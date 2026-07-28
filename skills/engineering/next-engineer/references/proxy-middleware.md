# Proxy and Middleware

Code that runs before a request is completed — rewriting, redirecting, or modifying headers.

**Next 16 renamed `middleware.ts` to `proxy.ts`.** Same functionality, clearer name, and it runs on the Node.js runtime. `middleware.ts` still works for Edge-runtime cases but is deprecated and will be removed.

| Version | File | Runtime |
|---|---|---|
| Next 16+ | `proxy.ts` | Node.js |
| Next 12-15 | `middleware.ts` | Edge |

Match the project. Do not introduce `proxy.ts` into a Next 15 app.

---

## Location and Shape

One file at the project root, or inside `src/` — the same level as `app/` or `pages/`.

```ts
// proxy.ts  (Next 16+)
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function proxy(request: NextRequest) {
  return NextResponse.redirect(new URL('/home', request.url))
}

export const config = {
  matcher: '/about/:path*',
}
```

Either a named `proxy` export or a default export works. In Next 15 and earlier the function is named `middleware`.

Only one such file per project. Split logic into modules and compose them in the single entry point:

```ts
// proxy.ts
import { handleAuth } from '@/proxy/auth'
import { handleLocale } from '@/proxy/locale'

export async function proxy(request: NextRequest) {
  const authResponse = await handleAuth(request)
  if (authResponse) return authResponse
  return handleLocale(request)
}
```

---

## Matchers

```ts
export const config = {
  matcher: [
    // Everything except static assets, images, and metadata files
    '/((?!api|_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
```

Advanced form with conditions:

```ts
export const config = {
  matcher: [
    {
      source: '/dashboard/:path*',
      missing: [
        { type: 'header', key: 'next-router-prefetch' },
        { type: 'header', key: 'purpose', value: 'prefetch' },
      ],
    },
  ],
}
```

Matchers must be **statically analyzable** — literal strings at build time, not computed values.

The negative-lookahead pattern above is the standard starting point. Two things routinely need adding to the exclusion list: webhook paths (an auth redirect breaks the provider's POST) and health-check endpoints.

---

## What It Is Good For

- Setting or forwarding headers across many routes
- A/B tests and experiment bucketing via rewrite
- Locale detection and redirect
- Geo-based routing
- Optimistic auth redirects (cookie presence only)
- Bot filtering and simple rate limiting

## What It Is Not For

- **Session validation against a database.** It runs on every matched request including prefetches; a DB round trip there multiplies load and latency.
- **Authorization as the only defence.** Route handlers and Server Actions are reachable directly.
- **Slow data fetching.** `fetch` cache options (`cache`, `next.revalidate`, `next.tags`) have no effect here.
- **Simple static redirects.** Use `redirects` in `next.config.ts` — no per-request execution at all.

---

## Common Patterns

### Optimistic auth

```ts
import { NextResponse, type NextRequest } from 'next/server'
import { decrypt } from '@/lib/session'

const protectedRoutes = ['/dashboard', '/settings']
const publicRoutes = ['/login', '/signup', '/']

export default async function proxy(req: NextRequest) {
  const path = req.nextUrl.pathname
  const isProtected = protectedRoutes.some(r => path.startsWith(r))
  const isPublic = publicRoutes.includes(path)

  const cookie = req.cookies.get('session')?.value
  const session = await decrypt(cookie)          // cookie only — no DB

  if (isProtected && !session?.userId) {
    return NextResponse.redirect(new URL('/login', req.nextUrl))
  }
  if (isPublic && session?.userId) {
    return NextResponse.redirect(new URL('/dashboard', req.nextUrl))
  }
  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|.*\\.png$).*)'],
}
```

This is a UX optimization — it stops unauthenticated users from loading a page they cannot use. The real check happens in the Data Access Layer. See `references/auth-patterns.md`.

The one case where it *is* load-bearing: static routes shared between users, such as paywalled content. Those have no per-request render in which to check, so the proxy is the only gate.

### Rewrites and A/B tests

```ts
export function proxy(request: NextRequest) {
  const bucket = request.cookies.get('bucket')?.value
    ?? (Math.random() < 0.5 ? 'a' : 'b')

  const url = request.nextUrl.clone()
  url.pathname = `/variant-${bucket}${url.pathname}`

  const response = NextResponse.rewrite(url)
  response.cookies.set('bucket', bucket, { maxAge: 60 * 60 * 24 * 30 })
  return response
}
```

A rewrite changes what renders while the URL stays the same; a redirect changes the URL.

### Headers

```ts
export function proxy(request: NextRequest) {
  const requestHeaders = new Headers(request.headers)
  requestHeaders.set('x-pathname', request.nextUrl.pathname)   // readable via headers()

  const response = NextResponse.next({ request: { headers: requestHeaders } })
  response.headers.set('X-Frame-Options', 'DENY')
  return response
}
```

Setting `x-pathname` is a common workaround: Server Components cannot read the current URL directly, but they can read a header you injected here.

### CSP with a nonce

```ts
export function proxy(request: NextRequest) {
  const nonce = Buffer.from(crypto.randomUUID()).toString('base64')
  const csp = `default-src 'self'; script-src 'self' 'nonce-${nonce}' 'strict-dynamic'; style-src 'self' 'unsafe-inline';`

  const requestHeaders = new Headers(request.headers)
  requestHeaders.set('x-nonce', nonce)
  requestHeaders.set('Content-Security-Policy', csp)

  const response = NextResponse.next({ request: { headers: requestHeaders } })
  response.headers.set('Content-Security-Policy', csp)
  return response
}
```

Exclude prefetch requests from this matcher — a per-request nonce on a prefetched page will not match the nonce of the eventual render.

---

## Response Helpers

| Call | Effect |
|---|---|
| `NextResponse.next()` | Continue to the route |
| `NextResponse.next({ request: { headers } })` | Continue with modified request headers |
| `NextResponse.redirect(url)` | 307/308 redirect |
| `NextResponse.rewrite(url)` | Render a different path, URL unchanged |
| `NextResponse.json(body, init)` | Respond directly, skipping the route |
| `response.cookies.set(...)` | Set a cookie on the way out |

---

## Runtime Constraints

**Next 16 (`proxy.ts`)** runs on Node.js — most libraries work. Check that the auth library is compatible; some only support Edge.

**Next 12-15 (`middleware.ts`)** runs on Edge:

- No `fs`, `net`, `child_process`, or native modules
- No most database drivers
- Web Crypto only — `jose` works, `jsonwebtoken` does not
- Keep it fast: it is on the critical path of every matched request

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Not running at all | Wrong filename for the version, or wrong directory level |
| Runs on static assets and images | Matcher missing the `_next` exclusions |
| Infinite redirect loop | Redirect target itself matches the protected pattern |
| Webhooks 302 to `/login` | Webhook path not excluded from the matcher |
| Very slow first byte | DB or network call inside the proxy |
| `Module not found: fs` (Next 15) | Node API in Edge middleware |
| Nonce mismatch in CSP | Prefetch requests not excluded from the matcher |
| Cookie set but never appears | Set on a new `NextResponse` that was not returned |
| Auth bypassed on a route handler | Proxy is not a substitute for checks in the handler |
