# State Management

Most "state management" questions in a Next.js App Router app dissolve once state is classified correctly. Reach for a library only after the first three options are ruled out.

---

## Classify First

| Kind of state | Home | Example |
|---|---|---|
| Server data | Server Component + revalidation | Product list, user profile, orders |
| Navigational / shareable | URL search params | Filters, search query, pagination, tab, sort |
| Form field values | Uncontrolled inputs / React Hook Form | Anything inside a `<form>` |
| Ephemeral UI | `useState` in the nearest Client Component | Dropdown open, hover, modal visibility |
| Cross-tree client state | Context, or Zustand/Jotai | Theme, cart drawer, editor selection |
| Client cache of server data | TanStack Query / SWR | Polling, infinite scroll, offline queue |

The most common architectural mistake is copying server data into a client store, then fighting to keep the copy fresh. If the server owns it, revalidate — do not mirror.

---

## Server Data

```tsx
export default async function ProductsPage() {
  const products = await getProducts()      // no store, no effect
  return <ProductGrid products={products} />
}
```

After a mutation, invalidate rather than patching a client copy:

```ts
'use server'
export async function updateProduct(id: string, data: FormData) {
  await db.product.update({ where: { id }, data: parse(data) })
  updateTag('products')                     // or revalidateTag / revalidatePath
}
```

The page re-renders with fresh data. There is no client cache to reconcile.

---

## URL State

Anything a user might bookmark, share, or reach with the back button belongs in the URL.

```tsx
// app/products/page.tsx — Server Component reads it directly
export default async function ProductsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; category?: string; page?: string }>
}) {
  const { q, category, page = '1' } = await searchParams
  const products = await searchProducts({ q, category, page: Number(page) })
  return <ProductGrid products={products} />
}
```

```tsx
'use client'
import { useRouter, useSearchParams, usePathname } from 'next/navigation'

export function CategoryFilter({ categories }: { categories: string[] }) {
  const searchParams = useSearchParams()
  const pathname = usePathname()
  const { replace } = useRouter()

  function select(category: string) {
    const params = new URLSearchParams(searchParams)
    category ? params.set('category', category) : params.delete('category')
    params.delete('page')
    replace(`${pathname}?${params}`, { scroll: false })
  }
  // ...
}
```

`replace` rather than `push` for filters — otherwise every keystroke lands in history.

`nuqs` gives type-safe URL state with a `useState`-like API if the manual `URLSearchParams` juggling gets repetitive.

Wrap any component calling `useSearchParams()` in `<Suspense>`, or the whole route opts out of static rendering.

---

## Local UI State

```tsx
'use client'
export function Dropdown({ items }: { items: Item[] }) {
  const [open, setOpen] = useState(false)
  return (
    <div>
      <button onClick={() => setOpen(o => !o)} aria-expanded={open}>Menu</button>
      {open && <ul>{items.map(i => <li key={i.id}>{i.label}</li>)}</ul>}
    </div>
  )
}
```

Keep it at the leaf. Lifting `open` into a global store to avoid prop drilling one level is a net loss.

---

## Context

Good for low-frequency, tree-wide values: theme, locale, feature flags, an auth DTO.

```tsx
// app/providers.tsx
'use client'
import { createContext, useContext, useState } from 'react'

const ThemeContext = createContext<{ theme: string; setTheme: (t: string) => void } | null>(null)

export function ThemeProvider({ children, initial }: { children: React.ReactNode; initial: string }) {
  const [theme, setTheme] = useState(initial)
  return <ThemeContext.Provider value={{ theme, setTheme }}>{children}</ThemeContext.Provider>
}

export function useTheme() {
  const ctx = useContext(ThemeContext)
  if (!ctx) throw new Error('useTheme must be used within ThemeProvider')
  return ctx
}
```

Two constraints:

- Context does not exist in Server Components. A Server Component nested as `children` inside a provider renders on the server and cannot read it.
- Every consumer re-renders on any change. Split high-frequency values into their own context, or use a store.

Initial value comes from the server as a prop — that avoids a flash of the wrong theme.

---

## Zustand

For cross-tree client state that changes often enough that Context re-renders hurt.

```ts
// lib/store/cart.ts
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

type CartState = {
  items: CartItem[]
  add: (item: CartItem) => void
  remove: (id: string) => void
  total: () => number
}

export const useCartStore = create<CartState>()(
  persist(
    (set, get) => ({
      items: [],
      add: item => set(s => ({ items: [...s.items, item] })),
      remove: id => set(s => ({ items: s.items.filter(i => i.id !== id) })),
      total: () => get().items.reduce((sum, i) => sum + i.price * i.quantity, 0),
    }),
    { name: 'cart' }
  )
)
```

```tsx
'use client'
export function CartBadge() {
  const count = useCartStore(s => s.items.length)   // selector — re-render only on this slice
  return <span>{count}</span>
}
```

**Persisted stores hydrate after the first client render**, so SSR HTML and the first client render disagree. Gate on a mounted flag:

```tsx
'use client'
export function CartBadge() {
  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])
  const count = useCartStore(s => s.items.length)
  return <span>{mounted ? count : 0}</span>
}
```

Never create the store at module scope on the server if it holds per-user data — module state is shared across requests. Client-only stores in `'use client'` files are fine.

---

## TanStack Query / SWR

Earn their place when data changes without a navigation: polling, infinite scroll, optimistic mutations with rollback, background refetch on focus, or offline queues.

```tsx
'use client'
import { useInfiniteQuery } from '@tanstack/react-query'

export function Feed({ initialData }: { initialData: Page }) {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
    queryKey: ['feed'],
    queryFn: ({ pageParam }) => fetch(`/api/feed?cursor=${pageParam}`).then(r => r.json()),
    initialPageParam: null,
    getNextPageParam: last => last.nextCursor,
    initialData: { pages: [initialData], pageParams: [null] },   // seeded from the server
  })
  // ...
}
```

Seeding `initialData` from a Server Component avoids a loading flash on first paint.

Do not add one of these just to fetch page-level data on mount — that is what Server Components already do, without the waterfall.

---

## Decision Path

```
Does the server own the data?
  → Server Component + revalidateTag / updateTag

Should it be shareable, bookmarkable, or in history?
  → URL search params

Is it inside a form?
  → Uncontrolled inputs, or React Hook Form

Does only one component and its children need it?
  → useState

Does a distant part of the tree need it, changing rarely?
  → Context

Changing often, read in many places?
  → Zustand / Jotai with selectors

Does it change without a navigation (poll, infinite scroll, offline)?
  → TanStack Query / SWR
```

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Hydration mismatch on a store-backed value | Persisted store hydrates after first render — gate on mounted |
| Client store perpetually stale | Server data mirrored into a store instead of revalidated |
| Whole page becomes client-rendered | `useSearchParams()` without a `<Suspense>` boundary |
| Context is `null` in a component | Consumer is a Server Component, or outside the provider |
| Every keystroke adds a history entry | `router.push` where `replace` was needed |
| Unrelated components re-render | Context value object recreated each render, or no store selector |
| Two users see each other's state | Store or client created at module scope on the server |
| Page jumps to top on filter change | `replace()` without `{ scroll: false }` |
