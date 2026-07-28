# Deployment

---

## Targets

| Target | Gets you | Costs |
|---|---|---|
| Vercel | ISR, image optimization, edge, preview URLs, analytics — zero config | Platform pricing, vendor coupling |
| Node server | Full control, any host | You operate the cache, images, and scaling |
| Docker | Portable, works with any orchestrator | Same, plus image and runtime management |
| Static export | Any static host, no server | No Actions, handlers, ISR, image optimization, or proxy |
| Adapters (alpha) | Platform-specific build integration | Immature API |

---

## Vercel

```bash
npm i -g vercel
vercel            # preview
vercel --prod     # production
```

Everything works without configuration: ISR, image optimization, streaming, Server Actions, proxy, and cron.

Preview deployments per branch are the main workflow advantage. Two things to set on them:

```ts
export const metadata: Metadata = {
  robots: process.env.VERCEL_ENV === 'preview' ? { index: false, follow: false } : undefined,
}
```

Preview URLs indexed as duplicate content is a common, avoidable SEO problem. Deployment Protection also gates previews behind auth.

Cron:

```json
// vercel.json
{ "crons": [{ "path": "/api/cron/cleanup", "schedule": "0 3 * * *" }] }
```

```ts
export async function GET(request: Request) {
  if (request.headers.get('authorization') !== `Bearer ${process.env.CRON_SECRET}`) {
    return new Response('Unauthorized', { status: 401 })
  }
  await cleanup()
  return Response.json({ ok: true })
}
```

Always check `CRON_SECRET` — the path is publicly reachable.

---

## Self-Hosted Node

```ts
// next.config.ts
const nextConfig = { output: 'standalone' }
```

```bash
npm run build
node .next/standalone/server.js
```

`standalone` traces only the files actually needed. Static assets are **not** included — copy them:

```bash
cp -r public .next/standalone/public
cp -r .next/static .next/standalone/.next/static
```

Missing this step is the most common self-hosting failure: the app boots, HTML renders, and every asset 404s.

### Cache handler for multiple instances

With more than one instance, the default filesystem ISR cache is per-instance. One instance revalidates, the others keep serving stale.

```ts
// next.config.ts
const nextConfig = {
  cacheHandler: require.resolve('./cache-handler.js'),
  cacheMaxMemorySize: 0,     // disable the in-memory layer when using a shared store
}
```

`@neshca/cache-handler` provides a Redis-backed implementation. Under Cache Components, `cacheHandlers` configures per-directive handlers and `'use cache: remote'` is the shared-cache path.

### Image optimization

`next/image` optimization needs `sharp`:

```bash
npm install sharp
```

Without it, self-hosted image optimization is disabled or falls back to unoptimized delivery. Alternatively point at an external optimizer with `images.loader`.

---

## Docker

```dockerfile
FROM node:20-alpine AS base

FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs \
 && adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
ENV PORT=3000 HOSTNAME=0.0.0.0

CMD ["node", "server.js"]
```

Node 20.9+ is required by Next.js 16.

`HOSTNAME=0.0.0.0` is required, or the server binds to localhost inside the container and health checks fail.

**Build-time vs runtime env.** `NEXT_PUBLIC_*` values are inlined during `npm run build`, so they must be present as build args — setting them at `docker run` does nothing. Server-only variables can be supplied at runtime.

```dockerfile
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
RUN npm run build
```

This forces a rebuild per environment. Where that is unacceptable, fetch config at runtime from a server component instead of using `NEXT_PUBLIC_`.

---

## Static Export

```ts
const nextConfig = {
  output: 'export',
  images: { unoptimized: true },
}
```

Disabled: Server Actions, route handlers, proxy/middleware, ISR, `next/image` optimization, dynamic routes without `generateStaticParams`, cookies and headers, draft mode, and `'use cache'`.

Right for docs sites and marketing pages that hit an external API from the client. Wrong for anything with server-side logic.

---

## Runtime Selection

```ts
export const runtime = 'nodejs'    // default
export const runtime = 'edge'
```

Edge starts faster and runs closer to users but has no Node built-ins and no most database drivers. Use it for lightweight request logic: geolocation, feature flags, redirects, simple auth checks.

Next 16's `proxy.ts` runs on Node.js, unlike Edge middleware in earlier versions.

---

## Health Checks

```ts
// app/api/health/route.ts
export const dynamic = 'force-dynamic'

export async function GET() {
  try {
    await db.$queryRaw`SELECT 1`
    return Response.json({ status: 'ok', timestamp: new Date().toISOString() })
  } catch {
    return Response.json({ status: 'degraded' }, { status: 503 })
  }
}
```

Exclude the path from proxy auth matchers, or the orchestrator gets a 302 and marks the instance unhealthy.

---

## Observability

```ts
// instrumentation.ts
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    await import('./instrumentation.node')
  }
}

export function onRequestError(err: unknown, request: Request, context: unknown) {
  // Server errors including RSC render failures
}
```

Track: error rate and `digest` correlation, p75 Core Web Vitals from the field, TTFB by route, cache hit rate, and build duration. Ship source maps to the error tracker or production stack traces are unreadable.

---

## Pre-Deploy Checklist

- `npm run build` clean; route legend matches expectations.
- `npm run start` verified locally — dev server behavior differs on caching.
- Typecheck, lint, unit tests, and e2e green against the production build.
- All required env vars set on the target; `.env.example` current.
- No secret behind `NEXT_PUBLIC_`.
- Security headers and CSP configured.
- `robots: { index: false }` on preview and staging.
- Sitemap and robots reachable.
- Error tracking wired with source maps.
- Cache handler configured if running multiple instances.
- `sharp` installed if self-hosting with `next/image`.
- Static assets copied alongside `standalone`.
- Health endpoint excluded from auth matchers.
- Rollback path known.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Assets 404 with `standalone` | `public/` and `.next/static` not copied |
| Container unreachable | `HOSTNAME` not set to `0.0.0.0` |
| `NEXT_PUBLIC_` wrong in the image | Set at runtime instead of as a build arg |
| ISR inconsistent across instances | Per-instance filesystem cache; needs a shared handler |
| Images unoptimized when self-hosted | `sharp` not installed |
| Static export missing features | `output: 'export'` disables all server features |
| Health checks fail | Endpoint caught by a proxy auth matcher |
| Cron endpoint hit by strangers | No `CRON_SECRET` check |
| Preview URLs in search results | No `robots: { index: false }` on preview |
| Unreadable production stack traces | Source maps not uploaded |
