# Code Review Checklist

Flag every item that applies. Explain why it is a problem, not just that it is one. Suggest the correct fix inline.

---

## Quick Review Checklist

- [ ] Missing `OnPush` on a component with no mutable default-CD requirement
- [ ] `.subscribe()` without `takeUntilDestroyed()` or `async` pipe (ng16+)
- [ ] Method call in template — `{{ fn() }}` or `[prop]="compute(x)"`
- [ ] `*ngFor` without `trackBy`
- [ ] `window` / `document` / `localStorage` accessed without `isPlatformBrowser()` guard
- [ ] `effect()` used for state derivation instead of `computed()`
- [ ] `toSignal()` called outside injection context without `injector` / `DestroyRef`
- [ ] `@defer` opportunity missed on dialog content, tab panels, or off-screen sections
- [ ] Raw `<img>` where `NgOptimizedImage` should be used
- [ ] Hardcoded user-facing string missing `i18n` attribute
- [ ] Plural text without ICU expression
- [ ] Icon-only button without `aria-label`
- [ ] Interactive element missing keyboard handler and `role`
- [ ] Dialog that does not restore focus to the trigger on close
- [ ] Barrel import pulling an entire feature into the initial bundle

---

## Components & Templates

❌ Component uses default change detection when `OnPush` would work.
WHY: Every CD cycle walks the full component tree; `OnPush` limits checks to `@Input` reference changes and explicit marks.
```ts
// ✅ FIX
@Component({ changeDetection: ChangeDetectionStrategy.OnPush })
```

❌ Method call in template: `{{ getLabel(item) }}` or `[value]="compute(row)"`.
WHY: The method re-executes on every CD cycle regardless of whether its inputs changed.
✅ FIX: Replace with a pure pipe (`item | labelPipe`) or a `computed()` signal declared as a class field.

❌ `*ngFor` over objects without `trackBy`.
WHY: Angular destroys and recreates every DOM node on each emission, even when only one item changed.
```html
<!-- ✅ FIX -->
<li *ngFor="let u of users; trackBy: trackById">
```
```ts
trackById = (_: number, u: User) => u.id;
```

❌ Missing `@defer` block for heavy or conditionally visible content.
WHY: Dialog contents, secondary tab panels, and off-screen sections loaded eagerly inflate the initial bundle.
```html
<!-- ✅ FIX -->
@defer (on interaction) {
  <app-detail-panel [item]="selected" />
} @placeholder { <div class="skeleton"></div> }
```

---

## Services & State

- [ ] **Duplicate shared code** — pipe, directive, or utility that already exists in `src/app/shared/`.
- [ ] **Service in wrong scope** — feature service in `AppModule` instead of its feature module.
- [ ] **Direct `HttpClient`** — feature service bypasses `ApiService`, breaking centralized error handling.
- [ ] **Untyped `any`** — no inline `// WHY:` comment explaining why a proper type isn't feasible.
- [ ] **Eager feature import** — module imported eagerly instead of lazy-loaded via `loadChildren`.

❌ Subscription with no `takeUntilDestroyed()` in an ng16+ project.
WHY: The component is destroyed but the observable keeps running, holding references and triggering duplicate side effects.
```ts
// ✅ FIX
readonly #destroy = inject(DestroyRef);
ngOnInit() { this.data$.pipe(takeUntilDestroyed(this.#destroy)).subscribe(…); }
```

❌ `BehaviorSubject` exposed as a public writable property on a service.
WHY: Any caller can push values, bypassing validation logic inside the service.
```ts
// ✅ FIX
private readonly _users = new BehaviorSubject<User[]>([]);
readonly users$ = this._users.asObservable();
```

---

## RxJS

❌ Nested `.subscribe()` inside another `.subscribe()`.
WHY: Inner subscriptions are never cleaned up when the outer emits again — memory leak and duplicate executions.
```ts
// ✅ FIX
this.route.params.pipe(switchMap(({ id }) => this.api.getUser(id))).subscribe(…);
```

