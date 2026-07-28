# Data Fetching

Fetch in Server Components, close to where the data is used. Do not lift every request to the page and thread props down — that serializes work and blocks streaming.

---

## The Default Shape

```tsx
// app/products/[id]/page.tsx
import { notFound } from 'next/navigation'
import { getProduct } from '@/lib/data/products'

export default async function ProductPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const product = await getProduct(id)
  if (!product) notFound()

  return <ProductDetail product={product} />
}
```

No `useEffect`, no loading state, no client fetch library. The component is async and awaits directly.

---

## The Data Access Layer

Put reads in `lib/data/` (or `server/`, or whatever the project already uses), not inline in components. This is the seam where authorization, caching, and DTO mapping live — three concerns that get forgotten when the query is inline in JSX.

```ts
// lib/data/products.ts
import 'server-only'
import { cache } from 'react'
import { db } from '@/lib/db'
import { verifySession } from '@/lib/dal'

export const getProduct = cache(async (id: string) => {
  const product = await db.product.findUnique({
    where: { id },
    select: { id: true, name: true, price: true, imageUrl: true },
  })
  return product
})

export const getOrder = cache(async (id: string) => {
  const session = await verifySession()
  const order = await db.order.findUnique({ where: { id } })
  // Authorize at the data source, not at the route
  if (!order || order.userId !== session.userId) return null
  return order
})
```

Three things earn their place here:

- `import 'server-only'` — build-time proof this never reaches the client bundle.
- `cache()` from React — dedupes within a single render pass, so three components calling `getProduct('1')` produce one query.
- `select` — returns a DTO, not the whole row. Stops `passwordHash` from riding along into a Client Component prop.

---

## `fetch` Deduplication vs `React.cache`

| Mechanism | Dedupes | Scope |
|---|---|---|
| Automatic `fetch` memoization | Identical `fetch(url, options)` calls | One render pass |
| `React.cache(fn)` | Any function — ORM queries, SDK calls | One render pass |

`fetch` is memoized automatically in Server Components. Anything that is not `fetch` — Prisma, Drizzle, an AWS SDK client — needs `cache()` to get the same behavior.

Neither survives across requests. For cross-request caching see `references/caching-revalidation.md`.

---

## Parallel vs Sequential

Sequential awaits are the most common avoidable latency in a Next.js app.

```tsx
// ❌ Waterfall — 3 round trips in series
const user = await getUser(id)
const posts = await getPosts(id)
const followers = await getFollowers(id)
```

```tsx
// ✅ One round trip's worth of wall time
const [user, posts, followers] = await Promise.all([
  getUser(id),
  getPosts(id),
  getFollowers(id),
])
```

When one request genuinely depends on another, only that pair must be sequential:

```tsx
const user = await getUser(id)
const [posts, team] = await Promise.all([
  getPosts(user.id),
  getTeam(user.teamId),
])
```

Use `Promise.allSettled` when one failure should not sink the page, and handle each result's status explicitly.

---

## Streaming with Suspense

Independent sections should not wait for each other. Give each its own boundary and the page streams progressively.

```tsx
// app/dashboard/page.tsx
import { Suspense } from 'react'

export default function Dashboard() {
  return (
    <>
      <h1>Dashboard</h1>                    {/* static, in the shell */}
      <Suspense fallback={<StatsSkeleton />}>
        <Stats />                            {/* streams when ready */}
      </Suspense>
      <Suspense fallback={<FeedSkeleton />}>
        <Feed />                             {/* streams independently */}
      </Suspense>
    </>
  )
}

async function Stats() {
  const stats = await getStats()            // slow
  return <StatsGrid data={stats} />
}
```

`loading.tsx` is sugar for wrapping the whole page in one boundary. Explicit `<Suspense>` gives finer control — prefer it whenever sections have different latencies.

**Push dynamic access down.** An `await cookies()` at the top of a layout blocks the entire subtree's first chunk. Move it into the one component that needs it and wrap that in `<Suspense>`.

---

## Preloading

Start a fetch before the component that needs it renders, without awaiting.

```ts
// lib/data/products.ts
export const preloadProduct = (id: string) => {
  void getProduct(id)   // fire, don't await — cache() dedupes the later await
}
```

```tsx
export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  preloadProduct(id)           // kicks off during the auth check
  const session = await verifySession()
  return <ProductDetail id={id} />   // awaits the already-in-flight promise
}
```

Only worth it when there is real work to overlap. Sprinkling `preload` everywhere adds noise without changing wall time.

---

## `fetch` Options by Version

```ts
// Next 15+ : uncached by default
await fetch(url)                                  // no cache
await fetch(url, { cache: 'force-cache' })        // opt in
await fetch(url, { next: { revalidate: 3600 } })  // ISR
await fetch(url, { next: { tags: ['products'] } })// tag for on-demand invalidation

// Next 14 and earlier: cached by default
await fetch(url)                                  // cached indefinitely
await fetch(url, { cache: 'no-store' })           // opt out
```

The Next 14→15 flip of the `fetch` default is a silent behavior change during upgrades. Anything that relied on the implicit cache now hits the origin on every request. See `references/upgrade-migration.md`.

With Cache Components enabled, `fetch` cache options are not the mechanism — `'use cache'` is. See `references/caching-revalidation.md`.

---

## Client-Side Fetching

Reach for it when the data is user-interactive rather than page-level: search-as-you-type, infinite scroll, polling, or anything that changes without a navigation.

```tsx
'use client'
import useSWR from 'swr'

export function LiveMetrics() {
  const { data, error, isLoading } = useSWR('/api/metrics', fetcher, {
    refreshInterval: 5000,
  })
  if (isLoading) return <Skeleton />
  if (error) return <ErrorState />
  return <MetricsGrid data={data} />
}
```

Pair it with a route handler (`references/route-handlers.md`) and check auth there — a client fetch is a public endpoint.

Do not use client fetching to work around a Server Component that "does not update." That is a revalidation problem; fix it with `revalidateTag`/`updateTag`.

---

## Sharing Data Across Server Components

Do not use React Context — it does not exist on the server. Two options:

1. `cache()` around the fetch function, then call it wherever needed. Simplest and usually correct.
2. `cache()` around a mutable holder when you need to set a value once and read it in several places within one request:

```ts
import { cache } from 'react'
export const getRequestContext = cache(() => ({ tenantId: null as string | null }))
```

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Page much slower than the sum of its parts | Sequential awaits — batch with `Promise.all` |
| Same query runs 5 times per render | Non-`fetch` call without `cache()` |
| Nothing streams; blank until everything resolves | Top-level `await` in a layout, or no `<Suspense>` boundaries |
| Secrets or extra columns visible in page source | No DTO mapping — `select` the fields you need |
| Data does not refresh after a mutation | Missing `revalidateTag`/`updateTag`/`revalidatePath` in the Action |
| `Dynamic server usage` build error | `cookies()`/`headers()` in a route expected to be static |
| Fetch hits origin on every request after upgrade | Next 15 made `fetch` uncached by default |
