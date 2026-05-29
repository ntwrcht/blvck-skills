# E2E Testing — Playwright for Angular

Playwright is the recommended e2e framework for Angular. Cypress is an alternative — patterns
are similar. This file covers Playwright; adapt selectors and commands if using Cypress.

## Table of Contents
1. Setup
2. Page Object Model
3. API Interception & Mocking
4. Authentication in E2E
5. Component Testing with Playwright
6. CI Integration
7. Test Data Management
8. Common Patterns & Pitfalls

---

## 1. Setup

```bash
npm install --save-dev @playwright/test

# Install browsers
npx playwright install chromium
```

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? 'github' : 'html',

  use: {
    baseURL: 'http://localhost:4200',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'Mobile Chrome', use: { ...devices['Pixel 5'] } },
  ],

  // Start Angular dev server before tests
  webServer: {
    command: 'ng serve',
    url: 'http://localhost:4200',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
```

```json
// package.json scripts
{
  "e2e": "playwright test",
  "e2e:ui": "playwright test --ui",
  "e2e:debug": "playwright test --debug",
  "e2e:report": "playwright show-report"
}
```

---

## 2. Page Object Model

Page Objects encapsulate selectors and interactions so tests stay readable and resilient to UI changes.

```typescript
// e2e/pages/login.page.ts
import { Page, Locator, expect } from '@playwright/test';

export class LoginPage {
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  constructor(private page: Page) {
    // Always use data-testid — never CSS classes or tag names
    this.emailInput    = page.getByTestId('email-input');
    this.passwordInput = page.getByTestId('password-input');
    this.submitButton  = page.getByTestId('login-submit');
    this.errorMessage  = page.getByTestId('login-error');
  }

  async goto(): Promise<void> {
    await this.page.goto('/login');
    await expect(this.submitButton).toBeVisible();
  }

  async login(email: string, password: string): Promise<void> {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }

  async expectError(message: string): Promise<void> {
    await expect(this.errorMessage).toBeVisible();
    await expect(this.errorMessage).toContainText(message);
  }
}
```

```typescript
// e2e/pages/users.page.ts
import { Page, Locator, expect } from '@playwright/test';

export class UsersPage {
  readonly userRows: Locator;
  readonly addUserButton: Locator;
  readonly searchInput: Locator;

  constructor(private page: Page) {
    this.userRows      = page.getByTestId('user-row');
    this.addUserButton = page.getByTestId('add-user-btn');
    this.searchInput   = page.getByTestId('search-input');
  }

  async goto(): Promise<void> {
    await this.page.goto('/users');
    await expect(this.userRows.first()).toBeVisible();
  }

  async search(term: string): Promise<void> {
    await this.searchInput.fill(term);
    await this.page.waitForTimeout(350);   // debounce
  }

  async getRowCount(): Promise<number> {
    return this.userRows.count();
  }

  async deleteUser(name: string): Promise<void> {
    const row = this.page.getByTestId('user-row').filter({ hasText: name });
    await row.getByTestId('delete-btn').click();
    await this.page.getByTestId('confirm-dialog-yes').click();
  }
}
```

```typescript
// e2e/tests/users.spec.ts
import { test, expect } from '@playwright/test';
import { UsersPage } from '../pages/users.page';

test.describe('Users management', () => {
  let usersPage: UsersPage;

  test.beforeEach(async ({ page }) => {
    usersPage = new UsersPage(page);
    await usersPage.goto();
  });

  test('should search and filter users', async () => {
    const initialCount = await usersPage.getRowCount();
    await usersPage.search('alice');
    const filteredCount = await usersPage.getRowCount();
    expect(filteredCount).toBeLessThan(initialCount);
  });
});
```

---

## 3. API Interception & Mocking

Mock API responses for fast, deterministic tests. Reserve real API calls for integration tests only.

```typescript
// e2e/fixtures/users.fixture.ts
export const mockUsers = [
  { id: 1, name: 'Alice Smith', email: 'alice@test.com', role: 'admin', status: 'active' },
  { id: 2, name: 'Bob Jones', email: 'bob@test.com', role: 'viewer', status: 'active' },
];
```

```typescript
// e2e/tests/users.spec.ts
import { test, expect } from '@playwright/test';
import { mockUsers } from '../fixtures/users.fixture';

test('should display users from API', async ({ page }) => {
  // Intercept before navigation
  await page.route('**/api/users', route =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(mockUsers),
    })
  );

  await page.goto('/users');
  const rows = page.getByTestId('user-row');
  await expect(rows).toHaveCount(2);
  await expect(rows.first()).toContainText('Alice Smith');
});

