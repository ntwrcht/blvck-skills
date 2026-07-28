---
name: supabase-engineer
description: "Builds, modifies, reviews, and debugs Supabase applications across Postgres schema, Row Level Security, auth, the data API, storage, realtime, Edge Functions, migrations, and type generation. Use when working on Supabase database design, RLS policies, session handling, client setup, SQL functions and triggers, local development, performance, security, or backend architecture."
---

# Supabase Engineer

Guide Supabase work with senior engineering judgment: the database is the authorization layer, so read the project's schema and policies before changing code, and keep every client-reachable table covered by RLS.

## When to Use

Use this skill for Supabase work: schema and migrations, RLS policies, auth and sessions, PostgREST queries and mutations, SQL functions and triggers, storage buckets, realtime channels, Edge Functions, vector search, type generation, local development, performance tuning, tests, reviews, and backend architecture decisions.

Use a narrower skill when the request is mainly about generic debugging, security review, analytics, TDD workflow, or stakeholder communication and Supabase is only incidental. Use `next-engineer` for Next.js rendering, routing, and caching concerns; this skill covers the Supabase half of that stack.

## Artifacts

- Produces: code changes, SQL migrations
- Consumes: stories at the `story` key path (if present) — see `references/artifact-paths.md` (default `docs/stories/<slug>.md`), `.context/project.md`, `.context/engineering.md`, `.context/git-workflow.md`, `.context/security.md`, `.context/learning.md`, `.context/adr/`

## Core Rule

RLS is the security boundary, not the client code. Any table reachable by a publishable or anon key must have RLS enabled and policies that a reviewer can read; a missing policy is a data breach, not a bug.

## Quick Path

Answer conceptual and architecture questions directly as prose with tradeoffs, and give explanations, single-line fixes, or small SQL or client snippets inline. Do not run the full project-context workflow unless you are generating, modifying, reviewing, or debugging project code.

## Workflow

1. Inspect local context before changing code. Read `.context/INDEX.md` when present, then load relevant domain files such as `.context/project.md`, `.context/engineering.md`, `.context/git-workflow.md`, `.context/security.md`, `.context/learning.md`, and `.context/adr/`. If context is missing and project code changes are needed, follow `references/project-context.md`.
2. Read the existing schema before writing SQL: `supabase/migrations/`, `supabase/schemas/` if the project is declarative, and the generated types file. Confirm which tables already have RLS.
3. Confirm the client library versions, key naming, and framework integration from `package.json` and `supabase/config.toml` before choosing APIs.
4. Load only the reference files needed for the task from the Reference Map.
5. Make the smallest coherent change. Schema changes go through a migration file, never a manual Studio edit.
6. Validate with `supabase db reset` locally, the repo's test command, and `supabase gen types` when the schema changed.

## Engineering Defaults

- Enable RLS on every table in an exposed schema, including join tables and lookup tables, and write policies per operation with an explicit `TO authenticated` or `TO anon`.
- Wrap auth helpers in a subquery — `(select auth.uid()) = user_id` — and index every column a policy filters on; the unwrapped form re-evaluates per row.
- Keep the secret (`service_role`) key server-side only. It bypasses RLS, so treat any code path holding it as fully privileged.
- Use `getClaims()` to verify a session server-side; never authorize on `getSession()`, whose user object is not revalidated.
- Generate types from the database and pass them to the client generic rather than hand-writing row interfaces.
- Put multi-statement or privileged logic in a `security definer` function with `set search_path = ''`, and grant execute deliberately.
- Prefer `raw_app_meta_data` over `raw_user_meta_data` for anything an authorization check reads — users can edit the latter.
- Write tests for policies, not just queries. A policy with no test is an access-control rule nobody has checked.

## Version Guide

