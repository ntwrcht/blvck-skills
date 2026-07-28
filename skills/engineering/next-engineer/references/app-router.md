# App Router

File-system routing in `app/`. A folder becomes a route segment; a file with a reserved name gives that segment a behavior.

---

## File Conventions

| File | Purpose |
|---|---|
| `layout.tsx` | Shared shell for a segment and its children. Preserves state across navigation within the segment. |
| `template.tsx` | Like `layout`, but remounts on every navigation. Use for enter animations or per-navigation effects. |
| `page.tsx` | The publicly routable UI for a segment. A segment without one is not routable. |
| `loading.tsx` | Suspense fallback for the segment's `page` and children. |
| `error.tsx` | Error boundary for the segment. Must be a Client Component. |
| `not-found.tsx` | UI for `notFound()` and unmatched URLs under the segment. |
| `route.ts` | HTTP handlers. Cannot coexist with `page.tsx` at the same path. |
| `default.tsx` | Fallback for an unmatched parallel-route slot. |
| `global-error.tsx` | Root-level error boundary. Replaces the root layout, so it renders its own `<html>` and `<body>`. |

Only `page.tsx` and `route.ts` make a segment publicly reachable. Everything else in the folder — components, tests, styles — is colocated and private.

---

## Segment Naming

```
app/
  (marketing)/          route group  — organizes without adding a URL segment
    about/page.tsx      → /about
  (shop)/
    layout.tsx          separate root-level layout for shop pages
    cart/page.tsx       → /cart
  blog/
    [slug]/page.tsx     → /blog/:slug
  docs/
    [...path]/page.tsx  → /docs/a/b/c   (required catch-all)
  shop/
    [[...filters]]/page.tsx → /shop and /shop/a/b  (optional catch-all)
  _components/          private folder — never routable
  @modal/               parallel route slot
```

- **Route groups** `(name)` organize files and let sibling trees have different layouts without changing URLs.
- **Private folders** `_name` are excluded from routing. Use them for colocation when a plain folder would accidentally become a route.
- **Catch-all** `[...slug]` requires at least one segment; **optional catch-all** `[[...slug]]` also matches the parent path.

---

## Params Are Async (Next 15+)

```tsx
// app/blog/[slug]/page.tsx
export default async function Page({
  params,
  searchParams,
}: {
  params: Promise<{ slug: string }>
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>
}) {
  const { slug } = await params
  const { page = '1' } = await searchParams
  // ...
}
```

`cookies()`, `headers()`, and `draftMode()` are async too. In Next 14 and earlier all of these are synchronous. Match the project's version — a synchronous `params.slug` in a Next 15+ app is a build error, and `await params` in a Next 14 app awaits a plain object (harmless but wrong-looking, and it will fail typecheck).

Codemod for the upgrade: `npx @next/codemod@latest next-async-request-api .`

---

## Layouts

```tsx
// app/dashboard/layout.tsx
export default function DashboardLayout({
  children,
  params,
}: {
  children: React.ReactNode
  params: Promise<{ team: string }>
}) {
  return (
    <section>
      <DashboardNav />
      {children}
    </section>
  )
}
```

Layouts do **not** re-render on navigation between their children. Three consequences worth internalizing:

1. **Never put an auth check only in a layout.** It will not re-run when the user navigates within the segment, and it does not protect nested Server Actions or route handlers. Check at the data source — see `references/auth-patterns.md`.
2. **Never `await` slow work at the top of a layout** unless every child genuinely needs it first. It blocks the first streamed chunk for the whole subtree. Push the `await` into a nested component and wrap it in `<Suspense>`.
3. **Layouts cannot read `searchParams`.** Only `page.tsx` receives them. If a layout needs query state, read it in the page and pass it down, or read it in a Client Component with `useSearchParams()`.

The root layout is required, must render `<html>` and `<body>`, and cannot be a Client Component. Multiple root layouts are possible by putting each in its own route group with no shared parent layout — navigating between them triggers a full page load.

---

## Navigation

