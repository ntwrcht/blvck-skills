# Security

The App Router's specific risk is the server/client boundary. Data that crosses it lands in HTML that anyone can read — and the boundary is invisible in the source unless you look for `'use client'`.

---

## Server/Client Data Leakage

```tsx
// ❌ The whole row is serialized into the page payload
export default async function ProfilePage() {
  const user = await db.user.findUnique({ where: { id } })
  return <ProfileCard user={user} />   // passwordHash, email, stripeCustomerId → view-source
}

// ✅ Explicit DTO
export default async function ProfilePage() {
  const user = await db.user.findUnique({
    where: { id },
    select: { id: true, name: true, avatarUrl: true },
  })
  return <ProfileCard user={user} />
}
```

Anything passed to a Client Component is serialized into the RSC payload embedded in the HTML. `select` the fields you need, at the query.

### `server-only`

```ts
// lib/db.ts
import 'server-only'
export const db = new PrismaClient()
```

Any client module transitively importing this now fails the build instead of leaking the connection string. One line, build-time enforcement. Put it on every module touching secrets, the database, or an internal API.

### Taint APIs

```ts
import { experimental_taintObjectReference as taintObjectReference } from 'react'

export async function getUser(id: string) {
  const user = await db.user.findUnique({ where: { id } })
  taintObjectReference('Do not pass the full user object to the client', user)
  return user
}
```

```ts
import { experimental_taintUniqueValue as taintUniqueValue } from 'react'

taintUniqueValue('Do not pass the session token to the client', session, session.token)
```

Enable with `experimental: { taint: true }`. A defence in depth, not a substitute for DTOs.

---

## Environment Variables

```bash
DATABASE_URL=postgres://…          # server only
STRIPE_SECRET_KEY=sk_live_…        # server only
NEXT_PUBLIC_ANALYTICS_ID=G-XXXX    # inlined into the client bundle
```

`NEXT_PUBLIC_` values are **inlined at build time** into the JavaScript sent to browsers. There is no runtime secrecy — anything with that prefix is public forever, including in past deployments.

`serverRuntimeConfig` and `publicRuntimeConfig` were removed in Next 16. Use env vars.

Validate at boot so a missing variable fails the build rather than a request at 3am:

```ts
// lib/env.ts
import 'server-only'
import { z } from 'zod'

const schema = z.object({
  DATABASE_URL: z.string().url(),
  SESSION_SECRET: z.string().min(32),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
})

export const env = schema.parse(process.env)
```

Never log `process.env` wholesale, and never return it in an error response.

---

## XSS

```tsx
// ❌ Raw user content
<div dangerouslySetInnerHTML={{ __html: comment.body }} />

// ✅ Sanitize on the server, allowlist tags
import DOMPurify from 'isomorphic-dompurify'

const clean = DOMPurify.sanitize(comment.body, {
  ALLOWED_TAGS: ['p', 'strong', 'em', 'a', 'ul', 'ol', 'li', 'code'],
  ALLOWED_ATTR: ['href'],
})
return <div dangerouslySetInnerHTML={{ __html: clean }} />
```

Better: store markdown, render it server-side with a sanitizing pipeline, never store HTML.

JSX escapes `{value}` automatically. `dangerouslySetInnerHTML` is the only common way to bypass that — and it is named accordingly.

Watch for these too:

```tsx
// ❌ javascript: URLs
<a href={user.website}>Site</a>

// ✅ Validate the protocol
const safe = /^https?:\/\//.test(user.website) ? user.website : '#'
```

```tsx
// ❌ JSON-LD injection through user content
<script type="application/ld+json"
  dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }} />

// ✅ Escape the closing-tag sequence
dangerouslySetInnerHTML={{ __html: JSON.stringify(data).replace(/</g, '\\u003c') }}
```

---

## Server Actions Are Public Endpoints

Every `'use server'` export is an HTTP endpoint anyone can POST to with any payload.

```ts
// ❌ Trusts a client-supplied id
'use server'
export async function deletePost(postId: string) {
  await db.post.delete({ where: { id: postId } })
}

// ✅ Authenticate, authorize, scope
'use server'
export async function deletePost(postId: string) {
  const session = await verifySession()
  const result = await db.post.deleteMany({
    where: { id: postId, authorId: session.userId },   // ownership in the query
  })
  if (result.count === 0) throw new Error('Not found')
  revalidateTag('posts')
}
```

Non-negotiables:

- Verify the session inside the action, not in the component that renders the button.
- Authorize the specific record, not just "is logged in."
- Validate every input with a schema — `FormData` values are strings, never trust the type.
- Rate-limit anything reachable while unauthenticated.
- Keep helper functions out of `'use server'` files; every export there is public.

Next.js encrypts bound action arguments and dead-code-eliminates unused action ids. Neither is authorization.

---

## CSRF

Server Actions have built-in protection: POST-only, with an Origin/Host comparison. Behind a reverse proxy, configure the allowed origins or the check misfires:

```ts
// next.config.ts
const nextConfig = {
  experimental: { serverActions: { allowedOrigins: ['app.example.com'] } },
}
```