| Area | Current | Notes |
|---|---|---|
| API keys | `sb_publishable_…` / `sb_secret_…` | Replace legacy `anon` / `service_role` JWTs, deprecated end of 2026 |
| Server auth | `@supabase/ssr` with `getAll`/`setAll` cookies | Supersedes `@supabase/auth-helpers-*`; per-cookie `get`/`set`/`remove` is removed |
| Session verification | `getClaims()` | Verifies the JWT locally against JWKS; `getUser()` costs a network call, `getSession()` is not for authorization |
| Edge Functions | `withSupabase` from `npm:@supabase/server` | Declares an `auth` mode and hands back a scoped client on `ctx` |

Ask before defaulting when the key naming, client library, or RLS posture is unclear and the choice affects generated code.

## Output Shape

- Small fix: changed code or SQL plus one sentence explaining the decision.
- New table or feature: migration, RLS policies, generated types, client usage, tests, and a short decision note.
- Review: findings first with file and line references; load `references/code-review.md` for full PR reviews.

## Reference Map

- `references/project-context.md`: missing or stale `.context/` domain files or provider stubs.
- `references/client-setup.md`: browser, server, and admin clients, `@supabase/ssr`, key selection, singletons.
- `references/database-schema.md`: table design, keys, constraints, enums, relationships, soft deletes, multi-tenancy.
- `references/rls-policies.md`: enabling RLS, per-operation policies, roles, helper functions, testing and debugging policies.
- `references/auth-patterns.md`: sign-up and sign-in, OAuth, magic links, MFA, JWT claims, custom claims, role checks.
- `references/data-api.md`: PostgREST selects, filters, embedded resources, pagination, inserts, upserts, deletes.
- `references/database-functions.md`: plpgsql, RPC, triggers, `security definer`, `search_path`.
- `references/realtime.md`: Postgres Changes, Broadcast, Presence, broadcast from database, realtime authorization.
- `references/storage.md`: buckets, upload and download, policies on `storage.objects`, signed URLs, transforms.
- `references/edge-functions.md`: Deno runtime, `withSupabase` auth modes, secrets, local serve, deploy, invoking.
- `references/migrations.md`: CLI migrations, declarative schemas, seeding, branching, rollback, CI deploys.
- `references/type-generation.md`: generating types, typing the client, helper types, keeping types in sync.
- `references/postgres-patterns.md`: indexes, JSONB, full-text search, extensions, generated columns, partitioning.
- `references/vector-search.md`: pgvector, embeddings, HNSW and IVFFlat, hybrid search, matching functions.
- `references/queues-jobs.md`: `pg_cron`, `pgmq`, database webhooks, background work, scheduling Edge Functions.
- `references/nextjs-integration.md`: `@supabase/ssr` with the App Router, proxy session refresh, Server Actions, caching.
- `references/performance.md`: query plans, index strategy, RLS cost, connection pooling, N+1, advisors.
- `references/security-patterns.md`: key handling, RLS bypass paths, SQL injection, exposed schemas, secrets, PII.
- `references/testing.md`: pgTAP policy tests, seeding, integration tests, mocking the client, CI.
- `references/local-development.md`: `supabase start`, Studio, `db reset`, config.toml, linking, environment parity.
- `references/error-handling.md`: `PostgrestError` codes, auth errors, constraint violations, retries, user-facing messages.
- `references/observability.md`: logs, advisors, metrics, slow query analysis, alerting.
- `references/self-hosting.md`: Docker Compose, self-hosted versus cloud tradeoffs, upgrades, backups.
- `references/git-workflow.md`: branch names, commits, changelog, PR descriptions.

## Next Step

Do not treat a change as done until `supabase db reset` applies cleanly from scratch, generated types are regenerated if the schema moved, and the project's test suite passes; for a schema change, until RLS policies on the new tables have been exercised as an anonymous and as a non-owning user.

- **If approved:** hand off to `tdd` when the change needs behavior tests it does not have, to `scrutinize` for an independent review of the diff, or to `security-audit` when it touches RLS, key handling, `security definer` functions, storage policies, or an exposed schema. For a full PR review of Supabase code, load `references/code-review.md` here instead of switching skills.
- **If not approved:** revise in place. When a failure's cause is not obvious from the SQL error or test output, escalate to `diagnose` rather than guessing at fixes.
