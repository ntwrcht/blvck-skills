# Error Handling

`supabase-js` **returns** errors rather than throwing. A call whose `error` is never inspected fails silently and hands you `null` data.

```ts
const { data, error } = await supabase.from('posts').select()
if (error) throw error       // or handle
```

---

## Error Shapes

```ts
type PostgrestError = {
  message: string      // human-readable, may name internal columns
  details: string      // often the offending value
  hint: string         // Postgres suggestion, sometimes empty
  code: string         // branch on this
}
```

Branch on `code`, never on `message`. Messages change between Postgres and PostgREST versions.

---

## Codes Worth Handling

### PostgREST

| Code | Meaning | Usual cause |
|---|---|---|
| `PGRST116` | Zero or multiple rows for `.single()` | Use `.maybeSingle()` |
| `PGRST200` | Relationship not found | No foreign key between the tables in an embed |
| `PGRST202` | Function not found | Wrong name, or argument names/types mismatch |
| `PGRST301` | JWT invalid or expired | Session not refreshed |

### Postgres

| Code | Meaning | User-facing message |
|---|---|---|
| `23505` | Unique violation | "That username is taken." |
| `23503` | Foreign key violation | "The referenced item no longer exists." |
| `23514` | Check constraint | Message specific to the named constraint |
| `23502` | Not-null violation | "A required field is missing." |
| `42501` | Insufficient privilege | **RLS denial** — "You do not have access." |
| `40001` | Serialization failure | Retryable |
| `57014` | Statement timeout | Retryable, or the query needs an index |
| `P0001` | `raise exception` | Your own message from a function |

`42501` on a write and an **empty array** on a read are the same thing: RLS said no. The read case is the confusing one — it looks like an empty table.

---

## Mapping to Messages

```ts
// lib/errors.ts
import type { PostgrestError } from '@supabase/supabase-js'

const CONSTRAINT_MESSAGES: Record<string, string> = {
  profiles_username_key:     'That username is taken.',
  profiles_username_format:  'Usernames may contain lowercase letters, numbers, and underscores.',
  posts_published_has_date:  'A published post needs a publish date.',
  bookings_no_overlap:       'That time slot is already booked.',
}

export function toUserMessage(error: PostgrestError): string {
  for (const [name, message] of Object.entries(CONSTRAINT_MESSAGES)) {
    if (error.message.includes(name) || error.details?.includes(name)) return message
  }

  switch (error.code) {
    case '23505': return 'That value is already in use.'
    case '23503': return 'The referenced item no longer exists.'
    case '23502': return 'A required field is missing.'
    case '42501': return 'You do not have permission to do that.'
    case 'PGRST116': return 'Not found.'
    case '57014': return 'That took too long. Try narrowing your search.'
    case 'P0001': return error.message          // deliberately written for users
    default:      return 'Something went wrong. Please try again.'
  }
}
```

Naming constraints deliberately in migrations is what makes this table possible — `check (char_length(title) <= 200)` produces an unusable auto-generated name, while `constraint posts_title_length check (…)` maps cleanly.

`P0001` is the exception: those messages come from `raise exception` in your own functions, so write them for users in the first place.

---

## Never Return Raw Errors

```ts
// ❌ Leaks column names, table names, and constraint definitions
return { error: error.message }

// ✅
console.error('createPost failed', { code: error.code, details: error.details, userId })
return { error: toUserMessage(error) }
```

`PostgrestError.message` regularly contains schema internals: `duplicate key value violates unique constraint "profiles_stripe_customer_id_key"` tells an attacker a column exists and what it is for.

---

## Auth Errors

```ts
import { AuthError, isAuthApiError } from '@supabase/supabase-js'

const { data, error } = await supabase.auth.signInWithPassword({ email, password })

if (error) {
  if (isAuthApiError(error)) {
    switch (error.code) {
      case 'invalid_credentials':
        return { message: 'Invalid email or password.' }     // same for both cases
      case 'email_not_confirmed':
        return { message: 'Check your inbox to confirm your email.' }
      case 'over_request_rate_limit':
        return { message: 'Too many attempts. Try again shortly.' }
      case 'weak_password':
        return { message: 'Choose a stronger password.' }
    }
  }
  return { message: 'Could not sign in.' }
}
```

Return the same message for "unknown email" and "wrong password". Distinguishing them is an account-enumeration oracle.

---

## Retries

```ts
const RETRYABLE = new Set(['40001', '57014', '08006', '08003'])

export async function withRetry<T>(
  fn: () => Promise<{ data: T | null; error: PostgrestError | null }>,
  attempts = 3
) {
  for (let i = 0; i < attempts; i++) {
    const result = await fn()
    if (!result.error || !RETRYABLE.has(result.error.code)) return result
    if (i < attempts - 1) {
      await new Promise(r => setTimeout(r, 2 ** i * 100 + Math.random() * 100))
    }
  }
  throw new Error('Exhausted retries')
}
```

Retry only serialization failures, timeouts, and connection errors. Retrying a constraint violation or an RLS denial just repeats the same failure — and retrying a non-idempotent write can duplicate it.

---

## Errors in Functions

```sql
create or replace function public.transfer_credits(to_user uuid, amount int)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if amount <= 0 then
    raise exception 'Amount must be greater than zero.'
      using errcode = '22023';
  end if;

  if (select credits from public.wallets where user_id = (select auth.uid()) for update) < amount then
    raise exception 'You do not have enough credits.'
      using errcode = 'P0001', detail = 'insufficient_balance';
  end if;
  -- ...
end;
$$;
```

Any exception rolls back the entire function — that atomicity is the reason the logic lives here.

Use `detail` for a machine-readable tag and the message for humans, so the client can branch without parsing prose.

---

## Edge Functions

```ts
export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    try {
      const body = await req.json()
      const parsed = Schema.safeParse(body)
      if (!parsed.success) {
        return Response.json({ error: 'Invalid request', details: parsed.error.flatten() }, { status: 400 })
      }

      const { data, error } = await ctx.supabase.from('posts').insert(parsed.data).select().single()
      if (error) {
        console.error('insert failed', error)
        return Response.json({ error: 'Could not save' }, { status: 500 })
      }

      return Response.json(data, { status: 201 })
    } catch (err) {
      console.error('unhandled', err)
      return Response.json({ error: 'Internal error' }, { status: 500 })
    }
  }),
}
```

Validation details are safe to return — they describe the caller's own input. Database errors are not.

---

## Distinguishing Denial from Absence

```ts
const { data, error } = await supabase.from('posts').select().eq('id', id).maybeSingle()

if (error) return { status: 'error', message: toUserMessage(error) }
if (!data)  return { status: 'not-found' }   // could be missing OR RLS-hidden
```

RLS deliberately makes these indistinguishable on reads — returning 404 rather than 403 avoids confirming that a row exists. Do not try to defeat that by probing with the admin client just to produce a nicer message; it re-introduces the leak.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Silent failures, `null` data | `error` never checked — it is returned, not thrown |
| Empty array where rows were expected | RLS denial, not an empty table |
| `42501` on a write | RLS denial |
| `PGRST116` | `.single()` matched 0 or 2+ rows |
| `PGRST200` | No foreign key backing the embed |
| `PGRST202` | RPC name or argument mismatch |
| Users see internal column names | Raw `error.message` returned |
| Attacker enumerates accounts | Sign-in distinguishes unknown email from wrong password |
| Duplicate writes after a blip | Retried a non-idempotent, non-retryable error |
| Constraint errors are unreadable | Constraints not explicitly named in migrations |