test('should show error state when API fails', async ({ page }) => {
  await page.route('**/api/users', route =>
    route.fulfill({ status: 500, body: 'Internal Server Error' })
  );

  await page.goto('/users');
  await expect(page.getByTestId('error-state')).toBeVisible();
  await expect(page.getByTestId('error-state')).toContainText('Failed to load');
});

test('should handle slow API gracefully', async ({ page }) => {
  await page.route('**/api/users', async route => {
    await page.waitForTimeout(2000);   // simulate slow network
    await route.fulfill({ status: 200, body: JSON.stringify(mockUsers) });
  });

  await page.goto('/users');
  await expect(page.getByTestId('loading-spinner')).toBeVisible();
  await expect(page.getByTestId('user-row')).toHaveCount(2);
});

// Verify a specific request was made with correct payload
test('should POST correct data when creating user', async ({ page }) => {
  let capturedRequest: Record<string, unknown> | null = null;

  await page.route('**/api/users', route => {
    if (route.request().method() === 'POST') {
      capturedRequest = route.request().postDataJSON();
      route.fulfill({ status: 201, body: JSON.stringify({ id: 99, ...capturedRequest }) });
    } else {
      route.continue();
    }
  });

  // ... fill form and submit

  expect(capturedRequest).toMatchObject({ name: 'New User', role: 'viewer' });
});
```

---

## 4. Authentication in E2E

Avoid logging in through the UI for every test — it's slow and couples tests to the login flow.

### Strategy 1 — Storage state (fastest)

```typescript
// e2e/auth/setup.ts — run once to create auth state
import { chromium, FullConfig } from '@playwright/test';

async function globalSetup(config: FullConfig): Promise<void> {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  await page.goto('http://localhost:4200/login');
  await page.fill('[data-testid="email-input"]', process.env.E2E_EMAIL!);
  await page.fill('[data-testid="password-input"]', process.env.E2E_PASSWORD!);
  await page.click('[data-testid="login-submit"]');
  await page.waitForURL('**/dashboard');

  // Save auth state (cookies + localStorage)
  await page.context().storageState({ path: 'e2e/.auth/user.json' });
  await browser.close();
}

export default globalSetup;
```

```typescript
// playwright.config.ts
export default defineConfig({
  globalSetup: './e2e/auth/setup.ts',
  projects: [
    {
      name: 'authenticated',
      use: {
        storageState: 'e2e/.auth/user.json',   // reuse auth on every test
      },
      testMatch: '**/*.spec.ts',
    },
    {
      name: 'unauthenticated',
      testMatch: '**/auth/*.spec.ts',          // login page tests — no stored auth
    },
  ],
});
```

### Strategy 2 — Token injection (for JWT apps)

```typescript
// In a test's beforeEach — inject token directly without UI login
test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.evaluate((token) => {
    localStorage.setItem('auth_token', token);
  }, process.env.E2E_JWT_TOKEN);
  await page.reload();
});
```

---

## 5. Component Testing with Playwright

For testing isolated components without a full app — useful for shared UI components.

```typescript
// Install if not already included
// npm install --save-dev @playwright/experimental-ct-angular

// playwright-ct.config.ts
import { defineConfig } from '@playwright/experimental-ct-angular';

export default defineConfig({
  testDir: './src',
  testMatch: '**/*.ct.spec.ts',
  use: { ctPort: 3100 },
});
```

```typescript
// src/app/shared/components/user-card/user-card.ct.spec.ts
import { test, expect } from '@playwright/experimental-ct-angular';
import { UserCardComponent } from './user-card.component';

