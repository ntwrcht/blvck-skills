# Performance

Measure before changing. `next build` output and a production Lighthouse run answer most questions faster than guessing.

---

## Budgets

| Metric | Target | Usual cause when missed |
|---|---|---|
| LCP | < 2.5 s | Unoptimized hero image, blocking font, server waterfall |
| INP | < 200 ms | Heavy client JS, unmemoized expensive render |
| CLS | < 0.1 | Images without dimensions, font swap, streamed content |
| TTFB | < 600 ms | Dynamic rendering where static would do, slow DB |
| First Load JS | < 100 kB | `'use client'` too high in the tree |

---

## Images

```tsx
import Image from 'next/image'

// Above the fold — priority, no lazy load
<Image src="/hero.jpg" alt="…" width={1200} height={600} priority
       sizes="100vw" placeholder="blur" blurDataURL={heroBlur} />

// Responsive grid
<Image src={product.image} alt={product.name} width={400} height={300}
       sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw" />

// Fill a sized container
<div className="relative aspect-video">
  <Image src={url} alt="" fill className="object-cover" sizes="(max-width: 768px) 100vw, 50vw" />
</div>
```

`sizes` is the most-skipped and highest-impact prop. Without it, the browser assumes `100vw` and downloads a full-width image for a thumbnail.

`priority` goes on the LCP image only. On everything it defeats its own purpose.

**Next 16 image defaults changed:**

| Setting | Was | Now |
|---|---|---|
| `images.minimumCacheTTL` | 60 s | 14400 s (4 h) |
| `images.qualities` | `[1..100]` | `[75]` — `quality` coerces to the nearest allowed |
| `images.imageSizes` | included `16` | `16` removed |
| `images.maximumRedirects` | unlimited | 3 |
| `images.dangerouslyAllowLocalIP` | allowed | blocked by default |
| local `src` with query string | allowed | requires `images.localPatterns` |

```ts
// next.config.ts
const nextConfig = {
  images: {
    remotePatterns: [{ protocol: 'https', hostname: 'cdn.example.com', pathname: '/images/**' }],
    formats: ['image/avif', 'image/webp'],
    qualities: [50, 75, 90],
  },
}
```

`images.domains` is deprecated — use `remotePatterns`, which constrains protocol and path too.

---

## Fonts

```tsx
import { Inter } from 'next/font/google'
const inter = Inter({ subsets: ['latin'], display: 'swap', variable: '--font-sans' })
```

Self-hosted at build time, with an automatically size-adjusted fallback that eliminates swap-induced CLS. Subset to the scripts you actually use; each extra subset is bytes on the critical path.

Two or three families maximum, and only the weights in use.

---

## JavaScript Bundle

```bash
npm install -D @next/bundle-analyzer
ANALYZE=true npm run build
```

```ts
// next.config.ts
import withBundleAnalyzer from '@next/bundle-analyzer'
export default withBundleAnalyzer({ enabled: process.env.ANALYZE === 'true' })({ /* config */ })
```

Next 16.1 also ships an experimental built-in analyzer.

### The biggest lever: the client boundary

```tsx
// ❌ 'use client' at the page level pulls the whole subtree into the bundle
'use client'
export default function ProductPage({ product }) {
  const [qty, setQty] = useState(1)
  return (
    <>
      <ProductGallery images={product.images} />     {/* now client */}
      <ProductDescription html={product.html} />     {/* now client */}
      <ReviewList reviews={product.reviews} />       {/* now client */}
      <input value={qty} onChange={e => setQty(+e.target.value)} />
    </>
  )
}
```

```tsx
// ✅ Only the interactive control crosses the boundary
export default function ProductPage({ product }) {
  return (
    <>
      <ProductGallery images={product.images} />
      <ProductDescription html={product.html} />
      <ReviewList reviews={product.reviews} />
      <QuantityPicker />                              {/* the only 'use client' */}
    </>
  )
}
```

Before optimizing anything else, audit where `'use client'` sits. It is usually worth more than every other item on this page combined.

### Dynamic imports

```tsx
import dynamic from 'next/dynamic'

const Chart = dynamic(() => import('@/components/chart'), {
  loading: () => <ChartSkeleton />,
})

const Editor = dynamic(() => import('@/components/editor'), { ssr: false })
```

`ssr: false` is only allowed in Client Components. Use it for anything that touches `window` at module scope.

