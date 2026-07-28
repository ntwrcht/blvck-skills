# Rendering Strategies

A route is not "static" or "dynamic" as a whole choice you make once. Next.js infers it from what the tree touches, and Partial Prerendering lets one route be both.

---

## What Makes a Route Dynamic

A route renders at request time if anything in its tree does one of these:

- reads `cookies()`, `headers()`, or `draftMode()`
- reads `searchParams` in a page
- reads `params` in a route with no `generateStaticParams`
- calls `connection()`
- performs an uncached `fetch` (Next 15+ default) or one with `cache: 'no-store'`
- sets `export const dynamic = 'force-dynamic'`

Otherwise it prerenders at build time.

The inference is transitive. One `cookies()` call in a shared header component makes every route using that header dynamic. This is the usual answer to "why did my whole site go dynamic?"

---

## Reading the Build Output

```
Route (app)                              Size     First Load JS
┌ ○ /                                    5.2 kB          92 kB
├ ● /blog/[slug]                         3.1 kB          89 kB
├ ◐ /dashboard                           8.4 kB         104 kB
└ ƒ /api/webhook                         0 B                0 B

○  (Static)             prerendered as static content
●  (SSG)                prerendered as static HTML using generateStaticParams
◐  (Partial Prerender)  prerendered as static HTML with dynamic parts streamed
ƒ  (Dynamic)            server-rendered on demand
```

This table is the fastest way to verify a rendering change actually landed. Check it before and after.

---

## Static

Default when nothing dynamic is touched. Rendered once at build, served from CDN.

```tsx
export default function AboutPage() {
  return <article>…</article>
}
```

Force it, and turn accidental dynamic access into a build error:

```tsx
export const dynamic = 'force-static'
export const dynamic = 'error'    // stricter: build fails on any dynamic API
```

`dynamic = 'error'` is the useful one during a refactor — it names the file that broke staticness instead of leaving you to diff build output.

---

## Static with Params

```tsx
// app/blog/[slug]/page.tsx
export async function generateStaticParams() {
  const posts = await getPosts()
  return posts.map(post => ({ slug: post.slug }))
}

export const dynamicParams = true    // false → 404 for unlisted slugs

export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const post = await getPost(slug)
  return <Article post={post} />
}
```

For nested dynamic segments, return every combination:

```tsx
// app/[category]/[product]/page.tsx
export async function generateStaticParams() {
  const products = await getProducts()
  return products.map(p => ({ category: p.category, product: p.slug }))
}
```

With thousands of pages, prerender the hot subset at build and let the rest render on demand:

```tsx
export async function generateStaticParams() {
  const top = await getTopPosts(100)     // only the popular ones
  return top.map(p => ({ slug: p.slug }))
}
export const dynamicParams = true        // the long tail renders on first request
```

---

## ISR

```tsx
export const revalidate = 3600   // seconds
```

After the window, the next request serves the stale page and triggers a background re-render. No user waits.

On-demand ISR from a CMS webhook:

```ts
// app/api/revalidate/route.ts
import { revalidateTag } from 'next/cache'

export async function POST(request: Request) {
  const secret = request.headers.get('x-webhook-secret')
  if (secret !== process.env.REVALIDATE_SECRET) {
    return new Response('Unauthorized', { status: 401 })
  }
  const { tag } = await request.json()
  revalidateTag(tag, 'max')     // Next 16 signature
  return Response.json({ revalidated: true })
}
```

Always gate the endpoint on a secret. An open revalidation endpoint is a free cache-stampede button for anyone who finds it.

---

## Dynamic

```tsx
export const dynamic = 'force-dynamic'
```

Or implicitly, by reading request data. Correct for dashboards, personalized pages, and anything behind auth where the whole page differs per user.

Before reaching for `force-dynamic` on a whole route, check whether only one component actually needs request data. If so, PPR or a `<Suspense>` boundary keeps the rest fast.

---

## Streaming

Send the shell immediately; stream slow parts as they resolve.

```tsx
import { Suspense } from 'react'

export default function Page() {
  return (
    <>
      <Header />                                   {/* immediate */}
      <Suspense fallback={<StatsSkeleton />}>
        <Stats />                                  {/* streams */}
      </Suspense>
      <Suspense fallback={<FeedSkeleton />}>
        <Feed />                                   {/* streams independently */}
      </Suspense>
    </>
  )
}
```

`loading.tsx` wraps the whole page in a single boundary. Explicit `<Suspense>` is better whenever sections have different latencies — one slow panel should not hold the fast ones.

Fallbacks should match the real layout's dimensions. A skeleton of the wrong height causes layout shift when content arrives, trading a loading state for a CLS penalty.

---

## Partial Prerendering

The static shell (including Suspense fallbacks) is prerendered and served instantly from the edge; dynamic holes stream in on the same response.

**Next 16+:** PPR is the default behavior when `cacheComponents: true`. The old `experimental.ppr` flag and the `export const experimental_ppr` route export were removed.

**Next 14-15:** opt in per route.

```ts
// next.config.ts (Next 15)
const nextConfig = { experimental: { ppr: 'incremental' } }
```

```tsx
// app/dashboard/page.tsx (Next 15)
export const experimental_ppr = true
```

The mental model: everything renders statically except what is inside a `<Suspense>` boundary that touches request data. The boundary is the seam between the shell and the hole.

```tsx
export default function ProductPage() {
  return (
    <>
      <ProductInfo />                              {/* static shell */}
      <Suspense fallback={<CartSkeleton />}>
        <Cart />                                   {/* reads cookies() → hole */}
      </Suspense>
    </>
  )
}
```

---

## `connection()`

Explicitly defers a component to request time without reading anything from the request:

```tsx
import { connection } from 'next/server'

async function RandomBanner() {
  await connection()
  const pick = banners[Math.floor(Math.random() * banners.length)]
  return <Banner {...pick} />
}
```

Needed under Cache Components whenever non-deterministic work (`Math.random`, `Date.now`, `crypto.randomUUID`) must produce a fresh value per request.

---

## `after()`

Run work after the response is sent — logging, analytics, cache warming — without adding to TTFB.

```tsx
import { after } from 'next/server'

export default async function Page() {
  const data = await getData()
  after(async () => {
    await logPageView({ path: '/page', at: Date.now() })
  })
  return <View data={data} />
}
```

Do not put anything the user's next request depends on inside `after()` — it is fire-and-forget.

---

## Choosing

| Content | Strategy |
|---|---|
| Marketing, docs, legal | Static |
| Blog, catalog with known slugs | Static + `generateStaticParams` |
| CMS content that changes on a schedule | ISR (`revalidate`) |
| CMS content that changes on publish | ISR + tag + webhook |
| Mostly shared page with a personalized corner | PPR / Cache Components |
| Fully personalized dashboard | Dynamic |
| Anything with a slow third-party API | Streaming with `<Suspense>` |

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Every route shows `ƒ` in build output | A shared layout or component reads `cookies()`/`headers()` |
| `Dynamic server usage: cookies` at build | Request API in a route expected to be static — add `<Suspense>` or make it dynamic |
| `generateStaticParams` produced no pages | Data source empty or unreachable at build time |
| Streaming does nothing | No `<Suspense>` boundary, or a top-level `await` before the boundary |
| Layout shift when streamed content lands | Skeleton dimensions do not match the real content |
| PPR export causes a build error in Next 16 | `experimental_ppr` was removed; use `cacheComponents` |
| ISR page never updates | Missing `revalidate`, or the webhook does not reach the deployment |
