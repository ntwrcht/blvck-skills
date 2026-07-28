# Authentication and Authorization

Three separable concerns: **authentication** (who is this), **session management** (keeping that answer across requests), **authorization** (what may they do).

The architectural rule that prevents most Next.js auth bugs: **check authorization as close to the data as possible**, not at the route.

---

## Why Not at the Route

Next.js apps have many entry points into the same data — pages, layouts, Server Actions, route handlers, and nested segments. A check in one of them does not cover the others.

| Placement | Covers | Misses |
|---|---|---|
| Proxy / middleware | Page navigations | Actions, route handlers, direct RSC requests |
| Layout | First render of the segment | Navigations within the segment (layouts do not re-render) |
| Page | That page | Actions and handlers it calls |
| **Data Access Layer** | **Every caller of that data** | — |

Layouts are the sharpest edge: partial rendering means a layout does not re-run when the user navigates between its children, so a session check there silently stops running.

---

## Data Access Layer

```ts
// lib/dal.ts
import 'server-only'
import { cache } from 'react'
import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import { decrypt } from '@/lib/session'

export const verifySession = cache(async () => {
  const cookie = (await cookies()).get('session')?.value
  const session = await decrypt(cookie)
  if (!session?.userId) redirect('/login')
  return { isAuth: true, userId: session.userId as string, role: session.role as string }
})

export const getUser = cache(async () => {
  const session = await verifySession()
  try {
    const user = await db.user.findUnique({
      where: { id: session.userId },
      select: { id: true, name: true, email: true, role: true },   // never the whole row
    })
    return user
  } catch {
    return null
  }
})
```

Every element earns its place:

- `import 'server-only'` — build fails if a Client Component imports this.
- `cache()` — one session decrypt per render pass, not one per component.
- `select` — a DTO, not the row. Prevents `passwordHash` from being passed to a Client Component and appearing in page source.
- `redirect` inside `verifySession` — callers cannot forget to handle the unauthenticated case.

Then every read goes through it:

```ts
export const getOrder = cache(async (orderId: string) => {
  const session = await verifySession()
  return db.order.findFirst({
    where: { id: orderId, userId: session.userId },   // ownership in the query
  })
})
```

Scoping by `userId` in the `where` clause beats fetching then comparing — there is no path where the check is skipped.

---

## Sessions

### Stateless (JWT in a cookie)

```ts
// lib/session.ts
import 'server-only'
import { SignJWT, jwtVerify } from 'jose'
import { cookies } from 'next/headers'

const encodedKey = new TextEncoder().encode(process.env.SESSION_SECRET)

export async function encrypt(payload: { userId: string; expiresAt: Date }) {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('7d')
    .sign(encodedKey)
}

export async function decrypt(session?: string) {
  if (!session) return null
  try {
    const { payload } = await jwtVerify(session, encodedKey, { algorithms: ['HS256'] })
    return payload
  } catch {
    return null
  }
}

export async function createSession(userId: string) {
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
  const session = await encrypt({ userId, expiresAt })
  ;(await cookies()).set('session', session, {
    httpOnly: true,
    secure: true,
    sameSite: 'lax',
    expires: expiresAt,
    path: '/',
  })
}

export async function deleteSession() {
  ;(await cookies()).delete('session')
}
```

Generate the secret with `openssl rand -base64 32` and store it in `.env` — never `NEXT_PUBLIC_`.

Put only the minimum in the payload: user id, role, expiry. No email, no phone, no PII — a JWT is signed, not encrypted, and anyone holding the cookie can decode it.

`jose` works on both Node and Edge runtimes. `jsonwebtoken` does not work on Edge, which matters for `middleware.ts` in Next 15 and earlier.

### Database sessions

Store the session server-side, send only an encrypted id. More secure and revocable — you can log a user out of all devices. Costs a lookup per request, so cache it for the request with `cache()`.

Keep an encrypted copy in the cookie too, so the proxy can do optimistic checks without a DB hit.

---

## Login with a Server Action

```ts
// app/actions/auth.ts
'use server'
import { redirect } from 'next/navigation'
import bcrypt from 'bcryptjs'
import { createSession, deleteSession } from '@/lib/session'
import { LoginSchema } from '@/lib/definitions'

export async function login(prevState: FormState, formData: FormData) {
  const parsed = LoginSchema.safeParse(Object.fromEntries(formData))
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors }

  const { email, password } = parsed.data
  const user = await db.user.findUnique({ where: { email } })

  // Same message for unknown email and wrong password — do not leak which
  if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
    return { message: 'Invalid email or password.' }
  }

  await createSession(user.id)
  redirect('/dashboard')                    // outside any try/catch
}

export async function logout() {
  await deleteSession()
  redirect('/login')
}
```