Good candidates: charts, rich-text editors, maps, video players, date pickers, modal bodies, admin-only panels.

### Heavy dependencies

```tsx
// ❌ Ships a syntax highlighter to every visitor
'use client'
import { Prism } from 'react-syntax-highlighter'

// ✅ Highlight on the server; the client gets HTML
import { codeToHtml } from 'shiki'
export async function CodeBlock({ code, lang }: { code: string; lang: string }) {
  const html = await codeToHtml(code, { lang, theme: 'github-dark' })
  return <div dangerouslySetInnerHTML={{ __html: html }} />
}
```

The same applies to markdown rendering, date formatting, and validation libraries — if only the output is needed, do it on the server.

Import narrowly (`import debounce from 'lodash/debounce'`, not `import { debounce } from 'lodash'`) unless the package is properly tree-shakeable.

---

## Server-Side Latency

```tsx
// ❌ Waterfall
const user = await getUser(id)
const posts = await getPosts(id)

// ✅ Parallel
const [user, posts] = await Promise.all([getUser(id), getPosts(id)])
```

Push dynamic access down and wrap it in `<Suspense>` so the shell streams while the slow part resolves. See `references/data-fetching.md` and `references/rendering-strategies.md`.

Cache what does not change per request — see `references/caching-revalidation.md`.

---

## Prefetching

`<Link>` prefetches when it enters the viewport in production. Next 16 rewrote this with layout deduplication (a shared layout downloads once, not once per link) and incremental prefetching (only the parts not already cached), so a page with 50 links transfers far less than before.

You may see more individual requests with lower total bytes. That is the intended trade.

Turn it off for links that are unlikely to be followed:

```tsx
<Link href={`/products/${id}`} prefetch={false}>…</Link>
```

Worth doing on very long lists — 500 rows prefetching on scroll is real bandwidth.

---

## Third-Party Scripts

```tsx
import Script from 'next/script'

<Script src="https://analytics.example.com/s.js" strategy="afterInteractive" />
<Script src="https://widget.example.com/w.js" strategy="lazyOnload" />
```

| Strategy | When it loads |
|---|---|
| `beforeInteractive` | Before hydration — only for scripts that must run first |
| `afterInteractive` | After hydration — default, right for analytics |
| `lazyOnload` | Browser idle — chat widgets, non-critical embeds |
| `worker` | Web worker (experimental) |

`@next/third-parties` has tuned wrappers for GA, GTM, and YouTube embeds.

---

## React Compiler

```ts
// next.config.ts (Next 16, stable)
const nextConfig = { reactCompiler: true }
```

```bash
npm install babel-plugin-react-compiler@latest
```

Automatic memoization with no source changes. Not on by default: it relies on Babel, so dev and build times increase. Measure both sides before adopting.

---

## Measuring

```tsx
// app/web-vitals.tsx
'use client'
import { useReportWebVitals } from 'next/web-vitals'

export function WebVitals() {
  useReportWebVitals(metric => {
    navigator.sendBeacon('/api/vitals', JSON.stringify(metric))
  })
  return null
}
```

Field data beats lab data. Lighthouse on a fast laptop hides the problems real users on mid-range Android hit.

```bash
npm run build && npm run start   # never profile against `next dev`
```

`next dev` has no minification, no production React, and recompiles on demand. Numbers from it mean nothing.

---

## Self-Hosting Notes

- Turbopack filesystem caching (`experimental.turbopackFileSystemCacheForDev`) speeds up cold starts on large repos.
- Next 16.2 cut `next dev` startup by roughly 400% and rendering by roughly 50%.
- `output: 'standalone'` produces a minimal server bundle for containers.
- Provide a cache handler for ISR across multiple instances — see `references/deployment.md`.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Huge First Load JS | `'use client'` high in the tree |
| Poor LCP on a hero image | Missing `priority`, or no `sizes` |
| CLS when images load | No `width`/`height` or aspect-ratio container |
| CLS when fonts swap | Not using `next/font` |
| Slow TTFB on a static-looking page | Route went dynamic — check the build output legend |
| Third-party script blocks paint | `beforeInteractive` where `afterInteractive` would do |
| Bundle grows after adding one icon | Barrel import instead of a deep import |
| Long lists stutter on scroll | 500 links prefetching — set `prefetch={false}` |
| Performance "improvements" unmeasurable | Profiled `next dev` rather than a production build |
