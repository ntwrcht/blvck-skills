# Security

Supabase inverts the usual model: the database is directly reachable from the browser, so authorization lives in Postgres rather than in an API layer you control. That makes a handful of failure modes both easy to hit and severe.

---

## The Three That Actually Cause Breaches

### 1. A table with RLS off

```sql
select c.relname
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
  and not c.relrowsecurity;
```

Any row this returns is readable and writable by anyone with the publishable key — which is in the browser bundle. Put this query in CI and fail the build on a non-empty result.

Easy to miss on: join tables, lookup tables, tables created directly in Studio, and anything added by a migration written in a hurry.

### 2. The secret key reaching the client

```ts
// ❌ Inlined into the bundle at build time, public forever
NEXT_PUBLIC_SUPABASE_SECRET_KEY=sb_secret_…

// ✅
SUPABASE_SECRET_KEY=sb_secret_…
```

```ts
// lib/supabase/admin.ts
import 'server-only'    // build fails if a client module imports this
```

If a secret key has ever been committed, pushed, or bundled, rotate it. It bypasses RLS on every table, so exposure is total compromise, not partial.

### 3. Authorization on user-editable metadata

```sql
-- ❌ Any user can call updateUser({ data: { role: 'admin' } })
using ( (select auth.jwt()) -> 'user_metadata' ->> 'role' = 'admin' )

-- ✅ app_metadata is writable only with the secret key
using ( (select auth.jwt()) -> 'app_metadata' ->> 'role' = 'admin' )
```

This one reads correctly, passes review, and works in testing. It is a self-service admin button.

---

## Key Handling

| Key | Exposure | RLS |
|---|---|---|
| `sb_publishable_…` / `anon` | Public by design | Enforced |
| `sb_secret_…` / `service_role` | Server only | **Bypassed** |

Rules for the secret key:

- Never in a browser, a URL, a query string, a log line, or a client-reachable env var.
- Never in an Edge Function that runs with `auth: 'none'` unless the function does its own authorization.
- Store it in the platform's secret manager, not in a committed `.env`.
- Rotate on any suspicion, on staff departure, and on schedule.
- Every code path holding it is fully privileged — scope queries by hand, because nothing else will.

```ts
// ❌ Trusts a client-supplied id with RLS bypassed
export async function getOrder(orderId: string) {
  return supabaseAdmin.from('orders').select().eq('id', orderId).single()
}

// ✅ Scope by the verified session
export async function getOrder(orderId: string) {
  const { data } = await supabase.auth.getClaims()
  if (!data?.claims) throw new Error('Unauthorized')
  return supabaseAdmin
    .from('orders')
    .select()
    .eq('id', orderId)
    .eq('user_id', data.claims.sub)     // the check RLS would have made
    .single()
}
```

---

## Exposed Schemas

Settings → API → Exposed schemas controls what PostgREST serves. Default is `public` (plus `graphql_public`).

Keep internal tables out of it:

```sql
create schema if not exists private;
revoke all on schema private from anon, authenticated;

create table private.audit_log ( … );      -- unreachable via the data API
```

This is a stronger guarantee than RLS for anything that should never be client-reachable — audit logs, internal queues, billing reconciliation, secrets tables. RLS is a filter; a non-exposed schema is a wall.

---

## `security definer` Functions

These run as the owner and bypass RLS. Two requirements:

```sql
create or replace function public.promote_user(target uuid)
returns void
language plpgsql
security definer
set search_path = ''                        -- mandatory
as $$
begin
  if (select auth.jwt()) -> 'app_metadata' ->> 'role' <> 'admin' then
    raise exception 'forbidden';            -- authorize inside the function
  end if;
  update public.profiles set role = 'moderator' where id = target;
end;
$$;

revoke execute on function public.promote_user(uuid) from public, anon;
grant execute on function public.promote_user(uuid) to authenticated;
```

- **`set search_path = ''`** — without it, a caller can create a table in a schema earlier on the path and hijack what the function touches. Every object reference must then be schema-qualified.
- **Authorize inside the body** — the function bypasses RLS, so it is an API endpoint. `grant execute to authenticated` means every logged-in user can call it.