test('should emit delete event on button click', async ({ mount }) => {
  const events: number[] = [];

  const component = await mount(UserCardComponent, {
    props: {
      user: { id: 1, name: 'Alice', email: 'alice@test.com' },
    },
    on: {
      delete: (id: number) => events.push(id),
    },
  });

  await component.getByTestId('delete-btn').click();
  expect(events).toEqual([1]);
});
```

---

## 6. CI Integration

```yaml
# .github/workflows/e2e.yml
name: E2E Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright browsers
        run: npx playwright install --with-deps chromium

      - name: Build Angular app
        run: npm run build:prod

      - name: Run E2E tests
        run: npx playwright test
        env:
          E2E_EMAIL: ${{ secrets.E2E_EMAIL }}
          E2E_PASSWORD: ${{ secrets.E2E_PASSWORD }}

      - name: Upload report on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 7
```

**Run against production build, not `ng serve`** in CI — catches build-only issues:
```typescript
// playwright.config.ts — CI mode
webServer: process.env.CI ? {
  command: 'npx serve dist/my-app/browser -p 4200',
  url: 'http://localhost:4200',
  timeout: 60_000,
} : {
  command: 'ng serve',
  url: 'http://localhost:4200',
  reuseExistingServer: true,
},
```

---

## 7. Test Data Management

**Seed and clean up via API** — not directly in the database:

```typescript
// e2e/helpers/api.helper.ts
export class ApiHelper {
  constructor(private baseUrl: string) {}

  async createUser(data: Partial<User>): Promise<User> {
    const res = await fetch(`${this.baseUrl}/api/test/users`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Test-Key': process.env.E2E_TEST_KEY! },
      body: JSON.stringify(data),
    });
    return res.json();
  }

  async cleanupUsers(ids: number[]): Promise<void> {
    await fetch(`${this.baseUrl}/api/test/users/cleanup`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Test-Key': process.env.E2E_TEST_KEY! },
      body: JSON.stringify({ ids }),
    });
  }
}
```

```typescript
test.describe('User deletion', () => {
  let createdUserId: number;
  const api = new ApiHelper('http://localhost:4200');

  test.beforeEach(async () => {
    const user = await api.createUser({ name: 'Test User', role: 'viewer' });
    createdUserId = user.id;
  });

  test.afterEach(async () => {
    await api.cleanupUsers([createdUserId]);
  });

  test('should delete a user', async ({ page }) => {
    const usersPage = new UsersPage(page);
    await usersPage.goto();
    await usersPage.deleteUser('Test User');
    await expect(page.getByText('Test User')).not.toBeVisible();
  });
});
```

---

## 8. Common Patterns & Pitfalls

### Waiting correctly

```typescript
// ❌ Fixed waits — slow and flaky
await page.waitForTimeout(2000);

// ✅ Wait for a specific state
await expect(page.getByTestId('user-row')).toHaveCount(3);
await expect(page.getByTestId('loading-spinner')).not.toBeVisible();
await page.waitForResponse('**/api/users');
await page.waitForURL('**/dashboard');
```

### Selector priority

```typescript
// In order of preference:
page.getByRole('button', { name: 'Save' })      // 1. Accessible roles (most resilient)
page.getByTestId('save-btn')                     // 2. data-testid (explicit, stable)
page.getByLabel('Email address')                 // 3. Form labels
page.getByText('Submit')                         // 4. Visible text
page.locator('.mat-button-base')                 // 5. CSS — last resort, breaks on refactor
```

### Angular Material specifics

```typescript
// mat-select — use keyboard interaction, not click (overlay needs special handling)
const select = page.getByTestId('role-select');
await select.click();
await page.getByRole('option', { name: 'Admin' }).click();

// mat-dialog — wait for overlay
await page.getByTestId('delete-btn').click();
await expect(page.getByRole('dialog')).toBeVisible();
await page.getByRole('button', { name: 'Confirm' }).click();
await expect(page.getByRole('dialog')).not.toBeVisible();

// mat-snackbar
await expect(page.getByRole('alert')).toContainText('Saved successfully');
```
