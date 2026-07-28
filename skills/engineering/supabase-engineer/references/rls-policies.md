# Row Level Security

RLS is the authorization layer. The publishable key ships in the browser and anyone can read it, so the only thing standing between a stranger and your data is the set of policies on each table.

A table in an exposed schema without RLS enabled is world-readable and world-writable to anyone holding that key.

---

## Enabling

```sql
alter table public.posts enable row level security;
```

Enabling with no policies denies everything (except to the secret/`service_role` key, which bypasses RLS). That is the correct starting point — deny by default, then add policies.

`force row level security` additionally applies policies to the table's owner, which matters for logic running as `postgres`.

---

## Policy Anatomy

```sql
create policy "<name>"
on <table>
for <select | insert | update | delete | all>
to <role>                     -- authenticated, anon, or a custom role
using ( <row visibility> )    -- filters existing rows
with check ( <row validity> ) -- validates new/updated rows
```

| Operation | `using` | `with check` |
|---|---|---|
| `select` | ✅ which rows are visible | — |
| `insert` | — | ✅ which rows may be created |
| `update` | ✅ which rows may be targeted | ✅ what they may become |
| `delete` | ✅ which rows may be removed | — |

Multiple policies for the same operation are **OR**-ed. Adding a policy can only widen access, never narrow it — so an over-broad policy is not fixed by adding a stricter one next to it.

---

## The Standard Set

```sql
alter table public.posts enable row level security;

create policy "posts are viewable by everyone"
on public.posts for select
to anon, authenticated
using ( published = true );

create policy "users can view their own drafts"
on public.posts for select
to authenticated
using ( (select auth.uid()) = author_id );

create policy "users can create their own posts"
on public.posts for insert
to authenticated
with check ( (select auth.uid()) = author_id );

create policy "users can update their own posts"
on public.posts for update
to authenticated
using ( (select auth.uid()) = author_id )
with check ( (select auth.uid()) = author_id );

create policy "users can delete their own posts"
on public.posts for delete
to authenticated
using ( (select auth.uid()) = author_id );
```

The `update` policy needs **both** clauses. With only `using`, a user can update their own row and set `author_id` to someone else — handing the row away, or worse, taking one.

---

## Performance

RLS runs per row. Three changes account for nearly all the difference between a fast and an unusable policy.

### Wrap auth functions in a subquery

```sql
-- ❌ auth.uid() re-evaluated for every row
using ( auth.uid() = user_id )

-- ✅ evaluated once per statement via initPlan
using ( (select auth.uid()) = user_id )
```

On large tables this is the difference between milliseconds and minutes. It applies to `auth.uid()`, `auth.jwt()`, and any stable function in a policy.

### Index the policy columns

```sql
create index posts_author_id_idx on public.posts (author_id);
```

A policy filtering on an unindexed column forces a sequential scan on every query against the table.

### Always specify `to`

```sql
-- ❌ Evaluated even for anonymous requests that can never pass
create policy "…" on posts for select using ( (select auth.uid()) = author_id );

-- ✅ Skipped entirely for anon
create policy "…" on posts for select to authenticated using ( (select auth.uid()) = author_id );
```

### Filter explicitly in the client too

```ts
// ❌ Relies on RLS alone to filter — the planner sees no predicate
await supabase.from('posts').select()

// ✅ Redundant with the policy, but the planner can use the index
await supabase.from('posts').select().eq('author_id', userId)
```

The `.eq()` is not the security boundary — the policy is. It exists so the query plan is sane.

---

## Auth Helpers

| Function | Returns |
|---|---|
| `auth.uid()` | The requesting user's id, or `null` when anonymous |
| `auth.jwt()` | The full JWT payload as `jsonb` |
| `auth.role()` | `anon`, `authenticated`, or `service_role` |

`auth.uid()` returns `null` for anonymous requests, and `null = user_id` is `null`, not `false` — which fails closed for equality. It does **not** fail closed for `is distinct from` or negation, so be explicit where the comparison is not a plain equality.

### `raw_app_meta_data` vs `raw_user_meta_data`

```sql
-- ❌ Users can edit their own user_metadata — this is a privilege escalation
using ( (select auth.jwt()) -> 'user_metadata' ->> 'role' = 'admin' )

-- ✅ app_metadata is server-controlled
using ( (select auth.jwt()) -> 'app_metadata' ->> 'role' = 'admin' )
```

