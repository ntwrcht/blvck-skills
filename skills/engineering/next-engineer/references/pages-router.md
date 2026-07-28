# Pages Router

Still supported and still common. A repo can run both routers side by side — `app/` takes precedence when a path exists in both.

Match the tree the file you are touching lives in. Do not import App Router APIs into `pages/`.

---

## API Differences

| Concern | Pages Router | App Router |
|---|---|---|
| Routing hooks | `next/router` (`useRouter`) | `next/navigation` |
| Head tags | `next/head` | Metadata API |
| Data fetching | `getServerSideProps` / `getStaticProps` | `async` Server Components |
| Layout | `_app.tsx` | `layout.tsx` per segment |
| Document shell | `_document.tsx` | root `layout.tsx` |
| API | `pages/api/*.ts` | `app/**/route.ts` |
| Mutations | API route + client fetch | Server Actions |
| Errors | `_error.tsx`, `404.tsx`, `500.tsx` | `error.tsx`, `not-found.tsx` |
| Middleware | `middleware.ts` | `proxy.ts` (Next 16+) |
| Server Components | Not available | Default |

`useRouter` from `next/router` and from `next/navigation` are different hooks with different shapes. Importing the wrong one is the most frequent hybrid-repo bug.

---

## Data Fetching

### `getServerSideProps`

```tsx
import type { GetServerSideProps } from 'next'

export const getServerSideProps: GetServerSideProps<Props> = async ({ params, req, res, query }) => {
  const session = await getSession(req)
  if (!session) {
    return { redirect: { destination: '/login', permanent: false } }
  }

  const product = await getProduct(params!.id as string)
  if (!product) return { notFound: true }

  res.setHeader('Cache-Control', 'public, s-maxage=60, stale-while-revalidate=300')
  return { props: { product } }
}

export default function ProductPage({ product }: Props) {
  return <ProductDetail product={product} />
}
```

Runs on every request. Props must be JSON-serializable — `Date` objects need explicit conversion, unlike the App Router's richer serialization.

### `getStaticProps` and `getStaticPaths`

```tsx
export const getStaticPaths: GetStaticPaths = async () => {
  const posts = await getTopPosts(100)
  return {
    paths: posts.map(p => ({ params: { slug: p.slug } })),
    fallback: 'blocking',
  }
}

export const getStaticProps: GetStaticProps = async ({ params }) => {
  const post = await getPost(params!.slug as string)
  if (!post) return { notFound: true }
  return { props: { post }, revalidate: 3600 }     // ISR
}
```

| `fallback` | Behavior for an unlisted path |
|---|---|
| `false` | 404 |
| `true` | Renders a fallback shell immediately, then hydrates with data |
| `'blocking'` | SSRs on first request, then caches — usually what you want |

With `fallback: true`, handle `router.isFallback`:

```tsx
const router = useRouter()
if (router.isFallback) return <Skeleton />
```

On-demand revalidation:

```ts
// pages/api/revalidate.ts
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.query.secret !== process.env.REVALIDATE_SECRET) {
    return res.status(401).json({ message: 'Invalid token' })
  }
  await res.revalidate('/blog/my-post')
  return res.json({ revalidated: true })
}
```

---

## `_app.tsx` and `_document.tsx`

```tsx
// pages/_app.tsx
import type { AppProps } from 'next/app'
import '@/styles/globals.css'

export default function App({ Component, pageProps }: AppProps) {
  return (
    <ThemeProvider>
      <Layout>
        <Component {...pageProps} />
      </Layout>
    </ThemeProvider>
  )
}
```

Per-page layouts:

```tsx
// pages/dashboard/index.tsx
DashboardPage.getLayout = (page: ReactElement) => <DashboardLayout>{page}</DashboardLayout>

// pages/_app.tsx
export default function App({ Component, pageProps }: AppPropsWithLayout) {
  const getLayout = Component.getLayout ?? ((page) => page)
  return getLayout(<Component {...pageProps} />)
}
```