Postgres grants `execute` to `public` by default on new functions. The explicit `revoke` is not optional.

---

## SQL Injection

The PostgREST client parameterizes, so normal queries are safe. Dynamic SQL inside functions is not:

```sql
-- ❌ Injectable
execute 'select * from public.items where name = ''' || search || '''';

-- ✅ Parameterized
execute 'select * from public.items where name = $1' using search;

-- ✅ For identifiers, which cannot be parameters
execute format('select * from public.%I where id = $1', table_name) using item_id;
```

`format` with `%I` quotes identifiers and `%L` quotes literals. String concatenation does neither.

On the client, `.filter()` and `.or()` take raw PostgREST syntax — do not build those strings from user input:

```ts
// ❌ User controls filter syntax
.or(`name.eq.${userInput}`)

// ✅
.eq('name', userInput)
```

---

## Storage

Buckets are private by default and `storage.objects` has its own policies.

```sql
create policy "users manage their own folder"
on storage.objects for all
to authenticated
using ( bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text )
with check ( bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text );
```

Public buckets serve every object to anyone with the URL, and object paths are often guessable. Use a private bucket with signed URLs for anything sensitive. See `references/storage.md`.

Validate uploads server-side: size limits on the bucket, MIME allowlist, and never derive a storage path from a user-supplied filename.

---

## Auth Hardening

- Enable email confirmation; without it, anyone can register as anyone.
- Set OTP and magic-link expiry short (under an hour).
- Restrict redirect URLs to an explicit allowlist — a wildcard is an open redirect and a token-exfiltration path.
- Enable leaked-password protection (HaveIBeenPwned).
- Set a password policy and require MFA for privileged roles.
- Set rate limits on sign-in, sign-up, and OTP.
- Keep JWT expiry short; revoking a role does not take effect until the token refreshes.
- Do not put PII in the JWT — it is signed, not encrypted, and readable by anyone holding it.

For immediate revocation, check a table in the policy rather than a claim.

---

## Realtime

Realtime respects RLS for Postgres Changes, but the events themselves reveal that a row changed. For private channels, add policies on `realtime.messages` and call `supabase.realtime.setAuth()` before subscribing.

A wide-open `using ( true )` on `realtime.messages` makes every broadcast topic readable by every authenticated user.

---

## PII and Logging

- Never log the full row on error; log ids and error codes.
- Never return raw `PostgrestError.message` to users — it can name columns, constraints, and tables.
- Consider column-level encryption (`pgsodium` / Vault) for secrets at rest.
- Mask PII in views used for analytics.

---

## Checklist

- [ ] No table in an exposed schema without RLS — enforced in CI.
- [ ] Policies scoped `TO` a role, with `with check` on every `update`.
- [ ] Secret key server-only, behind `import 'server-only'`, no `NEXT_PUBLIC_`.
- [ ] Authorization reads `app_metadata`, never `user_metadata`.
- [ ] Internal tables in a non-exposed schema.
- [ ] `security definer` functions have `set search_path = ''`, authorize internally, and have `execute` revoked from `public`.
- [ ] No string-built SQL in functions; no user input in `.or()` / `.filter()`.
- [ ] Storage buckets private by default with per-user path policies.
- [ ] Email confirmation on, redirect URLs allowlisted, leaked-password protection on, rate limits set.
- [ ] Views declared `security_invoker = true`.
- [ ] Security Advisor clean.
- [ ] Errors logged server-side, generic messages to users.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Entire table readable by strangers | RLS never enabled |
| Total compromise | Secret key bundled, committed, or logged |
| Users self-promote to admin | Policy reads `user_metadata` |
| Internal table reachable via the API | Left in an exposed schema |
| Privilege escalation via a helper | `security definer` without `set search_path = ''` |
| Any user can call an admin function | `execute` not revoked from `public` |
| Injection through a search function | Concatenated dynamic SQL |
| Private files publicly readable | Public bucket instead of signed URLs |
| Account takeover via redirect | Wildcard redirect URL allowlist |
| Error message names internal columns | Raw `PostgrestError` returned to the client |
