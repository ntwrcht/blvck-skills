# Upgrades and Migration

---

## Version Upgrade

```bash
# Automated
npx @next/codemod@canary upgrade latest

# Manual
npm install next@latest react@latest react-dom@latest
```

Run one major version at a time. Commit after each. Skipping from 13 to 16 in one step makes it impossible to tell which change broke what.

---

## Next 15 → 16

### Requirements

| Item | Minimum |
|---|---|
| Node.js | 20.9.0 (18 no longer supported) |
| TypeScript | 5.1 |
| Browsers | Chrome/Edge/Firefox 111+, Safari 16.4+ |

### Removed

| Removed | Replacement |
|---|---|
| AMP support (`useAmp`, `config = { amp: true }`) | — |
| `next lint` | Biome or ESLint directly. Codemod: `npx @next/codemod@canary next-lint-to-eslint-cli .` |
| `serverRuntimeConfig`, `publicRuntimeConfig` | Environment variables |
| `experimental.dynamicIO` | Renamed to `cacheComponents` |
| `experimental.ppr`, `export const experimental_ppr` | Cache Components |
| `experimental.turbopack` | Top-level `turbopack` in config |
| `unstable_rootParams()` | Replacement API pending |
| Sync `params`, `searchParams` | `await params`, `await searchParams` |
| Sync `cookies()`, `headers()`, `draftMode()` | `await` them |
| `devIndicators` sub-options | Indicator remains, options gone |
| `next/image` local `src` with query strings | Requires `images.localPatterns` |

### Behavior changes

| Changed | Detail |
|---|---|
| Bundler | Turbopack is the default. Opt out with `next build --webpack`. |
| `revalidateTag()` | Requires a `cacheLife` profile as the second argument |
| Parallel routes | Every slot needs an explicit `default.js`; builds fail without one |
| `images.minimumCacheTTL` | 60 s → 14400 s |
| `images.qualities` | `[1..100]` → `[75]` |
| `images.imageSizes` | `16` removed from defaults |
| `images.maximumRedirects` | unlimited → 3 |
| `images.dangerouslyAllowLocalIP` | Local IPs blocked by default |
| `scroll-behavior: smooth` | No longer automatic; add `data-scroll-behavior="smooth"` |
| ESLint plugin | Defaults to flat config |
| Sass | `sass-loader` v16, modern API |

### Deprecated

| Deprecated | Replacement |
|---|---|
| `middleware.ts` | `proxy.ts`, function renamed to `proxy` |
| `next/legacy/image` | `next/image` |
| `images.domains` | `images.remotePatterns` |
| `revalidateTag(tag)` single-arg | `revalidateTag(tag, profile)` or `updateTag(tag)` |

### Steps

1. Bump Node to 20.9+ and TypeScript to 5.1+.
2. `npx @next/codemod@canary upgrade latest`.
3. Rename `middleware.ts` → `proxy.ts` and the exported function to `proxy`.
4. Add `default.js` to every parallel-route slot.
5. Update `revalidateTag` call sites to pass a profile, or switch to `updateTag` in Actions.
6. Move `experimental.turbopack` config to top level.
7. Replace `serverRuntimeConfig` / `publicRuntimeConfig` with env vars.
8. Replace `next lint` in scripts and CI.
9. Check image rendering — the new `qualities` and `imageSizes` defaults change output.
10. Build with Turbopack; if a custom webpack config blocks you, `--webpack` buys time.
11. Adopt Cache Components separately, after the version bump is green.

---

## Next 14 → 15

The big one is async request APIs.

```bash
npx @next/codemod@latest next-async-request-api .
```

```tsx
// Before
export default function Page({ params }: { params: { slug: string } }) {
  const cookieStore = cookies()
  return <div>{params.slug}</div>
}

// After
export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const cookieStore = await cookies()
  return <div>{slug}</div>
}
```

Also in 15:

- **`fetch` is uncached by default.** Anything relying on the implicit cache now hits the origin every request. Audit `fetch` calls and add `cache: 'force-cache'` or `next: { revalidate }` where the old behavior was intended. This one is silent — no error, just load.
- GET route handlers are no longer cached by default.
- Client Router Cache no longer caches page segments by default.
- React 19 required for the App Router.
- `useFormState` → `useActionState`.
- `next/font/google` and `@next/font` merged into `next/font`.

