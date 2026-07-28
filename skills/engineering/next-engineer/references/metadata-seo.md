# Metadata and SEO

The Metadata API generates `<head>` tags from exported objects or functions. Do not hand-write `<head>` in the App Router — Next.js dedupes and merges metadata across the segment hierarchy.

---

## Static Metadata

```tsx
// app/layout.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  metadataBase: new URL('https://example.com'),
  title: {
    default: 'Acme Store',
    template: '%s | Acme Store',
  },
  description: 'Quality goods, delivered fast.',
  openGraph: {
    type: 'website',
    siteName: 'Acme Store',
    locale: 'en_US',
  },
  twitter: { card: 'summary_large_image' },
  robots: { index: true, follow: true },
}
```

`metadataBase` resolves relative image and canonical URLs. Without it, OG images end up as relative paths that crawlers cannot fetch — a silent failure that only shows up when someone shares a link.

The `template` applies to child segments. `%s` is replaced by the child's title. Use `absolute` in a child to bypass it.

---

## Dynamic Metadata

```tsx
// app/products/[slug]/page.tsx
import type { Metadata } from 'next'
import { notFound } from 'next/navigation'

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>
}): Promise<Metadata> {
  const { slug } = await params
  const product = await getProduct(slug)          // deduped with the page's own call
  if (!product) return { title: 'Not found' }

  return {
    title: product.name,
    description: product.summary,
    alternates: { canonical: `/products/${slug}` },
    openGraph: {
      title: product.name,
      description: product.summary,
      images: [{ url: product.imageUrl, width: 1200, height: 630, alt: product.name }],
      type: 'article',
    },
  }
}

export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const product = await getProduct(slug)          // same request, memoized
  if (!product) notFound()
  return <ProductDetail product={product} />
}
```

Fetching the same data in `generateMetadata` and the page is fine — `fetch` and `cache()`-wrapped calls dedupe within a render pass.

`generateMetadata` blocks the response until it resolves, so it must be fast. A slow API call there delays TTFB for the whole page.

Under Cache Components, `generateMetadata` tracks runtime data access separately from the page — reading `cookies()` there affects prerendering independently.

Do not export both `metadata` and `generateMetadata` from one file.

---

## Common Fields

```ts
export const metadata: Metadata = {
  title: 'Page title',
  description: 'Under 160 characters, written for humans.',
  keywords: ['next.js', 'react'],          // ignored by Google; harmless
  authors: [{ name: 'Jane Doe', url: 'https://example.com/jane' }],

  alternates: {
    canonical: '/products/widget',
    languages: { 'en-US': '/en-US/products/widget', 'de-DE': '/de-DE/products/widget' },
  },

  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, 'max-image-preview': 'large' },
  },

  icons: {
    icon: '/favicon.ico',
    apple: '/apple-touch-icon.png',
  },

  verification: { google: 'token', yandex: 'token' },
}
```

Set `robots: { index: false }` on staging, preview deployments, admin routes, and search result pages. Preview URLs indexed as duplicate content is a common and avoidable own goal.

---

## OG Images

### Static files

Drop these in an `app/` segment and Next.js wires the tags automatically:

```
app/opengraph-image.png     # or .jpg, .gif
app/opengraph-image.alt.txt
app/twitter-image.png
app/icon.png
app/apple-icon.png
```

### Generated at request time

```tsx
// app/products/[slug]/opengraph-image.tsx
import { ImageResponse } from 'next/og'

export const alt = 'Product preview'
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const product = await getProduct(slug)

  return new ImageResponse(
    (
      <div style={{
        width: '100%', height: '100%', display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center', background: '#0f172a', color: 'white',
      }}>
        <div style={{ fontSize: 64, fontWeight: 700 }}>{product.name}</div>
        <div style={{ fontSize: 32, opacity: 0.8 }}>${product.price}</div>
      </div>
    ),
    { ...size }
  )
}
```

`ImageResponse` supports a narrow CSS subset via Satori: flexbox only (no grid, no float), absolute positioning, and a limited set of properties. Every element with more than one child needs an explicit `display: 'flex'`.