This is the most damaging RLS mistake in practice, because it reads correctly and works in testing. Any user can call `supabase.auth.updateUser({ data: { role: 'admin' } })` and grant themselves the first policy.

Note also that JWTs are not refreshed on every request. Revoking a role in the database does not take effect until the user's token refreshes — for immediate revocation, check a table instead of a claim.

---

## Multi-Tenant and Role Checks

Joining inside a policy is slow and can recurse. Pull the check into a `security definer` function:

```sql
create or replace function public.user_org_ids()
returns uuid[]
language sql
security definer
set search_path = ''
stable
as $$
  select coalesce(array_agg(org_id), '{}') from public.org_members
  where user_id = (select auth.uid());
$$;

revoke execute on function public.user_org_ids() from public, anon;
grant execute on function public.user_org_ids() to authenticated;
```

```sql
create policy "members can read their org's projects"
on public.projects for select
to authenticated
using ( org_id = any (select public.user_org_ids()) );
```

`security definer` runs as the function owner, bypassing RLS on `org_members` — which is what breaks the recursion. That also makes the function a privilege boundary: `set search_path = ''` is mandatory, and every referenced object must be schema-qualified, or a caller can shadow a table and hijack execution.

### Infinite recursion

A policy on `org_members` that queries `org_members` recurses and errors with `infinite recursion detected in policy`. The `security definer` function above is the standard fix.

---

## Views and Functions

Views run with the **definer's** rights by default, so a view over an RLS-protected table bypasses the policies of the querying user.

```sql
create view public.public_profiles
with (security_invoker = true)     -- Postgres 15+, required
as select id, username, avatar_url from public.profiles;
```

Without `security_invoker = true`, this view leaks every row of `profiles` regardless of policies. Audit existing views for it.

---

## Testing Policies

Policies are access control, and untested access control is a guess.

```sql
-- supabase/tests/posts_rls.test.sql
begin;
select plan(4);

-- anonymous
set local role anon;
select is_empty(
  $$ select * from public.posts where published = false $$,
  'anon cannot see unpublished posts'
);

-- authenticated as user A
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
select results_eq(
  $$ select count(*)::int from public.posts where author_id = '11111111-1111-1111-1111-111111111111' $$,
  ARRAY[2],
  'user A sees their own drafts'
);
select is_empty(
  $$ select * from public.posts where author_id = '22222222-2222-2222-2222-222222222222' and published = false $$,
  'user A cannot see user B drafts'
);
select throws_ok(
  $$ update public.posts set author_id = '22222222-2222-2222-2222-222222222222' where author_id = '11111111-1111-1111-1111-111111111111' $$,
  '42501',
  null,
  'user A cannot reassign a post to user B'
);

select * from finish();
rollback;
```

```bash
supabase test db
```

Test the negative cases. A policy suite that only proves owners can read their own rows has not tested the policy — it has tested the query.

See `references/testing.md`.

---

## Debugging

```sql
-- What policies exist?
select schemaname, tablename, policyname, roles, cmd, qual, with_check
from pg_policies where schemaname = 'public';

-- Which tables have RLS off?
select relname from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;

-- Impersonate a user
set local role authenticated;
set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}';
explain analyze select * from public.posts;
```

The second query belongs in CI. It is the cheapest possible guard against the single worst Supabase failure mode.

The Supabase dashboard's Security Advisor reports the same class of finding — unprotected tables, security-definer views, mutable `search_path`.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Query returns `[]` with no error | RLS enabled, no matching policy — this is a denial, not an empty table |
| Anyone can read everything | RLS never enabled on the table |
| Users can grant themselves admin | Policy reads `user_metadata` instead of `app_metadata` |
| Users can steal rows via update | `update` policy has `using` but no `with check` |
| `infinite recursion detected in policy` | Policy queries its own table — use a `security definer` function |
| Query times out on a large table | `auth.uid()` not wrapped in `select`, or the policy column is unindexed |
| View leaks protected rows | Missing `security_invoker = true` |
| Works in the app, fails in a function | `security definer` without `set search_path = ''`, or RLS bypassed unintentionally |
| Revoked role still works | JWT claim not yet refreshed — check a table for immediate revocation |