---

## Pages → App Router

Incremental. Both routers coexist; `app/` wins on conflicting paths.

### Order

1. **Create `app/layout.tsx`.** Port `_document.tsx` structure and `_app.tsx` providers. Global CSS must be imported here too — the `_app.tsx` import does not reach `app/`.
2. **Migrate one leaf route.** Pick something simple and static to shake out the toolchain.
3. **Move data fetching into the component.**
4. **Split client interactivity into `'use client'` leaves.**
5. **Convert API routes to route handlers**, or replace them with Server Actions where the caller is your own UI.
6. **Migrate shared layouts last** — they touch everything.
7. **Delete the `pages/` version** once the App Router one is verified.

### Translations

```tsx
// getServerSideProps → async Server Component
export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await getProduct(id)
  if (!product) notFound()
  return <ProductDetail product={product} />
}
```

```tsx
// getStaticProps + getStaticPaths → generateStaticParams + revalidate
export const revalidate = 3600
export async function generateStaticParams() {
  const posts = await getPosts()
  return posts.map(p => ({ slug: p.slug }))
}
```

```tsx
// next/head → Metadata API
export async function generateMetadata({ params }): Promise<Metadata> {
  const { slug } = await params
  const post = await getPost(slug)
  return { title: post.title, description: post.summary }
}
```

```tsx
// _app.tsx providers → app/providers.tsx
'use client'
export function Providers({ children }: { children: React.ReactNode }) {
  return <ThemeProvider>{children}</ThemeProvider>
}
```

### Traps

- `useRouter` from `next/router` does not work in `app/`. Import from `next/navigation` — different API shape too.
- Navigating between the two trees is a full page load. Client state is lost.
- CSS-in-JS needs a registry and `'use client'` in the App Router. Consider moving to CSS Modules or Tailwind during the migration rather than after.
- `getServerSideProps`-style auth redirects become DAL checks — see `references/auth-patterns.md`.
- Do not port `getServerSideProps` shape verbatim into a page-level `await`; it recreates the waterfall Server Components exist to remove.

---

## Adopting Cache Components

Separate from the version bump. Do it after 16 is stable in production.

```ts
// next.config.ts
const nextConfig = { cacheComponents: true }
```

The build now fails on any uncached dynamic access outside `<Suspense>`. Each error names a file — work through them:

1. Wrap request-data components in `<Suspense>` with a real fallback.
2. Add `'use cache'` to functions and components whose output can be shared.
3. Set `cacheLife` profiles based on how stale each thing may be.
4. Add `cacheTag` where on-demand invalidation is needed.
5. Move `cookies()`/`headers()` reads outside cached scopes; pass the values as arguments.
6. Replace `unstable_cache` call sites with `'use cache'`.
7. Switch mutation revalidation to `updateTag` where the user must see their own write.

Expect the first build to produce many errors. That is the model surfacing implicit behavior that was previously invisible — each one is a real caching decision that was being made by default.

---

## Verification

After any upgrade:

```bash
npm run build          # check the route legend for unexpected ƒ
npm run start          # never validate caching against `next dev`
npx tsc --noEmit
npm test
npx playwright test
```

Compare the build output route table before and after. A route that flipped from `○` to `ƒ` means something now reads request data — usually the silent `fetch` default change.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| `params.slug` undefined after upgrade | Next 15 — `params` is a Promise |
| Everything re-fetches, load spikes | Next 15 `fetch` default flipped to uncached |
| Build fails on parallel routes | Next 16 requires `default.js` in every slot |
| `revalidateTag` deprecation warning | Next 16 wants a `cacheLife` profile |
| Proxy not running | Renamed the file but not the exported function |
| Styles missing on App Router pages | Global CSS only imported in `_app.tsx` |
| `useRouter` crashes after migration | Wrong import for the router tree |
| Turbopack build fails | Custom webpack config — `--webpack` while porting |
| Many build errors after enabling Cache Components | Expected — each names a real caching decision |
