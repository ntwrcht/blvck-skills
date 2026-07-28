# Unit and Component Testing

Async Server Components are not fully supported by React Testing Library. That constraint shapes the whole strategy: extract the logic, unit test that, and cover the rendered result with e2e.

---

## Runner

| Runner | When |
|---|---|
| Vitest | Default for new projects. Fast, ESM-native, Jest-compatible API. |
| Jest | Established projects. `next/jest` handles the transform. |

Follow whatever the project already uses.

### Vitest

```ts
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import tsconfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [tsconfigPaths(), react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.ts'],
    globals: true,
    include: ['**/*.{test,spec}.{ts,tsx}'],
    exclude: ['**/node_modules/**', '**/e2e/**'],
  },
})
```

```ts
// vitest.setup.ts
import '@testing-library/jest-dom/vitest'
import { cleanup } from '@testing-library/react'
import { afterEach, vi } from 'vitest'

afterEach(cleanup)

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn(), back: vi.fn() }),
  usePathname: () => '/',
  useSearchParams: () => new URLSearchParams(),
  useParams: () => ({}),
  redirect: vi.fn(),
  notFound: vi.fn(),
}))
```

### Jest

```js
// jest.config.js
const nextJest = require('next/jest')
const createJestConfig = nextJest({ dir: './' })

module.exports = createJestConfig({
  testEnvironment: 'jest-environment-jsdom',
  setupFilesAfterEnv: ['<rootDir>/jest.setup.ts'],
  moduleNameMapper: { '^@/(.*)$': '<rootDir>/$1' },
  testPathIgnorePatterns: ['<rootDir>/e2e/'],
})
```

---

## What to Test Where

| Target | How |
|---|---|
| Client Components | RTL — render, interact, assert |
| Server Actions | Import and call directly, mock the DB |
| Data-layer functions | Import and call, mock the DB or use a test DB |
| Pure utilities | Plain unit tests |
| Route handlers | Call the exported `GET`/`POST` with a `Request` |
| Async Server Components | e2e (Playwright), not RTL |
| Full user flows | e2e |

---

## Client Components

```tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ProductFilters } from './product-filters'

describe('ProductFilters', () => {
  it('updates the URL when a category is selected', async () => {
    const replace = vi.fn()
    vi.mocked(useRouter).mockReturnValue({ replace } as never)

    render(<ProductFilters categories={['shoes', 'hats']} />)
    await userEvent.click(screen.getByRole('button', { name: 'shoes' }))

    expect(replace).toHaveBeenCalledWith(expect.stringContaining('category=shoes'))
  })
})
```

Query by role and accessible name. `getByTestId` is a fallback — if a control cannot be found by role, that is usually an accessibility defect worth fixing rather than routing around.

Use `userEvent` over `fireEvent`: it simulates the real sequence (pointer down, focus, key events) and catches bugs `fireEvent` misses.

---

## Server Actions

Actions are ordinary async functions. Call them.

```ts
import { createProduct } from '@/app/actions/products'
import { db } from '@/lib/db'
import { verifySession } from '@/lib/dal'

vi.mock('@/lib/db')
vi.mock('@/lib/dal')
vi.mock('next/cache', () => ({ revalidateTag: vi.fn(), updateTag: vi.fn() }))
vi.mock('next/navigation', () => ({ redirect: vi.fn() }))

describe('createProduct', () => {
  beforeEach(() => {
    vi.mocked(verifySession).mockResolvedValue({ userId: 'u1', role: 'admin', isAuth: true })
  })

  it('rejects an invalid price', async () => {
    const fd = new FormData()
    fd.set('name', 'Widget')
    fd.set('price', '-5')

    const result = await createProduct({}, fd)

    expect(result.errors?.price).toBeDefined()
    expect(db.product.create).not.toHaveBeenCalled()
  })

  it('refuses a non-admin', async () => {
    vi.mocked(verifySession).mockResolvedValue({ userId: 'u2', role: 'user', isAuth: true })

    const fd = new FormData()
    fd.set('name', 'Widget')
    fd.set('price', '10')

    await expect(createProduct({}, fd)).rejects.toThrow('Unauthorized')
  })
})
```