❌ `mergeMap` used for navigation-driven requests.
WHY: Concurrent projections let stale responses overwrite the current result.
✅ FIX: Use `switchMap` — it cancels the previous in-flight request before starting the next.

❌ Observable consumed by multiple components without `shareReplay(1)`.
WHY: Each subscriber triggers a separate HTTP request.
```ts
// ✅ FIX
readonly config$ = this.http.get<Config>('/api/config').pipe(shareReplay(1));
```

---

## Signals (ng17+)

❌ `effect()` used to write to another signal (state derivation).
WHY: `effect()` is for side effects; `computed()` is lazy, cached, and re-evaluated only when dependencies change.
```ts
// ❌  effect(() => { this.fullName.set(`${this.first()} ${this.last()}`); });
// ✅ FIX
fullName = computed(() => `${this.first()} ${this.last()}`);
```

❌ `effect()` writes a signal without `allowSignalWrites: true`.
WHY: Angular throws a runtime error and the pattern risks infinite loops.

❌ `toSignal()` called inside a method rather than in an injection context.
WHY: Calling outside a constructor or field initializer throws `NG0203`.
✅ FIX: Declare as a class field — `readonly users = toSignal(this.users$, { initialValue: [] });`

❌ `linkedSignal()` opportunity missed — a signal that is always reset when a peer signal changes.
WHY: Manual `effect()` + `.set()` reset patterns are verbose and error-prone.
```ts
// ✅ FIX
category = signal('all');
selectedId = linkedSignal(() => { this.category(); return null; });
```

❌ Service exposes writable signal on its public API.
WHY: External components can mutate service state directly, bypassing guard logic.
✅ FIX: `readonly count = this._count.asReadonly();` — keep the writable signal private.

---

## Accessibility

❌ Icon-only button with no `aria-label`.
WHY: Screen readers announce only "button", making the action undiscoverable.
```html
<!-- ✅ FIX -->
<button mat-icon-button aria-label="Delete item"><mat-icon>delete</mat-icon></button>
```

❌ Interactive `div` / `span` with `(click)` but no keyboard handler and no `role`.
WHY: Keyboard-only and switch-access users cannot trigger the action.
✅ FIX: Use a native `<button>`, or add `role="button"` + `(keydown.enter)="…"` + `(keydown.space)="…"`.

❌ `mat-form-field` with no `<mat-label>` or `aria-label` on the inner input.
WHY: Screen readers cannot identify the field's purpose.
```html
<!-- ✅ FIX -->
<mat-form-field>
  <mat-label>Email</mat-label>
  <input matInput formControlName="email" />
</mat-form-field>
```

❌ Dialog does not restore focus to the trigger element on close.
WHY: Focus drops to `<body>`, losing the user's place in the page.
```ts
// ✅ FIX
const trigger = document.activeElement as HTMLElement;
this.dialog.open(MyDialog).afterClosed().subscribe(() => trigger.focus());
```

❌ `*ngFor` list missing `role="list"` when CSS removes native semantics.
WHY: `display: flex/grid` on `<ul>` strips list semantics in Safari VoiceOver.
✅ FIX: `<ul role="list"><li *ngFor="…" role="listitem">…</li></ul>`

---

## SSR Safety

❌ Direct `window`, `document`, or `localStorage` access without `isPlatformBrowser()`.
WHY: These globals do not exist in Node.js; the server render throws a `ReferenceError`.
```ts
// ✅ FIX
constructor(@Inject(PLATFORM_ID) private platformId: object) {}
ngOnInit() {
  if (isPlatformBrowser(this.platformId)) { localStorage.getItem('token'); }
}
```

❌ Service touches browser APIs without injecting `PLATFORM_ID`.
WHY: The service crashes on the server even if its consumer is guarded.

❌ Server-fetched data re-fetched on the client — `TransferState` / `HttpTransferCache` not used.
WHY: The client hydrates and immediately fires duplicate HTTP requests for data it already has.
✅ FIX: Add `provideClientHydration(withHttpTransferCache())` to `app.config.ts`.

---

## Performance