Rate-limit login by IP and by email. Without it the endpoint is a credential-stuffing target.

---

## Authorization Checks

### In a Server Component

```tsx
import { verifySession } from '@/lib/dal'

export default async function AdminActions() {
  const session = await verifySession()
  if (session.role !== 'admin') return null
  return <DangerZone />
}
```

Rendering `null` hides UI. It does not protect the Action behind the button — that needs its own check.

### In a Server Action

```ts
'use server'
export async function deleteUser(userId: string) {
  const session = await verifySession()
  if (session.role !== 'admin') throw new Error('Unauthorized')
  await db.user.delete({ where: { id: userId } })
}
```

### In a Route Handler

```ts
export async function GET() {
  const session = await verifySession()
  if (!session) return new Response(null, { status: 401 })
  if (session.role !== 'admin') return new Response(null, { status: 403 })
  return Response.json(await getAdminData())
}
```

---

## Streaming and the Session

Session data usually lives in shell UI — a header avatar, a nav. A top-level `await verifySession()` in a layout delays the first streamed chunk for the whole segment.

```tsx
// ❌ Blocks the entire subtree
export default async function Layout({ children }) {
  const user = await getUser()
  return <><Nav user={user} />{children}</>
}

// ✅ Only the user menu waits
export default function Layout({ children }) {
  return (
    <>
      <Nav>
        <Suspense fallback={<AvatarSkeleton />}>
          <UserMenu />          {/* awaits getUser() in here */}
        </Suspense>
      </Nav>
      {children}
    </>
  )
}
```

---

## Passing Session to Client Components

Client Components cannot import the DAL. Fetch in a parent Server Component and pass a minimal DTO down:

```tsx
export default async function Page() {
  const user = await getUser()
  return <ClientDashboard user={{ id: user.id, name: user.name, role: user.role }} />
}
```

Never pass the session token itself. If the client genuinely needs a sensitive value, `taintUniqueValue` from React makes accidental exposure a build-time error — see `references/security-patterns.md`.

---

## Auth Libraries

| Library | Notes |
|---|---|
| NextAuth.js / Auth.js | Broad provider support, self-hosted, DB adapters |
| Clerk | Hosted, prebuilt UI, native Vercel Marketplace integration |
| Better Auth | TypeScript-first, plugin architecture, self-hosted |
| Supabase Auth | Bundled with Supabase Postgres and RLS |
| WorkOS | Enterprise SSO, SCIM, directory sync |
| Auth0, Stytch, Kinde, Logto, Ory, Descope, Stack Auth | Hosted alternatives with Next.js SDKs |

Whichever is in use, the DAL pattern still applies — wrap the library's session getter in `cache()` behind `server-only`, and authorize at the data source.

Follow the project's existing library. Do not introduce a second auth system alongside one that already works.

---

## Checklist

- Session cookie is `httpOnly`, `secure`, `sameSite: 'lax'` (or `'strict'`), with an explicit expiry and path.
- `SESSION_SECRET` is server-only and rotated on compromise.
- The DAL is `server-only` and every read authorizes.
- Queries scope by session user id rather than trusting a client-supplied id.
- Server Actions and route handlers each verify independently.
- Login and signup are rate-limited; error messages do not distinguish unknown-user from wrong-password.
- Passwords hashed with bcrypt or argon2, never stored or logged in plaintext.
- Sessions invalidated on logout and on password change.
- No secret, token, or PII is passed to a Client Component.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Auth check does not re-run on navigation | Check placed in a layout — move it to the DAL |
| Action callable by unauthorized users | UI hidden, but no check in the Action body |
| Session in the browser bundle | Missing `import 'server-only'` on session or DAL modules |
| `jsonwebtoken` fails in middleware | Edge runtime — use `jose` |
| Every user sees the first user's data | Session read inside a `'use cache'` scope, or a module-level client |
| Redirect after login does nothing | `redirect()` inside a `try/catch` |
| DB hammered on every prefetch | DB session lookup in the proxy instead of an optimistic cookie check |
| `passwordHash` visible in page source | Whole user row passed to a Client Component |
