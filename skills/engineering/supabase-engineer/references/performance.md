# Performance

Supabase performance problems cluster into four causes: a missing index, an RLS policy evaluated per row, N+1 requests from the client, and connection exhaustion. Check them in that order.

---

## Measure First

```sql
create extension if not exists pg_stat_statements;

-- Slowest statements by total time
select
  calls,
  round(total_exec_time::numeric, 2)  as total_ms,
  round(mean_exec_time::numeric, 2)   as mean_ms,
  round((100 * total_exec_time / sum(total_exec_time) over ())::numeric, 2) as pct,
  query
from pg_stat_statements
order by total_exec_time desc
limit 20;
```

Sort by `total_exec_time`, not `mean_exec_time`. A 5 ms query called a million times costs more than a 2 s report run twice a day, and only one of them is worth fixing.

```sql
explain (analyze, buffers, format text)
select * from public.posts where author_id = '…' order by created_at desc limit 20;
```

Read for `Seq Scan` on a large table, a large gap between estimated and actual rows, and `Rows Removed by Filter`.

Impersonate a real user, or the plan will not include RLS:

```sql
set local role authenticated;
set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}';
explain analyze select * from public.posts;
```

A query that is fast in the SQL editor and slow through the API is almost always RLS.

---

## RLS Cost

Policies run per row. Three fixes account for nearly all of the difference.

```sql
-- ❌ auth.uid() re-evaluated per row
using ( auth.uid() = user_id )

-- ✅ evaluated once per statement
using ( (select auth.uid()) = user_id )
```

```sql
-- Index every column a policy filters on
create index posts_author_id_idx on public.posts (author_id);
```

```sql
-- Skip the policy entirely for roles that can never pass
create policy "…" on public.posts for select to authenticated using ( … );
```

Also add the redundant client filter so the planner sees a predicate:

```ts
// ❌ RLS filters, but the planner has nothing to work with
await supabase.from('posts').select()

// ✅
await supabase.from('posts').select().eq('author_id', userId)
```

Replace joins inside policies with a `security definer` helper returning an array — see `references/rls-policies.md`.

---

## N+1

```ts
// ❌ 1 + N HTTP round trips
const { data: posts } = await supabase.from('posts').select()
for (const post of posts) {
  const { data: author } = await supabase.from('profiles').select().eq('id', post.author_id).single()
}

// ✅ One request
const { data } = await supabase
  .from('posts')
  .select('*, author:profiles(id, username, avatar_url)')
```

Each `supabase.from()` is a network request, so N+1 here costs latency as well as database time. Embedding is the fix.

Batch independent queries:

```ts
const [posts, tags, profile] = await Promise.all([
  supabase.from('posts').select().eq('published', true),
  supabase.from('tags').select(),
  supabase.from('profiles').select().eq('id', userId).single(),
])
```

Select only the columns rendered. `select('*')` on a table with a large `body` or `jsonb` column moves megabytes to render a list of titles.

---

## Pagination

```ts
// ❌ Offset — the database still walks the skipped rows
.range(10000, 10019)

// ✅ Keyset — constant cost at any depth
.order('created_at', { ascending: false })
.lt('created_at', cursor)
.limit(20)
```

```ts
// ❌ Exact count on every request
.select('*', { count: 'exact' })

// ✅
.select('*', { count: 'estimated' })
```

`count: 'exact'` runs a full count alongside the query. On a large table it frequently costs more than the query itself.

---

## Connections

Postgres connections are a hard, small limit. Serverless makes it worse — each concurrent invocation wants its own.

| Mode | Port | Fit |
|---|---|---|
| Transaction pooler | 6543 | Serverless and edge. No prepared statements, no session state. |
| Session pooler | 5432 | Long-lived servers, migrations, tools needing session features |
| Direct | 5432 | Migrations and admin only |

The PostgREST data API pools for you — connection problems come from direct Postgres clients (Prisma, Drizzle, `pg`) in serverless functions.

```
DATABASE_URL="postgres://…@…pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=1"
DIRECT_URL="postgres://…@…pooler.supabase.com:5432/postgres"
```

`connection_limit=1` per serverless instance is right — the pooler multiplexes, so a per-instance pool just holds connections idle.

Prepared statements do not work in transaction mode; disable them in the ORM.

---

## Caching

```ts
// Safe — not user-scoped
export async function getPublishedPosts() {
  'use cache'
  cacheLife('hours')
  cacheTag('posts')
  return supabase.from('posts').select().eq('published', true)
}

// Never cache — RLS scopes rows to the caller
const { data } = await supabase.from('orders').select()
```

Caching a user-scoped query serves one user's rows to the next. If the query runs through a client carrying a session, it is user-scoped.

For read-heavy aggregates, a materialized view refreshed on a schedule moves the cost off the request path. Keep it in a non-exposed schema — materialized views do not support RLS.

---

## Realtime

Postgres Changes evaluates RLS per subscribed client per change, so cost is connections × changes. At scale, switch to Broadcast from a trigger: one evaluation, fanned out. Scope topics per tenant. See `references/realtime.md`.

---

## Advisors

The dashboard's Performance Advisor reports unindexed foreign keys, unused indexes, and RLS policies with unwrapped auth calls. It catches the common cases without any setup — check it before hand-analyzing.

The Security Advisor covers unprotected tables and mutable `search_path`.

---

## Storage

Request the rendered size rather than the original:

```ts
supabase.storage.from('avatars').getPublicUrl(path, {
  transform: { width: 128, height: 128, quality: 75 },
})
```

Set `cacheControl` on upload so the CDN keeps objects.

---

## Checklist

- [ ] `pg_stat_statements` reviewed by `total_exec_time`.
- [ ] Every foreign key indexed.
- [ ] Every RLS predicate column indexed.
- [ ] `auth.uid()` / `auth.jwt()` wrapped in `(select …)`.
- [ ] Policies scoped `TO` a role.
- [ ] Embeds instead of per-row queries.
- [ ] Explicit column lists, not `select('*')`.
- [ ] Keyset pagination on large tables; no `count: 'exact'`.
- [ ] Transaction pooler with `connection_limit=1` for serverless ORM clients.
- [ ] No caching of user-scoped queries.
- [ ] Advisors clean.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Fast in the SQL editor, slow via the API | RLS — impersonate a user in `explain analyze` |
| Query time grows with table size | Unwrapped `auth.uid()` in a policy |
| Sequential scan despite an index | Predicate column not in the policy or query |
| Page loads with many small requests | N+1 — use embeds |
| `remaining connection slots` errors | Direct connections from serverless; use the pooler |
| Prepared statement errors | Transaction pooler; disable prepared statements |
| Deep pages slow | Offset pagination |
| Count dominates response time | `count: 'exact'` |
| Cached page shows another user's data | Cached a user-scoped query |
| Realtime degrades as users grow | Postgres Changes at scale |