Route handlers have **no** built-in CSRF protection. A cookie-authenticated `POST /api/…` needs an explicit origin check or a CSRF token. `SameSite=Lax` cookies block the common cases but are not a complete answer for state-changing GETs or cross-subdomain setups.

---

## Content Security Policy

Nonce-based, from the proxy:

```ts
// proxy.ts
export function proxy(request: NextRequest) {
  const nonce = Buffer.from(crypto.randomUUID()).toString('base64')
  const csp = [
    `default-src 'self'`,
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'`,
    `style-src 'self' 'unsafe-inline'`,
    `img-src 'self' blob: data: https:`,
    `font-src 'self'`,
    `object-src 'none'`,
    `base-uri 'self'`,
    `form-action 'self'`,
    `frame-ancestors 'none'`,
    `upgrade-insecure-requests`,
  ].join('; ')

  const requestHeaders = new Headers(request.headers)
  requestHeaders.set('x-nonce', nonce)
  requestHeaders.set('Content-Security-Policy', csp)

  const response = NextResponse.next({ request: { headers: requestHeaders } })
  response.headers.set('Content-Security-Policy', csp)
  return response
}

export const config = {
  matcher: [{
    source: '/((?!api|_next/static|_next/image|favicon.ico).*)',
    missing: [
      { type: 'header', key: 'next-router-prefetch' },
      { type: 'header', key: 'purpose', value: 'prefetch' },
    ],
  }],
}
```

Excluding prefetches matters: a prefetched page carries a different nonce than the eventual render, and every script is blocked.

`style-src 'unsafe-inline'` is usually unavoidable with CSS-in-JS and Tailwind's inline critical CSS. Keep `script-src` strict.

---

## Security Headers

```ts
// next.config.ts
const nextConfig = {
  poweredByHeader: false,
  async headers() {
    return [{
      source: '/:path*',
      headers: [
        { key: 'X-Frame-Options', value: 'DENY' },
        { key: 'X-Content-Type-Options', value: 'nosniff' },
        { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
        { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
      ],
    }]
  },
}
```

---

## Open Redirects

```ts
// ❌ Attacker-controlled destination
const next = searchParams.get('next')
redirect(next)

// ✅ Allowlist by shape
const next = searchParams.get('next')
const safe = next?.startsWith('/') && !next.startsWith('//') ? next : '/dashboard'
redirect(safe)
```

The `//` check is the one people miss — `//evil.com` is a protocol-relative absolute URL, not a path.

---

## SSRF

```ts
// ❌ Fetches whatever the user names, including internal services
export async function GET(request: NextRequest) {
  const url = request.nextUrl.searchParams.get('url')
  return fetch(url!)
}
```

Allowlist hosts, reject private ranges (`127.0.0.0/8`, `10/8`, `172.16/12`, `192.168/16`, `169.254/16`, `::1`), and disable redirect following.

Next 16 blocks local-IP image optimization by default (`images.dangerouslyAllowLocalIP`) and caps redirects at 3 — both mitigations for this class.

---

## Rate Limiting

```ts
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(5, '60 s'),
})

export async function login(prev: State, formData: FormData) {
  const ip = (await headers()).get('x-forwarded-for') ?? 'unknown'
  const { success } = await ratelimit.limit(`login:${ip}`)
  if (!success) return { message: 'Too many attempts. Try again shortly.' }
  // ...
}
```

Apply to login, signup, password reset, contact forms, and any expensive unauthenticated endpoint. Limit by IP **and** by account — IP-only limiting misses distributed credential stuffing against one account.

---

## Error Disclosure

```ts
try {
  await db.order.create({ data })
} catch (error) {
  console.error('Order creation failed', { error, userId: session.userId })  // server log
  return { message: 'We could not place your order. Please try again.' }     // to the user
}
```

Never return raw error messages, stack traces, or DB errors. Next.js already redacts uncaught production errors to a digest — do not undo that by catching and echoing.

---

## Checklist

- `import 'server-only'` on every secret-touching module.
- DTO mapping at every server→client boundary.
- No secret behind `NEXT_PUBLIC_`.
- Env validated at boot.
- Every Server Action and route handler authenticates and authorizes.
- Every input validated with a schema.
- No raw user HTML without sanitization.
- CSP set, prefetches excluded from the nonce matcher.
- Security headers configured, `poweredByHeader: false`.
- Redirect targets allowlisted.
- Rate limits on unauthenticated endpoints.
- Errors logged server-side, generic messages to users.
- `npm audit` / Dependabot in CI.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Secret visible in the browser bundle | `NEXT_PUBLIC_` prefix, or missing `server-only` |
| `passwordHash` in page source | Whole row passed to a Client Component |
| Any user can delete any record | Client-supplied id trusted; no ownership scoping |
| Stored XSS via comments | `dangerouslySetInnerHTML` on unsanitized input |
| CSP blocks all scripts | Prefetch requests not excluded from the nonce matcher |
| Server Actions fail behind a proxy | `allowedOrigins` not configured |
| Phishing via `?next=` | Open redirect — allowlist and reject `//` |
| Credential stuffing succeeds | No rate limit, or IP-only limiting |
