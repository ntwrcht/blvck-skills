# Schema Design

The schema is the API. PostgREST exposes tables and views directly, so column names, types, and relationships become the client contract — renaming a column is a breaking change.

---

## Table Baseline

```sql
create table public.posts (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid not null references auth.users on delete cascade,
  title       text not null check (char_length(title) between 1 and 200),
  body        text,
  status      post_status not null default 'draft',
  published_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.posts enable row level security;

create index posts_author_id_idx on public.posts (author_id);
create index posts_status_published_idx on public.posts (status, published_at desc);

comment on table public.posts is 'User-authored blog posts.';
```

Every new table needs `enable row level security` in the same migration. Splitting it into a follow-up migration means production runs unprotected in between.

---

## Keys

| Choice | Use when |
|---|---|
| `uuid` + `gen_random_uuid()` | Default. Safe to expose, generated client-side, no enumeration. |
| `bigint generated always as identity` | Internal tables, or when index locality matters more than opacity. |
| `text` natural key | Slugs and codes that are genuinely stable. |

Sequential integer ids in a public API let anyone walk your dataset and estimate its size. Prefer UUIDs for anything client-reachable.

`gen_random_uuid()` (v4) is random, so index inserts scatter. On very high-insert tables, a time-ordered UUID (v7) via `pg_uuidv7` keeps locality.

---

## Types

```sql
create type post_status as enum ('draft', 'published', 'archived');
```

| Need | Type |
|---|---|
| Timestamps | `timestamptz` — never `timestamp` |
| Money | `numeric(12,2)`, or integer minor units — never `float` |
| Free text | `text` — `varchar(n)` buys nothing in Postgres |
| Fixed set | `enum`, or a lookup table with an FK |
| Semi-structured | `jsonb` — never `json` |
| Arrays | `text[]`, `uuid[]` |
| Ranges | `tstzrange` with an exclusion constraint for bookings |

`timestamp` without a time zone silently drops offset information and produces bugs that only appear across DST or deployments in another region.

Enums are compact and self-documenting but adding a value requires a migration and removing one is painful. A lookup table trades that for a join.

---

## Constraints

Put invariants in the database. Application checks are advisory — the data API, SQL editor, and admin scripts all bypass them.

```sql
alter table public.posts
  add constraint published_has_date
  check ( status <> 'published' or published_at is not null );

alter table public.profiles add constraint username_format
  check ( username ~ '^[a-z0-9_]{3,30}$' );

create unique index profiles_username_lower_idx
  on public.profiles (lower(username));

-- No overlapping bookings for one resource
alter table public.bookings
  add constraint no_overlap
  exclude using gist (resource_id with =, period with &&);
```

Name constraints deliberately — the name is what surfaces in the error, and `references/error-handling.md` maps names to user-facing messages.

---

## Relationships

```sql
-- One-to-many
create table public.comments (
  id       uuid primary key default gen_random_uuid(),
  post_id  uuid not null references public.posts on delete cascade,
  author_id uuid not null references auth.users on delete cascade,
  body     text not null
);
create index comments_post_id_idx on public.comments (post_id);

-- Many-to-many
create table public.post_tags (
  post_id uuid references public.posts on delete cascade,
  tag_id  uuid references public.tags on delete cascade,
  primary key (post_id, tag_id)
);
create index post_tags_tag_id_idx on public.post_tags (tag_id);
alter table public.post_tags enable row level security;   -- join tables need RLS too
```

Two things routinely forgotten:

- **Postgres does not index foreign keys automatically.** An unindexed FK makes the child-side join and every parent delete slow.
- **Join tables need RLS.** They are reachable via the data API like any other table, and they leak the relationship graph.

Choose `on delete` deliberately: `cascade` for owned children, `restrict` to block deletion, `set null` for optional links.

---

## Timestamps

```sql
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger posts_set_updated_at
before update on public.posts
for each row execute function public.set_updated_at();
```

A client-supplied `updated_at` is not trustworthy. Set it in a trigger.

---

## Soft Deletes

```sql
alter table public.posts add column deleted_at timestamptz;
create index posts_active_idx on public.posts (created_at desc) where deleted_at is null;

create policy "hide soft-deleted posts"
on public.posts for select to authenticated
using ( deleted_at is null and (select auth.uid()) = author_id );
```

The partial index keeps the common "not deleted" query fast without indexing dead rows.

Filter deleted rows in the **policy**, not just the client query — otherwise any direct API call sees them.

---

## Multi-Tenancy

```sql
create table public.organizations (
  id   uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null
);

create table public.org_members (
  org_id  uuid references public.organizations on delete cascade,
  user_id uuid references auth.users on delete cascade,
  role    org_role not null default 'member',
  primary key (org_id, user_id)
);
create index org_members_user_id_idx on public.org_members (user_id);

-- Every tenant-scoped table carries org_id
create table public.projects (
  id     uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations on delete cascade,
  name   text not null
);
create index projects_org_id_idx on public.projects (org_id);
```

Carry `org_id` on every tenant table even when it is derivable through a join. It keeps policies to a single indexed predicate instead of a join, which matters a lot given RLS runs per row.

Policies use a `security definer` helper to avoid recursion — see `references/rls-policies.md`.

---

## Views

```sql
create view public.published_posts
with (security_invoker = true)          -- Postgres 15+, required
as
select p.id, p.title, p.published_at, pr.username as author
from public.posts p
join public.profiles pr on pr.id = p.author_id
where p.status = 'published';
```

Without `security_invoker = true`, the view runs as its owner and bypasses RLS on the underlying tables. That is a data leak with a friendly name.

Materialized views do not support RLS at all. Keep them in a non-exposed schema and serve them through a `security definer` function.

---

## Generated Columns

```sql
alter table public.posts
  add column fts tsvector
  generated always as (
    to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))
  ) stored;

create index posts_fts_idx on public.posts using gin (fts);
```

Computed at write time, always consistent, indexable. Better than a trigger for pure derivations.

---

## Naming

- `snake_case` throughout — it becomes the JSON key.
- Plural tables (`posts`), singular columns (`title`).
- Foreign keys as `<singular>_id` so PostgREST infers the relationship name.
- Booleans read as assertions: `is_active`, `has_verified_email`.
- Timestamps end in `_at`; dates end in `_on`.

PostgREST derives embed names from FK names, so consistent naming makes `select('*, author:profiles(*)')` work without disambiguation.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Table world-readable | RLS not enabled in the same migration that created it |
| Slow joins and slow deletes | Foreign key not indexed |
| Timestamps shift by hours | `timestamp` instead of `timestamptz` |
| Money rounding errors | `float`/`double` instead of `numeric` |
| View leaks protected rows | Missing `security_invoker = true` |
| Relationship graph leaks | Join table without RLS |
| Duplicate usernames differing by case | Unique index not on `lower(username)` |
| Soft-deleted rows visible via API | Filtered in the client but not in the policy |
| `PGRST200` on an embed | No foreign key between the tables |
| Enum change requires downtime | Enum where a lookup table was the better fit |