The authorization test is the one that matters most — it is the check most likely to be dropped in a later refactor, and the one with the worst consequences.

Note `redirect` is mocked. Unmocked, it throws a framework signal and the test fails for the wrong reason.

---

## Route Handlers

```ts
import { POST } from '@/app/api/products/route'
import { NextRequest } from 'next/server'

it('returns 401 without a session', async () => {
  vi.mocked(verifySession).mockResolvedValue(null)

  const request = new NextRequest('http://localhost/api/products', {
    method: 'POST',
    body: JSON.stringify({ name: 'Widget', price: 10 }),
    headers: { 'Content-Type': 'application/json' },
  })

  const response = await POST(request)
  expect(response.status).toBe(401)
})
```

---

## Server Components

A **synchronous** Server Component renders in RTL like any other component:

```tsx
it('renders the product name', () => {
  render(<ProductCard product={{ id: '1', name: 'Widget', price: 10 }} />)
  expect(screen.getByRole('heading', { name: 'Widget' })).toBeInTheDocument()
})
```

An **async** one does not. Split it:

```tsx
// ❌ Data fetch and presentation fused — untestable in RTL
export default async function ProductPage({ params }) {
  const { id } = await params
  const product = await db.product.findUnique({ where: { id } })
  return <div><h1>{product.name}</h1><p>{formatPrice(product.price)}</p></div>
}
```

```tsx
// ✅ Thin async shell + testable synchronous presentation
export default async function ProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await getProduct(id)
  if (!product) notFound()
  return <ProductDetail product={product} />
}

// components/product-detail.tsx — synchronous, unit testable
export function ProductDetail({ product }: { product: Product }) { … }
```

`getProduct` gets its own unit test; `ProductDetail` gets an RTL test; the page composition gets e2e coverage. This split is worth doing for its own sake — it also makes the components reusable.

---

## Mocking Data

MSW intercepts at the network layer, so the code under test stays unmodified.

```ts
// test/msw/server.ts
import { setupServer } from 'msw/node'
import { http, HttpResponse } from 'msw'

export const server = setupServer(
  http.get('https://api.example.com/products', () =>
    HttpResponse.json([{ id: '1', name: 'Widget', price: 10 }])
  )
)
```

```ts
// vitest.setup.ts
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

`onUnhandledRequest: 'error'` surfaces requests you forgot to mock instead of letting them silently hit the network.

For database access, prefer a real test database with transaction rollback per test over deep ORM mocks. Mocked ORMs drift from real query behavior and give false confidence.

---

## Mocking Next.js APIs

```ts
vi.mock('next/headers', () => ({
  cookies: vi.fn(async () => ({
    get: vi.fn((name: string) => (name === 'session' ? { value: 'token' } : undefined)),
    set: vi.fn(),
    delete: vi.fn(),
  })),
  headers: vi.fn(async () => new Headers({ 'x-forwarded-for': '127.0.0.1' })),
  draftMode: vi.fn(async () => ({ isEnabled: false })),
}))

vi.mock('next/cache', () => ({
  revalidatePath: vi.fn(),
  revalidateTag: vi.fn(),
  updateTag: vi.fn(),
  refresh: vi.fn(),
  unstable_cache: (fn: unknown) => fn,
}))
```

These are async in Next 15+ — the mocks must return Promises.

---

## What to Cover

Prioritize by cost of being wrong:

1. Authorization in every Server Action and route handler.
2. Validation and coercion boundaries.
3. Business rules — pricing, permissions, state machines.
4. Error paths and empty states, not just the happy path.
5. Regression tests for every fixed bug.

Do not test framework behavior (that `<Link>` navigates), implementation details (internal state names), or generated markup structure.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| `Objects are not valid as a React child` | Async Server Component rendered in RTL |
| `useRouter` is null | `next/navigation` not mocked in setup |
| `cookies is not a function` | `next/headers` not mocked, or mocked as sync |
| Test passes but production breaks | Over-mocked — mocks encode assumptions, not behavior |
| Action test fails on `redirect` | `next/navigation` unmocked; `redirect` throws by design |
| Flaky async assertions | Missing `await` on `findBy*` / `waitFor` |
| Tests leak state between cases | No `cleanup`, or shared module-level fixtures |
