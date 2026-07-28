# Postgres Patterns

Supabase is Postgres. Most performance and modelling questions are Postgres questions, and the answer is usually an index or a different column type.

---

## Indexes

```sql
create index posts_author_id_idx on public.posts (author_id);

-- Composite: order matters. Leftmost columns must appear in the predicate.
create index posts_status_created_idx on public.posts (status, created_at desc);

-- Partial: smaller, and skips rows the query never wants
create index posts_active_idx on public.posts (created_at desc) where deleted_at is null;

-- Expression
create unique index profiles_username_lower_idx on public.profiles (lower(username));

-- Covering: satisfies the query from the index alone
create index posts_list_idx on public.posts (status, created_at desc) include (title);

-- On a live table
create index concurrently posts_status_idx on public.posts (status);
```

| Type | Use |
|---|---|
| B-tree (default) | Equality, ranges, sorting |
| GIN | `jsonb`, arrays, full-text search |
| GiST | Ranges, geometry, exclusion constraints |
| BRIN | Huge append-only tables ordered by insertion |
| HNSW / IVFFlat | Vector similarity (see `references/vector-search.md`) |

Two rules that cover most cases:

- **Index every foreign key.** Postgres does not do it automatically, and the child-side join plus every parent delete depends on it.
- **Index every column an RLS policy filters on.** The policy runs per row; an unindexed predicate means a sequential scan on every query.

Unused indexes are not free — they slow writes and consume space:

```sql
select relname, indexrelname, idx_scan
from pg_stat_user_indexes
where idx_scan = 0 and schemaname = 'public'
order by pg_relation_size(indexrelid) desc;
```

---

## JSONB

```sql
alter table public.events add column payload jsonb not null default '{}';

create index events_payload_gin on public.events using gin (payload);
-- Narrower and faster when you only query containment:
create index events_payload_path_gin on public.events using gin (payload jsonb_path_ops);
-- Single hot key:
create index events_user_idx on public.events ((payload ->> 'user_id'));
```

```sql
select payload -> 'user'  from events;        -- jsonb
select payload ->> 'name' from events;        -- text
select payload #> '{a,b}' from events;        -- nested, jsonb
where payload @> '{"type":"signup"}'          -- containment, uses GIN
where payload ? 'user_id'                     -- key exists
```

```ts
await supabase.from('events').select().contains('payload', { type: 'signup' })
```

Use `jsonb`, never `json` — `json` stores raw text and reparses on every access.

Reach for JSONB when the shape is genuinely variable: third-party webhook payloads, user-defined fields, event bodies. A column you always query and always populate should be a real column — it gets a type, a constraint, and a cheaper index.

---

## Full-Text Search

```sql
alter table public.posts
  add column fts tsvector
  generated always as (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(body,  '')), 'B')
  ) stored;

create index posts_fts_idx on public.posts using gin (fts);
```

```ts
await supabase.from('posts').select().textSearch('fts', 'postgres database', {
  type: 'websearch',        // handles quotes and OR the way users expect
  config: 'english',
})
```

`setweight` makes a title match outrank a body match under `ts_rank`. A generated column stays consistent without a trigger.

For fuzzy or partial matching, full-text search is the wrong tool — it matches whole lexemes:

```sql
create extension if not exists pg_trgm;
create index posts_title_trgm_idx on public.posts using gin (title gin_trgm_ops);
```

This is what makes `ilike '%term%'` fast. Without it, a leading wildcard forces a sequential scan.

---

## Extensions

```sql
create extension if not exists pg_trgm;       -- fuzzy text
create extension if not exists vector;        -- embeddings
create extension if not exists pg_cron;       -- scheduling
create extension if not exists pg_net;        -- async HTTP
create extension if not exists pgcrypto;      -- gen_random_uuid, hashing
create extension if not exists postgis;       -- geospatial
create extension if not exists pgmq;          -- queues
```

Install extensions into a dedicated schema rather than `public`, so they stay out of the exposed API surface:

```sql
create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;
```

---

## Aggregation

```sql
-- Window functions instead of correlated subqueries
select
  id, title, author_id,
  count(*)   over (partition by author_id)                     as author_post_count,
  row_number() over (partition by author_id order by created_at desc) as recency_rank
from public.posts;

-- Latest row per group
select distinct on (author_id) *
from public.posts
order by author_id, created_at desc;

-- Aggregate to JSON for a single round trip
select
  p.id, p.title,
  coalesce(jsonb_agg(c.*) filter (where c.id is not null), '[]') as comments
from public.posts p
left join public.comments c on c.post_id = p.id
group by p.id;
```

The `filter (where …)` on `jsonb_agg` is what stops a left join with no matches producing `[null]` instead of `[]`.

For anything expensive and read-heavy, a materialized view refreshed on a schedule beats recomputing per request — but materialized views do not support RLS, so keep them in a non-exposed schema and serve them through a `security definer` function.

---

## Constraints as Documentation

```sql
alter table public.subscriptions
  add constraint valid_period check (ends_at > starts_at);

alter table public.bookings
  add constraint no_double_booking
  exclude using gist (room_id with =, during with &&);

alter table public.orders
  add constraint one_default_address
  exclude (user_id with =) where (is_default);
```

Exclusion constraints express "no two rows may overlap" — a rule that application code cannot enforce correctly under concurrency without explicit locking.

Name constraints deliberately; the name is what surfaces in the error and what `references/error-handling.md` maps to a message.

---

## Concurrency

```sql
-- Read-modify-write without losing updates
select credits into balance from public.wallets where user_id = uid for update;

-- Skip locked rows — the queue-worker pattern
select * from public.jobs
where status = 'pending'
order by created_at
for update skip locked
limit 10;

-- Atomic increment, no read needed
update public.counters set value = value + 1 where id = counter_id;
```

Anything that reads a value, computes from it, and writes it back needs `for update` — otherwise two concurrent transactions both read the old value and one write is lost. This only works inside a database function, since the client has no transaction API.

---

## Partitioning

```sql
create table public.events (
  id         bigint generated always as identity,
  occurred_at timestamptz not null,
  payload    jsonb
) partition by range (occurred_at);

create table public.events_2026_07 partition of public.events
  for values from ('2026-07-01') to ('2026-08-01');
```

Worth it for large time-series tables where old data is dropped wholesale — `drop table events_2026_01` is instant where `delete` would be hours. Below tens of millions of rows it is usually premature.

RLS must be enabled on the parent; each partition inherits it.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Slow join or slow parent delete | Foreign key not indexed |
| Query slow only through the API | RLS predicate column not indexed |
| `ilike '%term%'` scans the table | No trigram index |
| Full-text search misses partial words | FTS matches lexemes — use trigram for substrings |
| JSONB queries slow | No GIN index, or a query shape the index cannot serve |
| Composite index unused | Predicate does not include the leftmost column |
| Writes degrade over time | Accumulated unused indexes |
| Lost updates under load | Read-modify-write without `for update` |
| Aggregate returns `[null]` | `jsonb_agg` without `filter (where … is not null)` |
| Extension functions exposed via the API | Installed into `public` instead of `extensions` |
