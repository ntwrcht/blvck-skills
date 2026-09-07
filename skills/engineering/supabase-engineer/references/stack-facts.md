# Supabase Stack Facts

The Supabase-specific facts a task must establish before generating code. The shared skeleton for reading, repairing, or skipping `.context/` is `references/project-context.md`; this file is what it points at.

## Recorded In Context

`.context/engineering.md` holds the client library versions, key naming, migration style, RLS posture, auth approach, test runner, and API conventions when the project records them there. Ask before generating code when the RLS posture or key naming is blank and the current task depends on it.

## Facts That Change Generated Code

| Fact | Where to find it | Why it matters |
|---|---|---|
| Key naming | `.env`, `.env.example` | `sb_publishable_`/`sb_secret_` vs legacy `anon`/`service_role` |
| Client library | `package.json` | `@supabase/ssr` vs deprecated `@supabase/auth-helpers-*` |
| Migration style | `supabase/schemas/` present or not | Declarative diffing vs hand-written migrations |
| RLS posture | `pg_policies`, migration files | Whether policies are the norm or the exception here |

A project on `@supabase/auth-helpers` needs different client code than one on `@supabase/ssr`, and the two do not mix.

## Read the Schema Before Writing Code

Unlike a frontend project, the authoritative context here is in SQL, not in `package.json`. Read these before proposing any change:

| Source | Tells you |
|---|---|
| `supabase/migrations/` | The real schema history, and which tables have RLS |
| `supabase/schemas/` | Present only in declarative projects — the source of truth if so |
| `lib/database.types.ts` (or similar) | The current generated shape, and whether it is stale |
| `supabase/config.toml` | Exposed schemas, auth settings, function `verify_jwt` flags |
| `supabase/seed.sql` | Reference data the tests assume |

The one query worth running before touching anything:

```sql
select c.relname from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind in ('r','p') and not c.relrowsecurity;
```

A non-empty result means existing tables are already exposed. That is worth raising regardless of what the current task is.

## Stale When

Offer to update the relevant `.context/` domain file when the user mentions or the repo shows:

- Migration from `@supabase/auth-helpers` to `@supabase/ssr`
- Adoption of the new `sb_publishable_` / `sb_secret_` key format
- A move to declarative schemas
- A new auth provider, or a custom access token hook
- Adoption of Realtime, Storage, Edge Functions, or pgvector
- A change in exposed schemas
- Self-hosting, or a move from self-hosted to cloud
- Test runner or CI changes

## Ask For

The bundled detector (`scripts/detect-project.sh`) inspects `package.json`, `supabase/config.toml`, the migrations and schemas directories, Edge Functions, environment files, and git history. If it cannot run, ask for:

- Supabase client library and version
- Key naming in use
- Hosted or self-hosted
- Whether migrations are declarative or hand-written
- Whether RLS is enabled across the board
- Auth providers in use, and whether custom claims exist
- Framework integration, if any
- Test runner, and whether pgTAP policy tests exist
- Main branch name, and ticket prefix if commit or PR output is needed

## Read Anyway

Still read `package.json` and list `supabase/migrations/` — those two reads cost nothing and prevent the most common category of wrong-version code.

Never skip the RLS check on a table you create. That one is not a convention question.
