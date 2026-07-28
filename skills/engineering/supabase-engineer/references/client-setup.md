# Client Setup

Three clients, three trust levels. Choosing the wrong one is either a broken session or a data breach.

| Client | Key | RLS | Where |
|---|---|---|---|
| Browser | publishable | enforced | Client Components, browser code |
| Server | publishable | enforced | Server Components, actions, route handlers |
| Admin | **secret** | **bypassed** | Trusted server code only, never in a request path a user controls |

---

## API Keys

Supabase is mid-transition between two key formats:

| New | Legacy | Role |
|---|---|---|
| `sb_publishable_…` | `anon` (a JWT) | Public. Ships to browsers. Safe only because RLS is enforced. |
| `sb_secret_…` | `service_role` (a JWT) | Privileged. Bypasses RLS entirely. |

Legacy `anon` and `service_role` keys still work but are deprecated at the end of 2026. New projects should use the new format; existing projects can migrate gradually since both work simultaneously.

The new secret key format adds a User-Agent check and returns 401 if used from a browser — a backstop, not a reason to be careless.

```bash
NEXT_PUBLIC_SUPABASE_URL=https://xyz.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_…
SUPABASE_SECRET_KEY=sb_secret_…                        # no NEXT_PUBLIC_ prefix, ever
```

A secret key behind `NEXT_PUBLIC_` is inlined into the JavaScript bundle at build time and is permanently public, including in past deployments. Rotate immediately if this ever happens.

---

## `@supabase/ssr`

```bash
npm install @supabase/supabase-js @supabase/ssr
```

`@supabase/auth-helpers-*` is superseded. If a project still uses it, migrating is worthwhile — the cookie handling in `@supabase/ssr` is what makes sessions work across Server Components, and the old per-cookie `get`/`set`/`remove` interface has been removed in favor of `getAll`/`setAll`.

### Browser client

```ts
// lib/supabase/client.ts
import { createBrowserClient } from '@supabase/ssr'
import type { Database } from '@/lib/database.types'

export function createClient() {
  return createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!
  )
}
```

`createBrowserClient` is already a singleton internally, so calling this per component is fine — it returns the same instance.

### Server client

```ts
// lib/supabase/server.ts
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import type { Database } from '@/lib/database.types'

export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {
            // Called from a Server Component, which cannot set cookies.
            // Safe to ignore when proxy/middleware is refreshing the session.
          }
        },
      },
    }
  )
}
```

The empty `catch` is deliberate and needs the comment. Server Components cannot write cookies; the write happens in the proxy instead. Swallowing it silently without explanation reads like a bug to the next person.

Create the client **per request**. A module-level server client shares one user's session across every request.

### Admin client

```ts
// lib/supabase/admin.ts
import 'server-only'
import { createClient } from '@supabase/supabase-js'
import type { Database } from '@/lib/database.types'

export const supabaseAdmin = createClient<Database>(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SECRET_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
)
```

`import 'server-only'` makes a client-side import a build error rather than a breach. Add it to every module holding the secret key.

Disable `persistSession` and `autoRefreshToken` — there is no user session here, and persisting one across requests would leak state between users.

Reach for this client only when the operation genuinely cannot be expressed as a policy: admin dashboards, webhook processing, background jobs, migrations. Every use is a spot where RLS is off, so scope the query by hand.

---

## Framework-Agnostic Server Client

Outside Next.js, supply cookies from whatever the framework exposes:

```ts
import { createServerClient, parseCookieHeader, serializeCookieHeader } from '@supabase/ssr'

const supabase = createServerClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_PUBLISHABLE_KEY!,
  {
    cookies: {
      getAll() {
        return parseCookieHeader(request.headers.get('Cookie') ?? '')
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value, options }) =>
          responseHeaders.append('Set-Cookie', serializeCookieHeader(name, value, options))
        )
      },
    },
  }
)
```

This works for SvelteKit, Astro, Remix, Nuxt, Express, Hono, TanStack Start, and React Router.

---

## Verifying a Session

| Method | Cost | Trustworthy server-side |
|---|---|---|
| `getClaims()` | Local JWT verification against cached JWKS | ✅ **Use this** |
| `getUser()` | Network call to the Auth server | ✅ but slower |
| `getSession()` | Reads storage, no revalidation | ❌ **Never for authorization** |

```ts
const supabase = await createClient()
const { data, error } = await supabase.auth.getClaims()
if (error || !data?.claims) redirect('/login')

const userId = data.claims.sub
```

`getSession()` returns whatever is in cookie storage without checking a signature. On the server, where storage is shared with the client, that means a user can hand you any session object they like. Use it only when you need the raw access or refresh token.

`getClaims()` verifies the signature against the project's published JWKS using WebCrypto, so it is both safe and fast — no round trip in the common case.

---

## Client Options

```ts
createBrowserClient<Database>(url, key, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,     // needed for OAuth and magic-link callbacks
    flowType: 'pkce',             // default, and the right choice for browsers
  },
  db: { schema: 'public' },
  global: { headers: { 'x-application-name': 'my-app' } },
  realtime: { params: { eventsPerSecond: 10 } },
})
```

To query a non-default schema, either set `db.schema` or use `supabase.schema('other')` per call. The schema must be added to the project's exposed schemas first — see `references/security-patterns.md`.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Session lost between navigations | Server client created at module scope instead of per request |
| `Auth session missing` in a Server Component | No proxy/middleware refreshing the session cookie |
| Cookies never set | `setAll` swallowing the error without a proxy doing the write |
| Users see each other's data | Module-level client, or admin client used in a user-facing path |
| Secret key in the browser bundle | `NEXT_PUBLIC_` prefix, or missing `server-only` |
| Auth check passes for a forged session | Authorized on `getSession()` instead of `getClaims()` |
| `auth-helpers` cookie errors after upgrade | Per-cookie `get`/`set`/`remove` removed — migrate to `getAll`/`setAll` |
| RLS silently not applied | Admin client used where the server client was intended |
| OAuth callback never completes | `detectSessionInUrl` disabled |
