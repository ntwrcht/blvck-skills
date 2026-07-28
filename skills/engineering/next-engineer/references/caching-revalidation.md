# Caching and Revalidation

Next.js has **two caching models**. Which one applies is decided by one line in `next.config.*`. Read that line before writing any caching code.

```ts
// next.config.ts
const nextConfig = { cacheComponents: true }   // → Cache Components model (Next 16+)
```

| `cacheComponents` | Model | Mechanism |
|---|---|---|
| `true` | Cache Components | Opt-in. Nothing is cached unless marked `'use cache'`. |
| absent / `false` | Legacy | Implicit. Four layered caches, controlled by `fetch` options and route config. |

Mixing the two produces code that looks right and caches nothing. The rest of this file is split accordingly.

---

# Part 1 — Cache Components (Next 16+, `cacheComponents: true`)

Caching is explicit and opt-in. All dynamic code runs at request time by default. Partial Prerendering is the default rendering behavior: cached and static parts form a shell, uncached parts stream in.

## `'use cache'`

Three placements:

```tsx
// File level — every export must be an async function
'use cache'
export async function getUsers() { /* ... */ }

// Function level
export async function getData() {
  'use cache'
  return db.query('SELECT * FROM products')
}

// Component level
export async function ProductGrid({ category }: { category: string }) {
  'use cache'
  const items = await db.product.findMany({ where: { category } })
  return <Grid items={items} />
}
```

### Cache keys are automatic

The key is derived from: build ID + a hash of the function's location and signature + serialized arguments + **any closed-over variables**. Closure capture is the part that surprises people:

```tsx
async function Component({ userId }: { userId: string }) {
  const getData = async (filter: string) => {
    'use cache'
    // Key includes BOTH userId (closure) and filter (argument)
    return fetch(`/api/users/${userId}/data?filter=${filter}`)
  }
  return getData('active')
}
```

### Arguments must serialize

**Allowed as arguments:** primitives, plain objects, arrays, `Date`, `Map`, `Set`, `TypedArray`, `ArrayBuffer`, and React elements as pass-through only.
**Allowed as return values:** the same, plus JSX.
**Not allowed:** class instances, functions (except pass-through), `Symbol`, `WeakMap`/`WeakSet`, `URL` instances.

### Request APIs are forbidden inside `'use cache'`

`cookies()`, `headers()`, `searchParams`, and `params` (without `generateStaticParams`) cannot be read inside a cached scope. Read them outside and pass the value in:

```tsx
export default function Page() {
  return (
    <Suspense fallback={<div>Loading…</div>}>
      <ProfileContent />
    </Suspense>
  )
}

async function ProfileContent() {              // not cached — reads the request
  const sessionId = (await cookies()).get('session')?.value
  return <CachedContent sessionId={sessionId} />
}

async function CachedContent({ sessionId }: { sessionId: string }) {
  'use cache'                                  // sessionId is part of the key
  const data = await fetchUserData(sessionId)
  return <div>{data.name}</div>
}
```

### Pass-through composition

Non-serializable values are fine as long as the cached function never introspects them. This is how `children` and Server Actions cross a cached boundary:

```tsx
async function CachedShell({ children }: { children: React.ReactNode }) {
  'use cache'
  const nav = await getNavigation()
  return <div><Nav items={nav} />{children}</div>   {/* children passed through, not read */}
}
```

## `cacheLife`

```tsx
import { cacheLife } from 'next/cache'

export async function getPosts() {
  'use cache'
  cacheLife('hours')
  return fetch('https://api.example.com/posts').then(r => r.json())
}
```

Built-in profiles: `'seconds'`, `'minutes'`, `'hours'`, `'days'`, `'weeks'`, `'max'`. The `default` profile (used when `cacheLife` is omitted) is `stale` 5 minutes client-side, `revalidate` 15 minutes server-side, and never expires by time.

Custom profiles go in `next.config.ts`:

```ts
const nextConfig = {
  cacheComponents: true,
  cacheLife: {
    biweekly: { stale: 60 * 60 * 24, revalidate: 60 * 60 * 24 * 7, expire: 60 * 60 * 24 * 14 },
  },
}
```

- `stale` — how long the **client** router reuses the value without asking the server. Enforced minimum 30 seconds regardless of config.
- `revalidate` — how long the **server** serves the cached value before refreshing in the background.
- `expire` — hard limit; past this, requests block on a fresh render.

## `cacheTag`, `updateTag`, `revalidateTag`, `refresh`

```tsx
import { cacheTag } from 'next/cache'

export async function getProducts() {
  'use cache'
  cacheTag('products')
  return db.product.findMany()
}
```

| API | Where | Semantics |
|---|---|---|
| `updateTag(tag)` | Server Actions only | Expires **and immediately re-reads** — read-your-writes. The user sees their own change. |
| `revalidateTag(tag, profile)` | Actions, route handlers | Stale-while-revalidate. Serves stale immediately, refreshes in background. |
| `refresh()` | Server Actions only | Refreshes **uncached** data only. Does not touch the cache. |
| `revalidatePath(path)` | Actions, route handlers | Invalidates by route path rather than tag. |

```ts
'use server'
import { updateTag } from 'next/cache'

export async function createProduct(data: FormData) {
  await db.product.create({ data: parse(data) })
  updateTag('products')       // user sees the new product immediately
}
```

**`revalidateTag` changed signature in Next 16.** It now takes a `cacheLife` profile as a second argument:

```ts
revalidateTag('blog-posts', 'max')        // recommended default
revalidateTag('news-feed', 'hours')
revalidateTag('products', { expire: 3600 })
revalidateTag('blog-posts')               // ⚠️ deprecated single-argument form
```

