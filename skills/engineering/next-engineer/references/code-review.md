# Code Review

Order findings by cost of being wrong. A leaked secret outranks a naming preference, and saying so explicitly keeps a review useful.

| Severity | Meaning |
|---|---|
| **Blocking** | Security hole, data loss, broken build, wrong behavior |
| **Should fix** | Real bug in an edge case, missing test on risky logic, meaningful performance regression |
| **Consider** | Simplification, naming, structure — author's call |

State the severity on every finding. An unlabeled list of twelve comments reads as twelve blockers.

---

## Pass 1 — Security

The highest-value pass in a Next.js review, because the failures are invisible in a diff unless you look for them.

- [ ] Every `'use server'` export verifies the session **in its own body**.
- [ ] Authorization checks the specific record, not just authentication.
- [ ] Queries scope by the session's user id rather than a client-supplied id.
- [ ] No helper functions exported from a `'use server'` file — every export is a public endpoint.
- [ ] Route handlers authenticate and authorize; a hidden URL is not access control.
- [ ] Every input validated with a schema; `FormData` values coerced, not cast.
- [ ] No whole DB row passed to a Client Component — check for `select` or a DTO.
- [ ] Modules touching secrets, the DB, or internal APIs carry `import 'server-only'`.
- [ ] No secret behind `NEXT_PUBLIC_`.
- [ ] `dangerouslySetInnerHTML` only on sanitized content.
- [ ] Redirect destinations allowlisted; `//` rejected.
- [ ] Errors returned to users are generic; details logged server-side.
- [ ] Rate limits on unauthenticated endpoints.

The one that hides best: a component that renders fine and passes tests, but passes `user` instead of `{ id, name }` and ships `passwordHash` into the HTML.

---

## Pass 2 — Server/Client Boundary

- [ ] `'use client'` sits at the interactive leaf, not on a page or layout.
- [ ] Nothing became a Client Component just to import a hook it barely uses.
- [ ] Server content passed as `children` rather than imported into a client file.
- [ ] Props crossing the boundary are serializable — no class instances or functions.
- [ ] No `useEffect` fetching data a Server Component could have awaited.
- [ ] Heavy display-only dependencies (markdown, highlighting, date formatting) stay server-side.

Check the import graph below any new `'use client'`. The bundle cost is not visible in the diff.

---

## Pass 3 — Data and Caching

- [ ] Independent fetches use `Promise.all`, not sequential awaits.
- [ ] Non-`fetch` data functions wrapped in `cache()` for per-render dedup.
- [ ] The caching model matches the project's `cacheComponents` setting.
- [ ] Mutations revalidate — `updateTag` for read-your-writes, `revalidateTag` for eventual consistency.
- [ ] `revalidateTag` passes a `cacheLife` profile (Next 16).
- [ ] No request API (`cookies`, `headers`, `searchParams`) inside a `'use cache'` scope.
- [ ] Dynamic access pushed down and wrapped in `<Suspense>`, not awaited at the top of a layout.
- [ ] Reads go through the data-access layer rather than inline queries in components.

---

## Pass 4 — Correctness

- [ ] `params` and `searchParams` awaited (Next 15+); `cookies()`, `headers()`, `draftMode()` too.
- [ ] `redirect()` and `notFound()` called outside `try/catch`.
- [ ] Expected failures returned as state; only unexpected ones thrown.
- [ ] Loading, empty, and error states all handled.
- [ ] Lists keyed by stable id, not array index.
- [ ] Parallel-route slots have `default.tsx` (Next 16).
- [ ] `useSearchParams()` consumers wrapped in `<Suspense>`.
- [ ] No auth check placed only in a layout.

---

## Pass 5 — Performance

- [ ] `next/image` with explicit dimensions and a real `sizes` value.
- [ ] `priority` on the LCP image only.
- [ ] `next/font` rather than a webfont `@import`.
- [ ] Heavy client-only components behind `dynamic()`.
- [ ] No large library imported for one function; deep imports where the package is not tree-shakeable.
- [ ] Route rendering strategy matches the content — check the build output legend.
- [ ] `prefetch={false}` on very long link lists.

---

## Pass 6 — Tests

- [ ] Behavior changes come with tests.
- [ ] Authorization paths tested for Actions and route handlers — the most commonly dropped check.
- [ ] Validation boundaries tested, not just the happy path.
- [ ] Fixed bugs come with a regression test.
- [ ] Tests query by role and label, not implementation details.
- [ ] E2E covers the flow end to end, including that a mutation actually revalidates the list.

---

## Pass 7 — Conventions

- [ ] Matches the project's existing patterns for structure, naming, and styling.
- [ ] No new dependency where an existing one suffices; new ones justified.
- [ ] TypeScript strict — no `any`, no unexplained `as`, no `@ts-ignore`.
- [ ] Errors handled at an appropriate boundary.
- [ ] No leftover `console.log`, commented-out code, or TODO without an owner.
- [ ] No `ignoreBuildErrors` or `ignoreDuringBuilds` added.

---

## Writing the Review

Lead with the conclusion:

> **Blocking (2), Should fix (3), Consider (4).** The Server Action at `app/actions/orders.ts:23` accepts a client-supplied `orderId` without an ownership check — any authenticated user can cancel any order. Everything else is contained.

Then the findings, each with file, line, why it matters, and a concrete fix:

> **Blocking** — `app/actions/orders.ts:23`
> `cancelOrder(orderId)` deletes by id with no ownership check. Any authenticated user can cancel anyone's order by guessing an id.
> ```ts
> const result = await db.order.updateMany({
>   where: { id: orderId, userId: session.userId },
>   data: { status: 'cancelled' },
> })
> if (result.count === 0) throw new Error('Not found')
> ```

> **Should fix** — `app/dashboard/page.tsx:12`
> Three sequential awaits add roughly 900 ms. They are independent — `Promise.all` cuts this to the slowest one.

> **Consider** — `components/product-card.tsx:8`
> `'use client'` is here only for the wishlist button. Extracting that button keeps the card server-rendered and drops the image gallery from the bundle.

State what you verified and what you did not. "I did not run the migration against a copy of production data" is more useful than silence.

---

## What Not to Comment On

- Formatting a linter or Prettier already governs.
- Personal style preferences with no correctness or performance argument.
- Pre-existing issues unrelated to the diff — file them separately.
- Rewrites of working code without a stated benefit.
- Speculative future requirements.

---

## Quick Reference

| Look for | Why |
|---|---|
| `'use server'` without a session check | Public endpoint, no auth |
| Whole DB row passed to a Client Component | Data leak into HTML |
| `'use client'` on a page or layout | Bundle bloat |
| Sequential `await`s | Avoidable latency |
| Mutation with no revalidation | Stale UI |
| `redirect()` inside `try/catch` | Silently swallowed |
| Missing `await` on `params` (Next 15+) | Undefined values |
| `dangerouslySetInnerHTML` on user input | Stored XSS |
| `NEXT_PUBLIC_` on a secret | Permanently public |
| Auth check only in a layout | Does not re-run on navigation |