```tsx
import Link from 'next/link'
import { useRouter, usePathname, useSearchParams, useParams } from 'next/navigation'

// Server Component: redirect during render
import { redirect, permanentRedirect, notFound } from 'next/navigation'
```

| API | Context | Note |
|---|---|---|
| `<Link href>` | anywhere | Prefetches on viewport entry in production. `prefetch={false}` to opt out. |
| `useRouter().push/replace` | Client only | Import from `next/navigation`, never `next/router` (that is the Pages Router). |
| `redirect(url)` | Server Components, Actions, handlers | Throws internally — call it outside `try/catch`, or the catch swallows it. |
| `notFound()` | Server Components, Actions, handlers | Renders the nearest `not-found.tsx`. |
| `useSelectedLayoutSegment()` | Client only | Active-link styling without string-matching the pathname. |

`redirect()` throwing is the single most common App Router footgun:

```tsx
// Broken — the catch swallows the redirect signal
try {
  await createUser(data)
  redirect('/dashboard')
} catch (e) {
  return { error: 'Failed' }
}

// Correct — redirect after the try block
let user
try {
  user = await createUser(data)
} catch (e) {
  return { error: 'Failed' }
}
redirect('/dashboard')
```

React 19's `unstable_rethrow` can re-throw framework signals from inside a catch if restructuring is genuinely impractical, but moving the call out is cleaner.

---

## Parallel Routes

Slots named `@folder` render alongside `children` in the same layout.

```tsx
// app/dashboard/layout.tsx
export default function Layout({
  children,
  team,
  analytics,
}: {
  children: React.ReactNode
  team: React.ReactNode
  analytics: React.ReactNode
}) {
  return (
    <>
      {children}
      <div className="grid grid-cols-2">
        {team}
        {analytics}
      </div>
    </>
  )
}
```

```
app/dashboard/
  layout.tsx
  page.tsx
  @team/page.tsx
  @team/default.tsx
  @analytics/page.tsx
  @analytics/default.tsx
```

**Next 16 requires an explicit `default.tsx` in every slot.** Builds fail without one. To reproduce the pre-16 behavior, the `default.tsx` returns `null` or calls `notFound()`.

Slots do not add URL segments. Each slot can have its own `loading.tsx` and `error.tsx`, which is the real payoff: independent streaming and independent failure per panel.

---

## Intercepting Routes

Render a route in the current layout's context instead of navigating away — the classic photo-modal pattern.

```
app/
  feed/page.tsx
  photo/[id]/page.tsx        full page (direct visit, refresh, share)
  @modal/(.)photo/[id]/page.tsx   modal (soft navigation from the feed)
  @modal/default.tsx
```

| Matcher | Matches |
|---|---|
| `(.)` | same level |
| `(..)` | one level above |
| `(..)(..)` | two levels above |
| `(...)` | from the app root |

The intercepted route must have a real non-intercepted counterpart, or a hard refresh 404s.

---

## Route Segment Config

```tsx
export const dynamic = 'force-dynamic'    // 'auto' | 'force-dynamic' | 'error' | 'force-static'
export const revalidate = 3600            // seconds, or false
export const fetchCache = 'force-no-store'
export const runtime = 'nodejs'           // 'nodejs' | 'edge'
export const preferredRegion = 'iad1'
export const maxDuration = 30
export const dynamicParams = true         // 404 unknown params when false
```

With Cache Components enabled these route-level knobs are largely superseded — caching becomes per-function via `'use cache'`. See `references/caching-revalidation.md` and `references/rendering-strategies.md`.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Route 404s despite the folder existing | No `page.tsx` in the leaf segment |
| `params.slug` is `undefined` | Next 15+ — `params` is a Promise, needs `await` |
| Build fails on a parallel route | Next 16 — slot is missing `default.tsx` |
| Redirect silently does nothing | `redirect()` called inside a `try` whose `catch` swallows it |
| Layout auth check bypassed | Layouts do not re-render on navigation; check at the data source |
| `useSearchParams()` deopts the whole page to client rendering | Wrap the component reading it in `<Suspense>` |
| `next/router` import errors | App Router uses `next/navigation` |