Generation costs CPU per request. For high-traffic pages, cache the result or pregenerate.

---

## Sitemap

```ts
// app/sitemap.ts
import type { MetadataRoute } from 'next'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const products = await getAllProducts()

  const staticRoutes: MetadataRoute.Sitemap = [
    { url: 'https://example.com', lastModified: new Date(), changeFrequency: 'daily', priority: 1 },
    { url: 'https://example.com/about', changeFrequency: 'monthly', priority: 0.5 },
  ]

  const productRoutes: MetadataRoute.Sitemap = products.map(p => ({
    url: `https://example.com/products/${p.slug}`,
    lastModified: p.updatedAt,
    changeFrequency: 'weekly',
    priority: 0.8,
  }))

  return [...staticRoutes, ...productRoutes]
}
```

Over 50,000 URLs needs a sitemap index — `generateSitemaps` produces the shards.

---

## Robots

```ts
// app/robots.ts
import type { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      { userAgent: '*', allow: '/', disallow: ['/admin/', '/api/', '/checkout/'] },
    ],
    sitemap: 'https://example.com/sitemap.xml',
  }
}
```

`robots.txt` controls crawling, not indexing. A URL linked from elsewhere can still be indexed while blocked from crawling. To keep something out of the index, use `robots: { index: false }` metadata or an auth wall.

---

## Structured Data

```tsx
export default async function ProductPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const product = await getProduct(slug)

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: product.name,
    image: product.imageUrl,
    description: product.summary,
    offers: {
      '@type': 'Offer',
      price: product.price,
      priceCurrency: 'USD',
      availability: product.inStock
        ? 'https://schema.org/InStock'
        : 'https://schema.org/OutOfStock',
    },
  }

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, '\\u003c') }}
      />
      <ProductDetail product={product} />
    </>
  )
}
```

Escaping `<` blocks a `</script>` injection through product data. JSON-LD built from user-controlled fields is an XSS vector otherwise.

Validate with Google's Rich Results Test. Structured data that does not match visible page content is a manual-action risk.

---

## Viewport

Separate from metadata since Next 14:

```tsx
import type { Viewport } from 'next'

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#ffffff' },
    { media: '(prefers-color-scheme: dark)', color: '#0f172a' },
  ],
}
```

Do not set `maximumScale: 1` or `userScalable: false` — it blocks zoom, which is an accessibility failure.

---

## Rendering and SEO

Server-rendered HTML is what crawlers index. Content behind `useEffect` or a client fetch may not be seen.

- Prefer static or ISR for indexable content.
- Streamed content inside `<Suspense>` is in the initial HTML response and is indexed.
- `dynamic(..., { ssr: false })` content is **not** in the HTML — never use it for indexable copy.
- One `<h1>` per page describing the content.
- Set a canonical on any page reachable by multiple URLs (filters, tracking params, pagination).

---

## Checklist

- `metadataBase` set in the root layout.
- Title template in the root, unique titles per page.
- Descriptions under ~160 characters, written for humans.
- Canonical URLs on filterable and paginated routes.
- OG image 1200×630 with alt text.
- `sitemap.ts` and `robots.ts` present.
- `robots: { index: false }` on preview, staging, and admin.
- Structured data on product, article, and event pages, escaped.
- One `<h1>` per page; headings descend without gaps.
- `lang` on `<html>`, and `alternates.languages` if localized.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| OG image not showing in previews | Missing `metadataBase`, or a relative URL |
| Title template ignored | Child used `title.absolute` |
| Preview deployments in search results | No `robots: { index: false }` on preview |
| `ImageResponse` renders blank | Unsupported CSS; needs explicit `display: 'flex'` |
| Metadata not updating | Both `metadata` and `generateMetadata` exported |
| Slow TTFB on every page | Slow fetch inside `generateMetadata` |
| Duplicate content warnings | No canonical on filtered or paginated URLs |
| Content missing from the index | Rendered client-side only |
