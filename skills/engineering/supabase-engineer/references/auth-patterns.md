# Auth

Supabase Auth issues a JWT that Postgres reads in RLS policies. Authentication and authorization are therefore split: the client library handles the former, policies handle the latter.

---

## Sign Up and Sign In

```ts
// Email + password
const { data, error } = await supabase.auth.signUp({
  email,
  password,
  options: {
    emailRedirectTo: `${origin}/auth/callback`,
    data: { full_name: fullName },      // → raw_user_meta_data, NOT for authorization
  },
})

const { data, error } = await supabase.auth.signInWithPassword({ email, password })

await supabase.auth.signOut()           // 'local' | 'global' | 'others'
```

Anything in `options.data` lands in `user_metadata`, which the user can rewrite at any time. Never read it in a policy. See `references/rls-policies.md`.

### OAuth

```ts
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: 'github',
  options: {
    redirectTo: `${origin}/auth/callback?next=/dashboard`,
    scopes: 'read:user user:email',
  },
})
```

### Magic link and OTP

```ts
await supabase.auth.signInWithOtp({
  email,
  options: { emailRedirectTo: `${origin}/auth/callback`, shouldCreateUser: false },
})

await supabase.auth.verifyOtp({ email, token, type: 'email' })
```

`shouldCreateUser: false` on a sign-in form stops the endpoint doubling as unauthenticated user creation.

### Anonymous

```ts
const { data, error } = await supabase.auth.signInAnonymously()
```

Useful for guest carts and trials. Anonymous users get the `authenticated` role with `is_anonymous: true` in the JWT — exclude them explicitly where they should not reach:

```sql
using ( (select auth.jwt() ->> 'is_anonymous')::boolean is not true )
```

---

## The Callback Route

OAuth and magic links redirect back with a code that must be exchanged for a session.

```ts
// app/auth/callback/route.ts
import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  const next = searchParams.get('next') ?? '/'

  // Reject absolute URLs — an open redirect here leaks the session
  const safeNext = next.startsWith('/') && !next.startsWith('//') ? next : '/'

  if (code) {
    const supabase = await createClient()
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) return NextResponse.redirect(`${origin}${safeNext}`)
  }

  return NextResponse.redirect(`${origin}/auth/auth-code-error`)
}
```

The `//` check matters: `//evil.com` is a protocol-relative absolute URL, not a path.

Add every callback URL to the project's redirect allowlist. A wildcard entry is a token-exfiltration path.

---

## Verifying a Session

| Method | What it does | Safe to authorize on |
|---|---|---|
| `getClaims()` | Verifies the JWT signature locally against cached JWKS | ✅ **Use this** |
| `getUser()` | Network call to the Auth server | ✅ slower, always fresh |
| `getSession()` | Reads storage, no revalidation | ❌ never server-side |

```ts
const supabase = await createClient()
const { data, error } = await supabase.auth.getClaims()
if (error || !data?.claims) redirect('/login')

const userId = data.claims.sub
const role = data.claims.app_metadata?.role
```

`getSession()` trusts whatever sits in cookie storage. On the server that storage is shared with the client, so its user object is attacker-controlled. Use it only to read raw tokens.

Prefer `getUser()` over `getClaims()` when you need state that changed since the token was issued — a ban, a deleted account, a revoked role.

---

## Profiles Table

`auth.users` is managed by Supabase and should not be modified directly. Mirror what you need into `public.profiles`:

```sql
create table public.profiles (
  id          uuid primary key references auth.users on delete cascade,
  username    text unique,
  full_name   text,
  avatar_url  text,
  updated_at  timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "profiles are viewable by everyone"
on public.profiles for select to anon, authenticated using ( true );

create policy "users can update their own profile"
on public.profiles for update to authenticated
using ( (select auth.uid()) = id )
with check ( (select auth.uid()) = id );
```

```sql
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'avatar_url');
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();
```

`on delete cascade` matters — without it, deleting a user leaves orphaned profiles.

A trigger that raises will fail the sign-up itself. Keep it minimal and defensive.

---

## Roles and Custom Claims

Store the role where users cannot edit it, and surface it in the JWT with an access token hook.

```sql
create table public.user_roles (
  user_id uuid references auth.users on delete cascade,
  role    app_role not null,
  primary key (user_id, role)
);
```

```sql
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims jsonb;
  user_role public.app_role;
begin
  select role into user_role from public.user_roles
  where user_id = (event ->> 'user_id')::uuid limit 1;

  claims := event -> 'claims';
  if user_role is not null then
    claims := jsonb_set(claims, '{app_metadata,role}', to_jsonb(user_role));
  end if;

  return jsonb_set(event, '{claims}', claims);
end;
$$;
```

Register it under Authentication → Hooks. The claim then lands in `app_metadata`, which is server-controlled and safe for policies.

Claims only update on token refresh. For revocation that must take effect immediately, have the policy read `user_roles` directly rather than the claim.

---

## MFA

```ts
const { data } = await supabase.auth.mfa.enroll({ factorType: 'totp' })
// data.totp.qr_code → render for the authenticator app

await supabase.auth.mfa.challengeAndVerify({ factorId: data.id, code })

const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel()
// aal.currentLevel === 'aal2' once MFA is satisfied
```

Enforce in policies:

```sql
create policy "aal2 required for billing"
on public.billing_details for select
to authenticated
using ( (select auth.jwt() ->> 'aal') = 'aal2' );
```

---

## Password Reset

```ts
await supabase.auth.resetPasswordForEmail(email, {
  redirectTo: `${origin}/auth/reset-password`,
})

// On the reset page, after the recovery session is established
await supabase.auth.updateUser({ password: newPassword })
```

Return the same response whether or not the email exists — a differing response is an account-enumeration oracle.

---

## Auth State on the Client

```tsx
'use client'
export function useUser() {
  const [user, setUser] = useState<User | null>(null)
  const supabase = createClient()

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => setUser(data.user))
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (_event, session) => setUser(session?.user ?? null)
    )
    return () => subscription.unsubscribe()
  }, [])

  return user
}
```

Never `await` a Supabase call inside the `onAuthStateChange` callback — the client holds a lock during the callback and awaiting inside it deadlocks. Set state and do async work in an effect keyed on it.

---

## Hardening

- Email confirmation on.
- Short OTP and magic-link expiry.
- Redirect URLs allowlisted, no wildcards.
- Leaked-password protection (HaveIBeenPwned) on.
- Rate limits on sign-in, sign-up, OTP, and password reset.
- MFA required for privileged roles.
- Short JWT expiry.
- No PII in the JWT — signed, not encrypted.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Users grant themselves admin | Policy reads `user_metadata` instead of `app_metadata` |
| Auth check passes for a forged session | Authorized on `getSession()` |
| Session missing in Server Components | No proxy refreshing the cookie |
| OAuth returns to an error page | Callback URL not in the allowlist, or no code exchange route |
| Sign-up fails with a database error | `handle_new_user` trigger raised |
| Orphaned profiles after user deletion | Missing `on delete cascade` |
| Role change has no effect | Claim not refreshed — read the table for immediate revocation |
| Client hangs after sign-in | `await` inside `onAuthStateChange` |
| Anonymous users reach protected data | Policy does not exclude `is_anonymous` |
| Attacker enumerates accounts | Reset endpoint responds differently for unknown emails |
