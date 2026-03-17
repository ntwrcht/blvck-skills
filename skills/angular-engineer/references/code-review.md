# Angular Code Review Checklist

Use this checklist when reviewing a PR. Flag every item that applies — explain *why* it's a problem,
not just that it is one. Suggest the correct fix inline.

---

## Components & Templates

- [ ] **Default change detection** — component uses `Default` when `OnPush` would work. Flag with: "This component has no mutable state that requires Default CD — switch to OnPush to avoid unnecessary re-renders."
- [ ] **Memory leaks** — subscription without `takeUntil(destroy$)` or `async` pipe. Any `.subscribe()` not paired with unsubscribe is a leak.
- [ ] **Method calls in templates** — `{{ getLabel() }}` or `[value]="compute(item)"` re-executes on every change detection cycle. Pre-compute with a pure pipe or derived observable instead.
- [ ] **Missing trackBy** — `*ngFor` over an array of objects without `trackBy`. DOM is fully rebuilt on every emission.
- [ ] **Smart/dumb boundary broken** — presentational component calling a service directly, or container component doing DOM manipulation.

---

## Architecture & Structure

- [ ] **Duplicate shared code** — new pipe, directive, utility, or component that already exists in `src/app/shared/`. Always check shared before creating.
- [ ] **Service provided in wrong module** — feature service registered in `AppModule` instead of its feature module. Creates a singleton when scoped instance is intended.
- [ ] **Direct HttpClient in feature service** — feature services must go through `ApiService`, not `HttpClient` directly. Breaks centralized error handling and base URL management.
- [ ] **Untyped `any`** — `any` without an inline `// WHY:` comment explaining why a proper type isn't feasible.
- [ ] **Eager feature import** — feature module imported eagerly in `AppModule` instead of lazy-loaded via `loadChildren`.

---

## Styles & Design System

- [ ] **Hardcoded values** — hex colors (`#1976d2`), raw pixel values (`padding: 16px`), or font names (`font-family: 'Roboto'`) instead of `$variables.scss` tokens.
- [ ] **Missing variables import** — SCSS file uses `$variable` without `@use`/`@import '_variables'` at the top.
- [ ] **Bootstrap vs Material misuse** — using Bootstrap components where Angular Material is the standard (or vice versa). See the comparison table in SKILL.md.

---

## Error Handling & HTTP

- [ ] **Unhandled HTTP errors** — `.subscribe()` with no `error` handler or no `catchError` in the pipe. Silent failures are worse than noisy ones.
- [ ] **Wrong interceptor order** — interceptors must be registered: auth → token-refresh → error. Wrong order breaks the 401 refresh cycle.
- [ ] **GlobalErrorHandler missing** — `AppModule` providers don't include `{ provide: ErrorHandler, useClass: GlobalErrorHandler }`.
- [ ] **Error messages in components** — user-facing error strings hardcoded in component logic instead of routed through `NotificationService`.

---

## Auth & Security

- [ ] **Guards missing on lazy modules** — lazy-loaded route has `canActivate` but no `canLoad` (ng14–15) or `canMatch` (ng15+). Unauthenticated users can still download the JS bundle.
- [ ] **JWT decoded without expiry check** — `atob(token.split('.')[1])` without checking `payload.exp * 1000 < Date.now()`. Expired tokens silently pass as valid.
- [ ] **Sensitive data in route state** — passwords, tokens, or PII passed via `router.navigate([], { state: ... })`. State survives in `history.state` and is accessible to any script.

---

## Forms

- [ ] **Validator with side effects** — validator function makes an HTTP call or mutates external state. Validators must be pure functions — use async validators for HTTP checks.
- [ ] **Async validator without debounce** — async validator fires on every keystroke without `debounceTime(300)` / `timer(300)`. Will hammer the API.
- [ ] **Cross-field validation at control level** — cross-field validators (e.g. password confirm) applied to individual `FormControl` instead of the parent `FormGroup`.
- [ ] **Missing error state in template** — `formControlName` bound but no `*ngIf="control.invalid && control.touched"` guard showing error messages.

---

## RxJS

- [ ] **Nested subscriptions** — `.subscribe()` inside another `.subscribe()`. Always flatten with `switchMap`, `concatMap`, or `mergeMap`.
- [ ] **Wrong flattening operator** — `mergeMap` for navigation-driven requests (use `switchMap` to cancel previous), or `switchMap` for ordered queues (use `concatMap`).
- [ ] **Missing shareReplay** — observable consumed by multiple components simultaneously without `shareReplay(1)`. Triggers multiple HTTP calls.
- [ ] **Subject exposed directly** — `BehaviorSubject` exposed as public property instead of `.asObservable()`. Allows external callers to push values.

---
 
## Signals (ng17+)
 
- [ ] **`effect()` used for state derivation** — `effect()` that calls `.set()` on another signal instead of using `computed()`. Effect is for side effects only (DOM, localStorage, analytics).
- [ ] **Signal written inside `effect()` without `allowSignalWrites: true`** — creates infinite loop risk.
- [ ] **Plain property alongside signals** — component mixes `count = 0` and `total = signal(0)`. Pick one pattern per component.
- [ ] **`input()` mutated inside component** — signal inputs are read-only. Never call `.set()` on an `input()`.
- [ ] **`toSignal()` called outside injection context** — must be called in constructor, field initializer, or with explicit `injector`. Calling inside a method throws.
- [ ] **Zone-less component with setTimeout writing to plain property** — in zone-less apps, only signal writes trigger CD. Plain property mutations are invisible.
- [ ] **Missing `asReadonly()`** — service exposes writable signal directly (`readonly users = signal([])`). External components can mutate state. Use `_users.asReadonly()` for the public surface.

---

## Testing

- [ ] **Missing spec file** — implementation file has no `.spec.ts` counterpart.
- [ ] **BrowserAnimationsModule in tests** — use `NoopAnimationsModule` instead, or tests will be slow and flaky.
- [ ] **CSS selectors in queries** — `By.css('.btn-primary')` instead of `By.css('[data-testid="submit-btn"]')`. Class names change; test IDs don't.
- [ ] **Real HTTP in unit tests** — service tested without `HttpClientTestingModule`. Unit tests must never hit the network.
- [ ] **No arrange/act/assert structure** — test body is a wall of code with no clear separation. Makes failure diagnosis harder.

---

## Review Comment Format

When flagging an issue, use this structure:

```
❌ [Category] Short description of the problem
WHY: One sentence on why this matters (performance / memory / security / maintainability)
FIX: Concrete suggestion or code snippet
```

Example:
```
❌ [Memory leak] Subscription in ngOnInit has no takeUntil
WHY: This subscription stays alive after the component is destroyed, holding references and potentially causing duplicate side effects.
FIX: Add private destroy$ = new Subject<void>() and pipe takeUntil(this.destroy$) before subscribe. Call this.destroy$.next() in ngOnDestroy.
```