```tsx
// pages/_document.tsx — server-only, renders once
import { Html, Head, Main, NextScript } from 'next/document'

export default function Document() {
  return (
    <Html lang="en">
      <Head />          {/* document-level: fonts, preconnect — NOT per-page title */}
      <body>
        <Main />
        <NextScript />
      </body>
    </Html>
  )
}
```

`_document` never runs on the client. No event handlers, no hooks, no `useEffect`. Per-page tags go in `next/head`.

---

## API Routes

```ts
// pages/api/products/[id].ts
import type { NextApiRequest, NextApiResponse } from 'next'

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const { id } = req.query

  switch (req.method) {
    case 'GET': {
      const product = await getProduct(id as string)
      if (!product) return res.status(404).json({ error: 'Not found' })
      return res.status(200).json(product)
    }
    case 'DELETE': {
      const session = await getSession(req)
      if (session?.role !== 'admin') return res.status(403).json({ error: 'Forbidden' })
      await deleteProduct(id as string)
      return res.status(204).end()
    }
    default:
      res.setHeader('Allow', ['GET', 'DELETE'])
      return res.status(405).end()
  }
}
```

Config for body parsing (needed for raw webhook bodies):

```ts
export const config = { api: { bodyParser: false } }
```

---

## Head

```tsx
import Head from 'next/head'

export default function ProductPage({ product }: Props) {
  return (
    <>
      <Head>
        <title>{product.name} | Acme</title>
        <meta name="description" content={product.summary} />
        <meta property="og:image" content={product.imageUrl} />
        <link rel="canonical" href={`https://example.com/products/${product.slug}`} />
      </Head>
      <ProductDetail product={product} />
    </>
  )
}
```

Duplicate tags from nested `<Head>` are deduped by the `key` prop, not automatically.

---

## Router

```tsx
import { useRouter } from 'next/router'

const router = useRouter()
router.query.id
router.pathname
router.asPath
router.isReady          // query is empty until true on static pages
router.isFallback

router.push('/products')
router.push({ pathname: '/products', query: { category: 'shoes' } })
router.replace(url, undefined, { shallow: true })   // no data-fetching re-run
```

`router.isReady` is a real trap: on a statically optimized page `router.query` is `{}` on first render. Reading it before `isReady` gives `undefined`.

---

## Hybrid Repos

Both routers can coexist during migration:

- `app/` wins when a path exists in both. Two files serving `/about` means the `pages/` one is dead code.
- Navigating between the two trees is a **full page load**, not a client transition. State is lost.
- `_app.tsx` and `_document.tsx` apply only to `pages/`. App Router pages get `app/layout.tsx`.
- One `middleware.ts` (or `proxy.ts`) serves both.
- Global CSS imported in `_app.tsx` does not reach `app/` routes. Import it in the root layout too, or move it.

Migrate leaf routes first, shared layouts last. See `references/upgrade-migration.md`.

---

## When to Stay

Not every Pages Router app should migrate. Reasons to stay:

- The app is stable and feature-complete.
- Heavy reliance on a client-side data layer that already works.
- A dependency that has no App Router story.
- No team capacity for the rendering-model shift.

Reasons to move: bundle size wins from Server Components, streaming, simpler mutations via Server Actions, and the fact that new Next.js features ship App-Router-first.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| `useRouter` returns the wrong shape | Imported from the wrong module for the tree |
| `router.query` empty on first render | Static page — guard on `router.isReady` |
| `Error serializing props` | Non-JSON value (usually a `Date`) returned from `getServerSideProps` |
| Styles missing on App Router pages | Global CSS only imported in `_app.tsx` |
| Full reload navigating between trees | Expected — the routers do not share a client transition |
| Webhook signature fails | `bodyParser` not disabled for the API route |
| Duplicate meta tags | Nested `<Head>` without `key` props |
| `pages/` route unreachable | Same path also exists under `app/` |
