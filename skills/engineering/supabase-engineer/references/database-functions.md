# Database Functions and Triggers

PostgREST has no transaction API — separate `supabase.from(...)` calls are separate transactions. Anything that must be atomic belongs in a database function.

---

## When to Reach for One

| Use a function | Reason |
|---|---|
| Multi-step writes that must be atomic | The client cannot open a transaction |
| Logic with a race condition | `for update` locking is only available in SQL |
| Complex authorization | Avoids RLS recursion and keeps the check in one place |
| Aggregations too complex for the query builder | Runs where the data is |
| Anything a user must not skip | The client can always skip client code |

Do not move ordinary CRUD into functions. The query builder is typed, cached, and readable; a function is opaque to the type generator's row inference and harder to review.

---

## Function Anatomy

```sql
create or replace function public.transfer_credits(
  to_user uuid,
  amount  int
)
returns void
language plpgsql
security invoker                      -- default; runs as the caller, RLS applies
set search_path = ''
as $$
declare
  sender uuid := (select auth.uid());
  balance int;
begin
  if sender is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if amount <= 0 then
    raise exception 'amount must be positive' using errcode = '22023';
  end if;

  select credits into balance
  from public.wallets where user_id = sender
  for update;                          -- lock the row for the transaction

  if balance is null or balance < amount then
    raise exception 'insufficient credits' using errcode = 'P0001';
  end if;

  update public.wallets set credits = credits - amount where user_id = sender;
  update public.wallets set credits = credits + amount where user_id = to_user;

  insert into public.transfers (from_user, to_user, amount)
  values (sender, to_user, amount);
end;
$$;
```

```ts
const { error } = await supabase.rpc('transfer_credits', {
  to_user: recipientId,
  amount: 100,
})
```

The whole body runs in one transaction — any exception rolls it all back. `for update` prevents two concurrent transfers from both reading the same balance.

---

## `security invoker` vs `security definer`

| Mode | Runs as | RLS |
|---|---|---|
| `security invoker` (default) | The caller | Enforced |
| `security definer` | The function owner | **Bypassed** |

Default to `invoker`. Reach for `definer` only when the function genuinely needs to see rows the caller cannot — breaking RLS recursion, or a controlled privileged operation.

Every `security definer` function is an API endpoint with RLS off:

```sql
create or replace function public.promote_user(target uuid)
returns void
language plpgsql
security definer
set search_path = ''                              -- mandatory
as $$
begin
  if (select auth.jwt()) -> 'app_metadata' ->> 'role' <> 'admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.profiles set role = 'moderator' where id = target;
end;
$$;

revoke execute on function public.promote_user(uuid) from public, anon;
grant execute on function public.promote_user(uuid) to authenticated;
```

Three things are load-bearing:

- **`set search_path = ''`** — without it a caller can create a table in an earlier schema on the path and redirect what the function touches. Every reference must then be schema-qualified.
- **Authorization in the body** — nothing else is checking.
- **The explicit `revoke`** — Postgres grants `execute` to `public` on new functions by default.

---

## Function Volatility

```sql
create function public.expensive_calc(x int) returns int
language sql
immutable          -- same input → same output, no table reads
as $$ select x * 2 $$;
```

| Marker | Meaning |
|---|---|
| `immutable` | Depends only on arguments. Usable in index expressions. |
| `stable` | Cannot modify data; consistent within one statement. Use for anything reading tables. |
| `volatile` (default) | May modify data or return different results per call. |

Marking a read-only helper `stable` lets the planner cache it per statement instead of per row — the same mechanism that makes `(select auth.uid())` fast in policies.

---

## Returning Rows

```sql
create or replace function public.search_posts(term text, max_results int default 20)
returns setof public.posts
language sql
stable
set search_path = ''
as $$
  select * from public.posts
  where fts @@ websearch_to_tsquery('english', term)
  order by ts_rank(fts, websearch_to_tsquery('english', term)) desc
  limit max_results;
$$;
```

```ts
const { data } = await supabase.rpc('search_posts', { term: 'postgres' })
// data is typed as Tables<'posts'>[] via generated types
```

`returns setof <table>` gives the type generator a concrete row shape. A `returns table(...)` with ad-hoc columns generates a matching type too; `returns json` produces `Json` and loses all safety.

Because this is `security invoker`, RLS still filters the results.

---

## Triggers

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

| Timing | Use |
|---|---|
| `before` | Modify the row (`new`), validate, cancel with `return null` |
| `after` | Side effects — audit rows, notifications, cascades |
| `instead of` | Writable views |

```sql
-- Audit trail
create or replace function public.audit_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.audit_log (table_name, operation, row_id, actor, old_data, new_data)
  values (
    tg_table_name, tg_op,
    coalesce(new.id, old.id), (select auth.uid()),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end
  );
  return coalesce(new, old);
end;
$$;

create trigger posts_audit
after insert or update or delete on public.posts
for each row execute function public.audit_changes();
```

The audit table lives in a non-exposed schema so it is unreachable via the data API, and the trigger is `security definer` so callers can write to it without a policy granting them direct access.

Trigger cautions:

- A `before insert` trigger on `auth.users` that raises will fail the sign-up itself. Keep those minimal and defensive.
- Triggers run inside the caller's transaction. Slow work there slows every write — queue it instead (see `references/queues-jobs.md`).
- Triggers that write to the same table recurse. Guard with `pg_trigger_depth()` or `when` conditions.

```sql
create trigger posts_on_publish
after update on public.posts
for each row
when ( old.status is distinct from new.status and new.status = 'published' )
execute function public.notify_published();
```

A `when` clause is cheaper than an `if` in the body — the function is never called.

---

## Error Codes

```sql
raise exception 'insufficient credits' using errcode = 'P0001', detail = 'balance too low';
```

Custom codes surface as `PostgrestError.code`, letting the client branch without string-matching messages. Reserve `P0001`+ for application errors; map them in `references/error-handling.md`.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Partial writes after a failure | Multiple client calls instead of one RPC |
| Privilege escalation via a helper | `security definer` without `set search_path = ''` |
| Any user can call an admin function | `execute` not revoked from `public` |
| Function returns everything | `security definer` used where `invoker` was correct |
| `PGRST202` | Function missing, or argument names/types do not match |
| Type generator produces `Json` | `returns json` instead of `setof <table>` |
| Sign-up fails with a database error | Trigger on `auth.users` raised |
| Infinite recursion | Trigger writes to its own table without a guard |
| Writes became slow | Heavy work inside a trigger |
| Lost updates under concurrency | Read-modify-write without `for update` |