Choosing between them: `updateTag` when the acting user must see their own write (forms, settings, anything with a submit button). `revalidateTag` when eventual consistency is fine (webhooks, CMS publish hooks, cron). `refresh()` when the stale thing was never cached — a notification count, a live metric.

## Handling non-determinism

`Math.random()`, `Date.now()`, and `crypto.randomUUID()` cannot run during prerendering. Either defer to request time:

```tsx
import { connection } from 'next/server'

async function RequestId() {
  await connection()               // opt this component into request time
  return <p>{crypto.randomUUID()}</p>
}
// caller wraps it in <Suspense>
```

or cache the result so every visitor sees the same value until revalidation.

## Runtime storage

`'use cache'` stores entries in an in-memory LRU by default.

| Environment | Behavior |
|---|---|
| Serverless | Entries typically do not survive between requests — each may be a different instance. Build-time caching still works. |
| Self-hosted | Entries persist across requests. Size via `cacheMaxMemorySize`. |

If in-memory is not enough, `'use cache: remote'` lets the platform supply a shared handler (Redis/KV) — it adds a network round trip and usually platform cost. `'use cache: private'` exists for compliance cases where runtime request data genuinely cannot be refactored out of the cached scope.

## Draft Mode

When Draft Mode is on, every cached function re-executes per request and nothing is written to cache. `draftMode().isEnabled` is readable inside `'use cache'`; `cookies()` and `headers()` still are not.

## Full picture

```tsx
export default function BlogPage() {
  return (
    <>
      <header><h1>Our Blog</h1></header>          {/* static → shell */}
      <BlogPosts />                                {/* cached → shell */}
      <Suspense fallback={<p>Loading…</p>}>
        <UserPreferences />                        {/* per-request → streams */}
      </Suspense>
    </>
  )
}

async function BlogPosts() {
  'use cache'
  cacheLife('hours')
  cacheTag('posts')
  const posts = await fetch('https://api.example.com/posts').then(r => r.json())
  return <PostList posts={posts} />
}

async function UserPreferences() {
  const theme = (await cookies()).get('theme')?.value ?? 'light'
  return <aside>Theme: {theme}</aside>
}
```

Anything that can neither prerender nor stream throws `Uncached data was accessed outside of <Suspense>` at build time. That error is the model working — it names the exact boundary you forgot.

---

# Part 2 — Legacy Model (Next 13-15, or 16 without `cacheComponents`)

Four caches, layered:

| Cache | Stores | Scope | Cleared by |
|---|---|---|---|
| Request Memoization | `fetch` return values | One render pass | End of request |
| Data Cache | `fetch` results | Across requests and deployments | `revalidateTag`, `revalidatePath`, time |
| Full Route Cache | Rendered HTML + RSC payload | Across requests | Data Cache invalidation, redeploy |
| Router Cache | RSC payload | Client, per session | `router.refresh()`, Action revalidation, time |

## `fetch` control

```ts
// Next 15+ default: uncached.  Next 14 and earlier default: cached.
await fetch(url, { cache: 'force-cache' })
await fetch(url, { cache: 'no-store' })
await fetch(url, { next: { revalidate: 60 } })
await fetch(url, { next: { tags: ['products'] } })
```

## Non-`fetch` caching

ORM and SDK calls are not cached by `fetch` options. Wrap them:

```ts
import { unstable_cache } from 'next/cache'

export const getProducts = unstable_cache(
  async (category: string) => db.product.findMany({ where: { category } }),
  ['products'],                                  // key parts
  { revalidate: 3600, tags: ['products'] }
)
```

`unstable_cache` is superseded by `'use cache'`. In a Next 16 project prefer enabling Cache Components over adding new `unstable_cache` call sites.

## Route-level control

```tsx
export const revalidate = 3600
export const dynamic = 'force-dynamic'
export const fetchCache = 'default-no-store'
```

## Invalidation

```ts
'use server'
import { revalidatePath, revalidateTag } from 'next/cache'

export async function updatePost(id: string, data: FormData) {
  await db.post.update({ where: { id }, data: parse(data) })
  revalidateTag('posts')
  revalidatePath(`/blog/${id}`)
}
```

## ISR

```tsx
export const revalidate = 3600
export const dynamicParams = true    // false → 404 for params not in generateStaticParams

export async function generateStaticParams() {
  const posts = await getTopPosts()
  return posts.map(p => ({ slug: p.slug }))
}
```

Prerenders the listed params at build; others render on demand and are cached. `revalidate` sets the background refresh window.

---

## Debugging Either Model

```bash
NEXT_PRIVATE_DEBUG_CACHE=1 npm run dev
NEXT_PRIVATE_DEBUG_CACHE=1 npm run start
```

`next build` output labels each route: `○` static, `ƒ` dynamic, `●` SSG, `◐` partially prerendered. If a route you expected to be static shows `ƒ`, something in its tree reads request data.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| `'use cache'` does nothing | `cacheComponents: true` missing from `next.config.*` |
| `Uncached data was accessed outside of <Suspense>` | Dynamic component with no `'use cache'` and no boundary — add one |
| Build hangs, then "Filling a cache during prerender timed out" | A request-time Promise reached a `'use cache'` scope via props or closure |
| `next-request-in-use-cache` error | `cookies()`/`headers()` called directly inside `'use cache'` |
| Whole route went dynamic unexpectedly | A shared component reads `cookies()`/`headers()`/`searchParams` |
| User does not see their own write | Used `revalidateTag` (SWR) where `updateTag` (read-your-writes) was needed |
| Cache never hits in production, fine locally | Serverless in-memory LRU does not persist — consider `'use cache: remote'` |
| Everything re-fetches after upgrading to 15 | `fetch` default flipped to uncached |
| `revalidateTag` deprecation warning | Next 16 wants a `cacheLife` profile as the second argument |
