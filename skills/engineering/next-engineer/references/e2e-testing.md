# End-to-End Testing

Playwright is the default for Next.js. It is the only place async Server Components, streaming, caching behavior, and full navigation flows get real coverage.

---

## Setup

```bash
npm init playwright@latest
```

```ts
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? [['github'], ['html']] : 'list',

  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    { name: 'setup', testMatch: /global\.setup\.ts/ },
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], storageState: 'e2e/.auth/user.json' },
      dependencies: ['setup'],
    },
    { name: 'mobile', use: { ...devices['Pixel 5'], storageState: 'e2e/.auth/user.json' }, dependencies: ['setup'] },
  ],

  webServer: {
    command: process.env.CI ? 'npm run build && npm run start' : 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
})
```

**Test the production build in CI.** `next dev` behaves differently from `next start` in exactly the areas e2e exists to cover: caching, prerendering, streaming, and error boundaries. A suite that only ever runs against `dev` will miss caching bugs entirely.

---

## Auth State Reuse

Log in once, reuse the storage state everywhere. This removes a login round trip from every spec.

```ts
// e2e/global.setup.ts
import { test as setup, expect } from '@playwright/test'

const authFile = 'e2e/.auth/user.json'

setup('authenticate', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Email').fill(process.env.TEST_USER_EMAIL!)
  await page.getByLabel('Password').fill(process.env.TEST_USER_PASSWORD!)
  await page.getByRole('button', { name: 'Sign in' }).click()

  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
  await page.context().storageState({ path: authFile })
})
```

Add `e2e/.auth/` to `.gitignore`.

For a spec that must be anonymous:

```ts
test.use({ storageState: { cookies: [], origins: [] } })
```

---

## Locators

```ts
page.getByRole('button', { name: 'Add to cart' })
page.getByLabel('Email address')
page.getByPlaceholder('Search products')
page.getByText('Order confirmed')
page.getByTestId('product-card')
```

Prefer role and label — they assert accessibility as a side effect and survive markup refactors. `getByTestId` when the element genuinely has no accessible identity (a chart canvas, a container).

Playwright locators auto-wait and auto-retry. Explicit sleeps are almost always a bug:

```ts
await page.waitForTimeout(2000)                       // ❌ flaky and slow
await expect(page.getByText('Saved')).toBeVisible()   // ✅ waits up to the timeout
```

---

## Page Objects

Worth it once three or more specs touch the same screen.

```ts
// e2e/pages/checkout.page.ts
import { type Page, type Locator, expect } from '@playwright/test'

export class CheckoutPage {
  readonly email: Locator
  readonly cardNumber: Locator
  readonly submit: Locator

  constructor(private page: Page) {
    this.email = page.getByLabel('Email')
    this.cardNumber = page.getByLabel('Card number')
    this.submit = page.getByRole('button', { name: 'Place order' })
  }

  async goto() {
    await this.page.goto('/checkout')
  }

  async fillPayment(details: PaymentDetails) {
    await this.email.fill(details.email)
    await this.cardNumber.fill(details.cardNumber)
  }

  async expectOrderConfirmed() {
    await expect(this.page.getByRole('heading', { name: /order confirmed/i })).toBeVisible()
  }
}
```

Keep assertions about the page's own state in the page object; keep the scenario in the spec.

---

## Network Interception

```ts
test('shows an error when the payment API fails', async ({ page }) => {
  await page.route('**/api/payment', route =>
    route.fulfill({ status: 500, body: JSON.stringify({ error: 'Gateway timeout' }) })
  )

  const checkout = new CheckoutPage(page)
  await checkout.goto()
  await checkout.fillPayment(validCard)
  await checkout.submit.click()

  await expect(page.getByRole('alert')).toContainText('Payment could not be processed')
})
```

Intercepting third-party calls (payment gateways, email, analytics) keeps the suite deterministic and off other people's rate limits. Do **not** intercept your own Server Actions — they are the thing under test.

Slow a response to assert loading UI:

