# Code Review

Order findings by cost of being wrong. In a Supabase project the top of that list is almost always RLS — a missing policy is a data breach, and it is invisible in a diff unless you go looking.

| Severity | Meaning |
|---|---|
| **Blocking** | Data exposure, data loss, broken migration, wrong behavior |
| **Should fix** | Real bug in an edge case, missing policy test, meaningful performance regression |
| **Consider** | Simplification, naming, structure — author's call |

Label every finding. An unlabeled list of twelve comments reads as twelve blockers.

---

## Pass 1 — Access Control

The highest-value pass. Everything here is reachable from a browser holding a public key.

- [ ] Every new table has `enable row level security` **in the same migration** that creates it.
- [ ] Join tables and lookup tables too — they leak the relationship graph.
- [ ] Policies exist per operation, with `to authenticated` / `to anon` stated.
- [ ] Every `update` policy has **both** `using` and `with check`. Without the latter, a user can reassign a row to someone else.
- [ ] Policies read `app_metadata`, never `user_metadata`.
- [ ] `auth.uid()` / `auth.jwt()` wrapped in `(select …)`.
- [ ] Every column a policy filters on is indexed.
- [ ] New views declare `security_invoker = true`.
- [ ] New `security definer` functions set `search_path = ''`, authorize in the body, and `revoke execute from public`.
- [ ] Storage policies scope by `(storage.foldername(name))[1]`, and buckets are private unless public is intended.
- [ ] `realtime.messages` policies are not `using ( true )`.
- [ ] Internal tables are in a non-exposed schema, not merely RLS-protected.

The one that hides best: a migration that adds a table and defers `enable row level security` to a follow-up that has not shipped.

---

## Pass 2 — Keys and Secrets

- [ ] No secret/`service_role` key outside a `server-only` module.
- [ ] No `NEXT_PUBLIC_` (or equivalent) prefix on a secret.
- [ ] Admin-client call sites scope queries by hand — RLS is off there.
- [ ] The admin client is not used where the user's client would work.
- [ ] Edge Function secrets set on the project, not only in a local `.env`.
- [ ] No key embedded in a `cron.job` definition — read from Vault.

---

## Pass 3 — Data Access

- [ ] `error` checked on every `supabase` call — errors are returned, not thrown.
- [ ] `.select()` present where the caller uses returned rows.
- [ ] Every `update` and `delete` has a filter.
- [ ] `.maybeSingle()` where zero rows is normal; `.single()` only where exactly one is guaranteed.
- [ ] Embeds instead of per-row queries (N+1).
- [ ] Explicit column lists rather than `select('*')` on wide tables.
- [ ] Keyset pagination on large tables; no `count: 'exact'` on hot paths.
- [ ] Multi-step writes that must be atomic are in a database function, not sequential client calls.
- [ ] No user input interpolated into `.or()` / `.filter()`.

---

## Pass 4 — Migrations

- [ ] The change is in a migration file, not applied by hand.
- [ ] No already-pushed migration was edited.
- [ ] Safe on a live table: no `add column not null default` on a large table, `create index concurrently` where needed.
- [ ] No column rename without an expand-and-contract path — it is a breaking API change.
- [ ] A generated migration was reviewed for accidental drops.
- [ ] `supabase db reset` builds the database from scratch.
- [ ] Generated types regenerated and committed.
- [ ] Extensions added via migration, not installed by hand.

---

## Pass 5 — Auth

- [ ] Session verified with `getClaims()` (or `getUser()`), never `getSession()`.
- [ ] Server clients created per request, never at module scope.
- [ ] Proxy/middleware still calls `getClaims()` — removing it as "unused" breaks refresh.
- [ ] Server Actions and route handlers verify independently; the proxy is not the boundary.
- [ ] Ownership taken from the verified claim, not from a form field.
- [ ] Redirect targets allowlisted; `//` rejected.
- [ ] Sign-in responses do not distinguish unknown email from wrong password.

---

## Pass 6 — Correctness and Performance

- [ ] Triggers do no network or long-running work — enqueue instead.
- [ ] Read-modify-write inside a function uses `for update`.
- [ ] Queue and webhook handlers are idempotent.
- [ ] `net.http_post` results are not treated as synchronous.
- [ ] Realtime channels removed on unmount.
- [ ] No user-scoped query cached across requests.
- [ ] Foreign keys indexed.

---

## Pass 7 — Tests and Conventions

- [ ] New or changed policies have pgTAP tests, including the negative cases.
- [ ] Constraints named deliberately so errors map to messages.
- [ ] Raw `PostgrestError.message` never returned to users.
- [ ] Matches the project's existing structure, naming, and client patterns.
- [ ] No `any`, no unexplained casts on `Json` columns.

---

## Writing the Review

Lead with the conclusion:

> **Blocking (2), Should fix (3), Consider (1).** `20260729_add_invoices.sql` creates `public.invoices` without enabling RLS — every invoice is readable by anyone with the publishable key. Everything else is contained.

Then each finding with file, line, why it matters, and a concrete fix:

> **Blocking** — `supabase/migrations/20260729_add_invoices.sql:14`
> The table is created without RLS. It is in the `public` schema, so it is served by the data API to anyone holding the publishable key — which ships in the browser bundle.
> ```sql
> alter table public.invoices enable row level security;
>
> create policy "org members read invoices"
> on public.invoices for select to authenticated
> using ( org_id = any (select public.user_org_ids()) );
> ```

> **Blocking** — `app/actions/orders.ts:23`
> `cancelOrder(orderId)` uses the admin client, which bypasses RLS, and filters only on `id`. Any authenticated user can cancel any order by guessing an id. Either use the user's client, or add `.eq('user_id', claims.sub)`.

> **Should fix** — `supabase/migrations/20260729_add_invoices.sql:22`
> `invoices.org_id` has no index. The RLS policy filters on it, so every query against this table will sequentially scan.

State what you verified and what you did not. "I did not run the migration against production-sized data" is more useful than silence.

---

## What Not to Comment On

- Formatting a linter already governs.
- Style preferences with no correctness or performance argument.
- Pre-existing issues unrelated to the diff — file them separately.
- Rewrites of working code without a stated benefit.

---

## Quick Reference

| Look for | Why |
|---|---|
| `create table` without `enable row level security` | World-readable |
| `update` policy with no `with check` | Users can reassign rows |
| `user_metadata` in a policy | Self-service privilege escalation |
| `auth.uid()` not wrapped in `select` | Per-row evaluation, table scan |
| Admin client with a client-supplied id | RLS bypassed, no ownership check |
| `security definer` without `set search_path` | Privilege escalation |
| `getSession()` used to authorize | Forgeable |
| Missing `error` check | Silent failure |
| `update`/`delete` without a filter | Mass mutation |
| HTTP call inside a trigger | Slow and fragile writes |
| Cached user-scoped query | One user's rows served to another |
