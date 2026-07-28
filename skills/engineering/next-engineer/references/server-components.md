# Server and Client Components

The App Router renders on the server by default. `'use client'` marks a boundary, not a file — everything imported below that boundary joins the client bundle.

---

## The Boundary Rule

```
'use client' at the top of a file means:
  this module AND every module it imports
  are compiled into the client bundle.
```

It does not mean "this component runs only on the client." Client Components still prerender on the server for the initial HTML. The name describes *which bundle*, not *where it runs*.

Corollary: `'use client'` placed high in the tree (a root layout, a shared `<Providers>` that also exports UI) drags the subtree into the bundle. Put it at the interactive leaf.

---

## Choosing

| Need | Component type |
|---|---|
| Fetch data, query a database, read a secret | Server |
| `useState`, `useReducer`, `useEffect`, `useRef` | Client |
| `onClick`, `onChange`, any DOM event handler | Client |
| Browser APIs: `window`, `localStorage`, `IntersectionObserver` | Client |
| React Context provider or consumer | Client |
| Class components | Client |
| Large dependency used only for display (markdown, syntax highlight, date format) | Server — keeps it out of the bundle |
| Reading `cookies()` / `headers()` | Server |

Default to Server. Move to Client when a specific line requires it, and move only that line's component.

---

## Composition: Pass Server Content as Children

A Client Component cannot *import* a Server Component, but it can *render one passed as a prop*. This is the escape hatch for almost every "I need a client wrapper around server content" situation.

```tsx
// ❌ Pulls ServerContent into the client bundle — and it will fail if it queries a DB
'use client'
import ServerContent from './server-content'
export function Accordion() {
  const [open, setOpen] = useState(false)
  return <div>{open && <ServerContent />}</div>
}
```

```tsx
// ✅ Client shell, server content injected as children
'use client'
export function Accordion({ children }: { children: React.ReactNode }) {
  const [open, setOpen] = useState(false)
  return (
    <div>
      <button onClick={() => setOpen(!open)}>Toggle</button>
      {open && children}
    </div>
  )
}

// app/page.tsx — Server Component
export default async function Page() {
  return (
    <Accordion>
      <ServerContent />   {/* rendered on the server, streamed in as a slot */}
    </Accordion>
  )
}
```

The Server Component renders on the server; its output travels to the client as serialized RSC payload and slots into the `children` hole. The client shell never imports it.

Note the `{open && children}` subtlety: `children` is already-rendered output, so the server work happens regardless of whether `open` is true. If the content is expensive and usually hidden, lift the condition to the server or fetch on demand.

---

## Props Must Serialize

Props crossing the server→client boundary go through React's serialization. Passing something unserializable is a runtime error, not a type error.

**Allowed:** primitives, plain objects, arrays, `Date`, `Map`, `Set`, `TypedArray`, `ArrayBuffer`, Promises, JSX, and Server Action references.

**Not allowed:** functions (except Server Actions), class instances, `Symbol`, `WeakMap`/`WeakSet`, `URL` instances.

```tsx
// ❌ ORM model instances are class instances
const user = await db.user.findUnique({ where: { id } })
return <Profile user={user} />        // may fail depending on the ORM

// ✅ Map to a plain DTO — also stops over-fetching fields to the client
return <Profile user={{ id: user.id, name: user.name, avatar: user.avatarUrl }} />
```

Mapping to a DTO at the boundary is both a serialization fix and a security control. A `user` row passed whole ships `passwordHash` and `email` into the HTML payload, visible in view-source. See `references/security-patterns.md`.

---

## Streaming a Promise into a Client Component

Rather than awaiting on the server and blocking, pass the unawaited Promise and let the client `use()` it.

```tsx
// app/page.tsx — Server Component, does NOT await
export default function Page() {
  const commentsPromise = getComments()   // no await
  return (
    <Suspense fallback={<CommentsSkeleton />}>
      <Comments promise={commentsPromise} />
    </Suspense>
  )
}
```

```tsx
'use client'
import { use } from 'react'

export function Comments({ promise }: { promise: Promise<Comment[]> }) {
  const comments = use(promise)          // suspends until resolved
  return <ul>{comments.map(c => <li key={c.id}>{c.body}</li>)}</ul>
}
```

The page shell renders immediately; the comments stream in. This is the main reason to reach for `use()` over `await` — it moves the suspense boundary without moving the fetch to the client.

---

## `server-only` and `client-only`

```bash
npm install server-only client-only
```

```ts
// lib/db.ts
import 'server-only'

export async function query(sql: string) { /* uses process.env.DATABASE_URL */ }
```

Now any `'use client'` module that transitively imports `lib/db.ts` fails the build with a clear message instead of leaking the connection string into the bundle. Put `import 'server-only'` at the top of every module that touches secrets, the database, or an internal API key. It is a one-line, build-time guarantee — cheaper than any review process.

`client-only` is the mirror: it makes a module fail if imported from a Server Component. Use it for modules that touch `window` at import time.

---

## Providers

Context needs a Client Component, but the provider file can stay a thin shell so the root layout remains a Server Component.

```tsx
// app/providers.tsx
'use client'
import { ThemeProvider } from 'next-themes'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient())
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider attribute="class">{children}</ThemeProvider>
    </QueryClientProvider>
  )
}
```

```tsx
// app/layout.tsx — still a Server Component
import { Providers } from './providers'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
```

`children` passes through the client boundary as a slot, so pages below stay Server Components.

Note `useState(() => new QueryClient())` rather than a module-level instance: on the server a module-level client would be shared across all requests and all users.

---

## Third-Party Components

A package component that uses hooks but ships without `'use client'` cannot be rendered from a Server Component. Wrap it once:

```tsx
// components/carousel.tsx
'use client'
export { Carousel } from 'some-ui-lib'
```

---

## Interleaving

Server → Client → Server (via children) → Client nests arbitrarily. What cannot happen is a Client Component *importing* a Server Component. When the tree looks impossible, the answer is nearly always: hoist the data fetch to the nearest Server Component and pass results down as props, or pass rendered output as `children`.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| `useState is not a function` / hook errors | Missing `'use client'` on a component using hooks |
| `Only plain objects can be passed to Client Components` | Class instance, function, or `URL` in props |
| Secret appears in the browser bundle | Server module imported from a client subtree; add `import 'server-only'` |
| Bundle much larger than expected | `'use client'` too high in the tree — check the import graph below it |
| `window is not defined` | Browser API accessed during SSR; guard in `useEffect` or `dynamic(..., { ssr: false })` |
| Data stale after mutation | Client state duplicating server state; revalidate instead of mirroring |
| `Functions cannot be passed directly` | Callback prop to a Client Component from a Server Component — pass a Server Action or move the boundary |