```ts
await page.route('**/api/products', async route => {
  await new Promise(r => setTimeout(r, 2000))
  await route.continue()
})
```

---

## Testing Next.js Specifics

### Streaming and Suspense

```ts
test('shell renders before slow data', async ({ page }) => {
  await page.goto('/dashboard')
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()   // shell
  await expect(page.getByTestId('stats-skeleton')).toBeVisible()                 // fallback
  await expect(page.getByTestId('stats-grid')).toBeVisible()                     // streamed
  await expect(page.getByTestId('stats-skeleton')).toBeHidden()
})
```

### Server Action mutation and revalidation

```ts
test('new product appears in the list after creation', async ({ page }) => {
  await page.goto('/products/new')
  await page.getByLabel('Name').fill('Test Widget')
  await page.getByLabel('Price').fill('29.99')
  await page.getByRole('button', { name: 'Create' }).click()

  await expect(page).toHaveURL(/\/products\//)
  await page.goto('/products')
  await expect(page.getByText('Test Widget')).toBeVisible()   // proves revalidation worked
})
```

The second navigation is the point — it catches a missing `revalidateTag`, which unit tests cannot.

### Progressive enhancement

```ts
test.use({ javaScriptEnabled: false })

test('form submits without JavaScript', async ({ page }) => {
  await page.goto('/contact')
  await page.getByLabel('Message').fill('Hello')
  await page.getByRole('button', { name: 'Send' }).click()
  await expect(page.getByText('Thanks')).toBeVisible()
})
```

### Error boundaries

```ts
test('shows the error boundary when the API fails', async ({ page }) => {
  await page.route('**/api/products', route => route.abort('failed'))
  await page.goto('/products')
  await expect(page.getByRole('heading', { name: /something went wrong/i })).toBeVisible()
  await page.getByRole('button', { name: 'Try again' }).click()
})
```

---

## Test Data

Each test creates and cleans up what it needs. Shared fixtures make parallel runs interfere.

```ts
// e2e/fixtures.ts
import { test as base } from '@playwright/test'

type Fixtures = { testProduct: Product }

export const test = base.extend<Fixtures>({
  testProduct: async ({ request }, use) => {
    const res = await request.post('/api/test/products', {
      data: { name: `Test ${Date.now()}`, price: 10 },
    })
    const product = await res.json()
    await use(product)
    await request.delete(`/api/test/products/${product.id}`)
  },
})

export { expect } from '@playwright/test'
```

Gate any test-only endpoint on an env flag so it cannot exist in production:

```ts
export async function POST(request: Request) {
  if (process.env.ENABLE_TEST_API !== 'true') return new Response(null, { status: 404 })
  // ...
}
```

---

## CI

```yaml
# .github/workflows/e2e.yml
name: E2E
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci
      - run: npx playwright install --with-deps chromium
      - run: npm run build
      - run: npx playwright test
        env:
          TEST_USER_EMAIL: ${{ secrets.TEST_USER_EMAIL }}
          TEST_USER_PASSWORD: ${{ secrets.TEST_USER_PASSWORD }}
      - uses: actions/upload-artifact@v4
        if: ${{ !cancelled() }}
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 7
```

Node 20.9+ is the minimum for Next.js 16.

---

## Scope

Cover flows where failure is expensive: signup and login, checkout and payment, the primary create/edit path, search and filter, permission boundaries, and the top mobile flow.

Do not e2e every page or every validation message. Those are cheaper and faster as unit tests. E2E earns its runtime on integration between layers.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Passes locally, fails in CI | Dev server locally vs production build in CI |
| Flaky timing failures | `waitForTimeout` instead of web-first assertions |
| Tests interfere in parallel | Shared fixture data instead of per-test records |
| Auth setup runs per spec | Missing `dependencies: ['setup']` and `storageState` |
| Caching bugs never caught | Suite only runs against `next dev` |
| Revalidation bugs never caught | Test asserts the redirect but never revisits the list |
| Trace unavailable on failure | `trace` not set to `on-first-retry` |
