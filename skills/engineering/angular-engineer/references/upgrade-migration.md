# Angular Version Upgrade & Migration Guide

## Table of Contents
1. Pre-Upgrade Checklist
2. The ng update Process
3. ng15 → ng16: Standalone APIs, functional guards/resolvers
4. ng16 → ng17: Control flow syntax, SSR, `@defer`
5. ng17 → ng18: Zoneless, signal forms
6. NgModule → Standalone Migration (any version)
7. RxJS/BehaviorSubject → Signals Migration
8. Common Breaking Change Patterns

---

## 1. Pre-Upgrade Checklist

Always do this before any major version upgrade:

- [ ] Check `ng update` output for peer dependency conflicts: `ng update --dry-run`
- [ ] Pin third-party Angular packages (`@ngrx/*`, `@angular/material`, `ngx-*`) — upgrade them alongside core
- [ ] Run full test suite on current version — establishes a green baseline
- [ ] Check [update.angular.io](https://update.angular.io) for the exact version pair
- [ ] Create a dedicated upgrade branch — never upgrade on `main` directly
- [ ] Upgrade one major version at a time — never skip (ng14 → ng16 directly causes hard-to-debug issues)

---

## 2. The ng update Process

```bash
# Step 1 — see what's available
ng update

# Step 2 — always upgrade core + CLI together
ng update @angular/core@16 @angular/cli@16

# Step 3 — upgrade Material and other Angular packages to match
ng update @angular/material@16

# Step 4 — upgrade NgRx if used
ng update @ngrx/store@16

# Step 5 — check for remaining peer dep issues
npm ls --depth=0 2>&1 | grep WARN

# Step 6 — run tests
ng test --watch=false && ng build
```

`ng update` runs migration schematics automatically. Read the output — it tells you exactly what it changed.

---

## 3. ng15 → ng16

### Key changes
- Standalone APIs stable (no longer experimental)
- `inject()` in class fields fully supported
- Required inputs: `@Input({ required: true })`
- `takeUntilDestroyed()` operator — replaces `takeUntil(destroy$)` pattern
- Functional guards/resolvers stable (class-based still work)

### Migrate takeUntil → takeUntilDestroyed

```typescript
// Before (ng15)
export class MyComponent implements OnDestroy {
  private destroy$ = new Subject<void>();

  ngOnInit(): void {
    this.service.data$.pipe(takeUntil(this.destroy$)).subscribe(...);
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}

// After (ng16+) — no OnDestroy needed
export class MyComponent {
  private destroyRef = inject(DestroyRef);

  ngOnInit(): void {
    this.service.data$
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(...);
  }
}

// Or at field level (no ngOnInit needed)
export class MyComponent {
  data$ = this.service.data$.pipe(takeUntilDestroyed());
}
```

### Migrate class guards → functional guards

```typescript
// Before
@Injectable({ providedIn: 'root' })
export class AuthGuard implements CanActivate {
  canActivate(): Observable<boolean> { ... }
}
// Route: canActivate: [AuthGuard]

// After (ng16+)
export const authGuard: CanActivateFn = (route, state) => {
  const auth = inject(AuthService);
  return auth.isAuthenticated$;
};
// Route: canActivate: [authGuard]
```

Run the schematic to auto-migrate guards:
```bash
ng generate @angular/core:route-lazy-loading
```

---

## 4. ng16 → ng17

### Key changes
- New control flow syntax (`@if`, `@for`, `@switch`) — replaces `*ngIf`, `*ngFor`, `*ngSwitch`
- `@defer` blocks for lazy component loading
- SSR built-in (`@angular/ssr`) — replaces `@nguniversal/express-engine`
- Standalone is the default for `ng generate`
- Vite + esbuild replaces Webpack for `ng serve`
- Signal inputs/outputs introduced (experimental → stable in ng17.1)

### Migrate control flow syntax

Run the migration schematic:
```bash
ng generate @angular/core:control-flow
```

Manual migration reference:
```html
<!-- Before -->
<div *ngIf="user; else loading">{{ user.name }}</div>
<ng-template #loading><mat-spinner /></ng-template>

<li *ngFor="let item of items; trackBy: trackById">{{ item.name }}</li>

<div [ngSwitch]="status">
  <span *ngSwitchCase="'active'">Active</span>
  <span *ngSwitchDefault>Inactive</span>
</div>

<!-- After -->
@if (user) {
  <div>{{ user.name }}</div>
} @else {
  <mat-spinner />
}

@for (item of items; track item.id) {
  <li>{{ item.name }}</li>
}

@switch (status) {
  @case ('active') { <span>Active</span> }
  @default { <span>Inactive</span> }
}
```

Note: `@for` requires `track` — no separate `trackBy` function needed for simple IDs.

### Add @defer for heavy components

```html
<!-- Load HeavyChartComponent only when it enters the viewport -->
@defer (on viewport) {
  <app-heavy-chart [data]="chartData" />
} @loading {
  <mat-spinner />
} @error {
  <p>Failed to load chart.</p>
}

<!-- Load on user interaction -->
@defer (on interaction) {
  <app-comments [postId]="post.id" />
}

<!-- Preload after 2 seconds -->
@defer (on timer(2000)) {
  <app-recommendations />
}
```

### Migrate Universal → @angular/ssr

```bash
ng add @angular/ssr
```

Then remove `@nguniversal/express-engine`:
```bash
npm uninstall @nguniversal/express-engine
```

Update `server.ts` — the new version is simpler and generated automatically.

---

## 5. ng17 → ng18

### Key changes
- `provideExperimentalZonelessChangeDetection()` — zone-less is closer to stable
- Signal forms (experimental) — `signalInput()` for typed signal inputs
- `afterRenderEffect()` — new lifecycle hook
- Resource API (experimental) — declarative async data loading

### Zoneless migration (opt-in only — don't rush this)

Only migrate if you're starting fresh or have a signal-first codebase:
```bash
# ng18 setup
npm uninstall zone.js

# main.ts
bootstrapApplication(AppComponent, {
  providers: [
    provideExperimentalZonelessChangeDetection(),
  ]
});
```

Checklist before going zoneless — see `references/signals-patterns.md` §Zone-less checklist.

---

## 6. NgModule → Standalone Migration

Run the official schematic first — it handles ~80% of the work:

```bash
# Migrate all components, directives, pipes to standalone
ng generate @angular/core:standalone

# Choose migration mode when prompted:
# 1 — Convert declarations to standalone (do this first)
# 2 — Remove unnecessary NgModule classes
# 3 — Bootstrap with standalone API
```

Run the three modes sequentially, committing between each. Do NOT run all three at once.

**Manual cleanup after schematic:**

```typescript
// Remove SharedModule imports — standalone components import directly
// Before
@NgModule({
  imports: [SharedModule],
  declarations: [UserCardComponent],
})

// After
@Component({
  standalone: true,
  imports: [CommonModule, MatButtonModule, MatIconModule, UserAvatarComponent],
})
export class UserCardComponent {}
```

**Common post-migration fixes:**
- `CommonModule` must be imported where `*ngIf`/`*ngFor` are used (or migrate to `@if`/`@for`)
- `ReactiveFormsModule` must be imported in each form component
- Providers that were in `SharedModule` must move to `app.config.ts` or route-level providers
- `RouterModule` → import `RouterLink`, `RouterOutlet` individually

---

## 7. RxJS/BehaviorSubject → Signals Migration

Migrate incrementally — signals and BehaviorSubject coexist. Don't rewrite everything at once.

**Migrate one service at a time:**

```typescript
// Before — BehaviorSubject
@Injectable()
export class UserService {
  private usersSubject = new BehaviorSubject<User[]>([]);
  readonly users$ = this.usersSubject.asObservable();
  readonly count$ = this.users$.pipe(map(u => u.length));

  setUsers(users: User[]): void {
    this.usersSubject.next(users);
  }
}

// After — Signals
@Injectable()
export class UserService {
  private _users = signal<User[]>([]);
  readonly users = this._users.asReadonly();
  readonly count = computed(() => this._users().length);

  setUsers(users: User[]): void {
    this._users.set(users);
  }
}
```

**Bridge for consumers not yet migrated:**

```typescript
// Consumers using the Observable API can bridge with toObservable()
readonly users$ = toObservable(this.users);
```

**Template migration:**

```html
<!-- Before -->
<app-user-card
  *ngFor="let user of users$ | async; trackBy: trackById"
  [user]="user">
</app-user-card>

<!-- After -->
@for (user of users(); track user.id) {
  <app-user-card [user]="user" />
}
```

---

## 8. Common Breaking Change Patterns

| Change | Versions | Fix |
|---|---|---|
| `HttpClientModule` deprecated | ng15+ | Use `provideHttpClient()` in `app.config.ts` |
| `BrowserModule` not needed in standalone | ng15+ | Remove from imports |
| `CanLoad` deprecated | ng15+ | Replace with `canMatch` |
| `@NgModule` `entryComponents` removed | ng14 | Remove — Ivy renders dynamically without it |
| `ComponentFactoryResolver` removed | ng14 | Use `ViewContainerRef.createComponent()` |
| `APP_INITIALIZER` token changes | ng16 | Use `provideAppInitializer()` (ng18+) |
| `RouterTestingModule` deprecated | ng16+ | Use `provideRouter()` in test providers |
| `ngcc` removed | ng16 | Packages must be Ivy-compatible |
| `ReflectiveInjector` removed | ng14 | Use `Injector.create()` |
| `Renderer2` direct DOM methods | all | Use for SSR-safe DOM access |

**When a peer dependency blocks the upgrade:**
```bash
# Force upgrade with legacy peer deps (last resort — check for actual incompatibilities first)
npm install --legacy-peer-deps

# Or use overrides in package.json
{
  "overrides": {
    "some-old-lib": { "@angular/core": "^17.0.0" }
  }
}
```