❌ Raw `<img>` tag for above-the-fold or LCP images.
WHY: `NgOptimizedImage` adds `fetchpriority`, lazy-loads below-fold images, and generates `srcset` automatically.
```html
<!-- ✅ FIX -->
<img ngSrc="/hero.jpg" alt="Hero" width="1200" height="600" priority />
```

❌ Barrel import (`index.ts`) used to pull a single symbol from a feature.
WHY: Tree shakers cannot always eliminate dead re-exports; the whole feature can land in the initial chunk.
✅ FIX: Use direct path imports — `import { X } from '@features/foo/x/x.component'`.

❌ Feature module or standalone component not lazy-loaded.
WHY: Every eagerly imported route adds JS parse time, delaying Time to Interactive.
```ts
// ✅ FIX
{ path: 'dashboard', loadComponent: () =>
    import('./dashboard/dashboard.component').then(m => m.DashboardComponent) }
```

---

## Error Handling & HTTP

- [ ] **Unhandled HTTP errors** — `.subscribe()` with no `error` handler or `catchError`.
- [ ] **Wrong interceptor order** — must be: auth → token-refresh → error.
- [ ] **`GlobalErrorHandler` missing** — `app.config.ts` lacks `{ provide: ErrorHandler, useClass: GlobalErrorHandler }`.
- [ ] **Error messages in components** — user-facing errors hardcoded instead of routed through `NotificationService`.

---

## Auth & Security

- [ ] **`canMatch` missing on lazy routes** (ng15+) — unauthenticated users still download the JS bundle.
- [ ] **JWT decoded without expiry check** — `atob(token.split('.')[1])` without `payload.exp * 1000 < Date.now()`.
- [ ] **Sensitive data in route state** — tokens or PII in `router.navigate([], { state: … })` persist in `history.state`.

---

## Forms

- [ ] **Validator with side effects** — validator makes HTTP calls; use async validators for HTTP checks.
- [ ] **Async validator without debounce** — fires on every keystroke without `debounceTime(300)`.
- [ ] **Cross-field validation at control level** — apply to the parent `FormGroup`, not individual `FormControl`.
- [ ] **Missing error state in template** — `formControlName` bound but no `*ngIf="control.invalid && control.touched"` guard.

---

## i18n

❌ Hardcoded user-facing string with no `i18n` attribute.
WHY: Strings without `i18n` markers are invisible to `ng extract-i18n` and cannot be translated.
```html
<!-- ✅ FIX -->
<button i18n="@@profile.saveChanges">Save changes</button>
```

❌ Plural text rendered with a ternary or string interpolation.
WHY: Most languages have more than two plural forms; a ternary produces grammatically wrong output for e.g. Russian or Arabic.
```html
<!-- ✅ FIX: ICU plural expression -->
<p i18n>{count, plural, =0 {No items} =1 {One item} other {{{count}} items}}</p>
```

❌ Dynamic status text without a `select` ICU expression.
WHY: Each status value needs its own translation entry; a TypeScript switch cannot be extracted by tooling.
```html
<!-- ✅ FIX -->
<span i18n>{status, select, active {Active} inactive {Inactive} other {Unknown}}</span>
```

---

## Testing

- [ ] **Missing spec file** — implementation file has no `.spec.ts` counterpart.
- [ ] **`BrowserAnimationsModule` in tests** — use `NoopAnimationsModule`; real animations make tests slow and flaky.
- [ ] **CSS selectors in queries** — `By.css('.btn')` vs `By.css('[data-testid="submit"]')`. Class names change; test IDs do not.
- [ ] **Real HTTP in unit tests** — service tested without `provideHttpClientTesting()`.
- [ ] **No arrange/act/assert structure** — test body is a wall of code with no clear separation.

---

## Review Comment Format

```
❌ [Category] Short description of the problem
WHY: One sentence on why this matters.
FIX: Concrete suggestion or code snippet.
```

Example:
```
❌ [Memory leak] Subscription in ngOnInit has no takeUntilDestroyed
WHY: Subscription stays alive after destroy, holding references and causing duplicate side effects.
FIX: inject DestroyRef and pipe takeUntilDestroyed(this.#destroy) before subscribe.
```
