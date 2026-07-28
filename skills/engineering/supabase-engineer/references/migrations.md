# Migrations

Every schema change goes through a migration file in version control. A change made in Studio or the SQL editor exists in exactly one environment and will be lost on the next `db reset`.

---

## Imperative Migrations

```bash
supabase migration new add_posts_table
# → supabase/migrations/20260729103000_add_posts_table.sql
```

```sql
-- supabase/migrations/20260729103000_add_posts_table.sql
create table public.posts (
  id        uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users on delete cascade,
  title     text not null,
  created_at timestamptz not null default now()
);

alter table public.posts enable row level security;

create policy "users read own posts"
on public.posts for select to authenticated
using ( (select auth.uid()) = author_id );

create index posts_author_id_idx on public.posts (author_id);
```

```bash
supabase migration up          # apply pending migrations locally
supabase db reset              # drop, re-apply everything, re-seed
supabase migration list        # compare local and remote state
supabase db push               # apply to the linked remote project
```

`supabase db reset` is the real test. It proves the migration history builds a working database from nothing, which is what CI and a new teammate will do.

---

## Declarative Schemas

Instead of writing each change by hand, declare the desired end state and let the CLI diff it.

```
supabase/
  schemas/
    01_extensions.sql
    02_types.sql
    10_profiles.sql
    20_posts.sql
  migrations/          # generated — reviewed, then committed
```

```sql
-- supabase/schemas/20_posts.sql — the desired state, edited in place
create table public.posts (
  id        uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users on delete cascade,
  title     text not null,
  summary   text,                                  -- newly added column
  created_at timestamptz not null default now()
);
```

```bash
supabase stop
supabase db diff -f add_post_summary     # generates the migration
supabase start
supabase migration up
```

Files run in lexicographic order; number them, or set the order explicitly:

```toml
# supabase/config.toml
[db.migrations]
schema_paths = [
  "./schemas/01_extensions.sql",
  "./schemas/02_types.sql",
  "./schemas/*.sql",
]
```

**The diff engine does not capture everything.** These still need hand-written migrations:

- DML — inserts, updates, deletes, and all seed data
- RLS policy changes (`alter policy`) and column privileges
- View ownership, `security_invoker`, materialized views, column type changes
- Schema privileges, comments, partitions, domains

Because policies are in that list, a declarative project still hand-writes its most security-critical changes. Review every generated migration regardless — the engine will happily emit a destructive `drop column`.

---

## Rules

**Migrations are append-only once pushed.** Editing an applied migration desyncs environments that already ran the old version. Fix forward with a new migration.

**Write them to be safe on a live database.** Development order is not production order:

```sql
-- ❌ Rewrites the table and blocks writes
alter table public.posts add column status text not null default 'draft';

-- ✅ Three steps, each cheap
alter table public.posts add column status text;                       -- 1
update public.posts set status = 'draft' where status is null;         -- 2, batched if large
alter table public.posts alter column status set not null;             -- 3
```

```sql
-- ❌ Locks the table for the duration
create index posts_status_idx on public.posts (status);

-- ✅ No write lock (cannot run inside a transaction block)
create index concurrently posts_status_idx on public.posts (status);
```

**Renaming a column is a breaking API change.** PostgREST exposes column names directly. Expand and contract instead: add the new column, backfill, dual-write, migrate clients, then drop.

---

## Seeding

```sql
-- supabase/seed.sql — runs after migrations on `db reset`
insert into public.tags (id, name) values
  ('11111111-1111-1111-1111-111111111111', 'postgres'),
  ('22222222-2222-2222-2222-222222222222', 'typescript')
on conflict (id) do nothing;
```

Fixed UUIDs make seed data stable across resets so tests can reference it.

Seeding auth users needs the admin API rather than SQL, since `auth.users` rows carry hashed credentials and identity records:

```ts
await supabaseAdmin.auth.admin.createUser({
  email: 'test@example.com',
  password: 'password123',
  email_confirm: true,
})
```

---

## Branching and Environments

| Approach | Fit |
|---|---|
| Supabase Branching | Per-PR ephemeral database, migrations applied automatically |
| Separate projects | dev / staging / prod as distinct projects |
| Local only | Solo work; `supabase db push` to a single remote |

Whichever is used, migrations run in the same order everywhere. Environment differences belong in config and secrets, never in divergent schema.

---

## CI

```yaml
name: Database
on: [push, pull_request]

jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
        with: { version: latest }

      - run: supabase start
      - run: supabase db reset            # migrations build from scratch
      - run: supabase test db             # pgTAP, including RLS policy tests
      - run: supabase gen types typescript --local > /tmp/types.ts
      - run: diff -q /tmp/types.ts lib/database.types.ts   # committed types are current

      - name: Fail on tables without RLS
        run: |
          supabase db query --local "
            select c.relname from pg_class c
            join pg_namespace n on n.oid = c.relnamespace
            where n.nspname='public' and c.relkind in ('r','p') and not c.relrowsecurity
          " | grep -q '^(0 rows)' || { echo 'Table without RLS'; exit 1; }
```

The last two steps are the ones worth adding first: they catch stale generated types and the unprotected-table mistake, which are the two failures that survive review most often.

Production deploys run `supabase db push`, gated on the above and on a backup.

---

## Rollback

There is no automatic down migration. Options:

```bash
supabase db reset --version 20260729103000    # local only, destroys data
```

In production, write a forward migration that reverses the change. For anything destructive, take a backup first and stage it: deploy the additive part, verify, then deploy the removal in a later release.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Works locally, missing in production | Changed in Studio, never captured in a migration |
| `db reset` fails but `migration up` worked | Migrations depend on state not in the history |
| Environments diverge | An already-pushed migration was edited |
| Deploy locks the table | `add column not null default` or a non-concurrent index |
| Generated migration drops a column | Diff engine inferred a rename as drop + add — always review |
| Policy change missing from the diff | Declarative diff does not capture `alter policy` |
| Types out of date in CI | `gen types` not re-run after a schema change |
| Seed data conflicts on reset | Missing `on conflict do nothing` |
| New table unprotected in production | `enable row level security` in a separate, unshipped migration |
