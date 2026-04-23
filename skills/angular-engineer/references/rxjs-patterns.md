# RxJS Patterns

## Unsubscribe Strategies

### takeUntil (preferred for class-based components)
```typescript
@Component({ ... })
export class MyComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();

  ngOnInit(): void {
    this.userService.users$
      .pipe(takeUntil(this.destroy$))
      .subscribe(users => this.users = users);

    this.router.events
      .pipe(
        filter(e => e instanceof NavigationEnd),
        takeUntil(this.destroy$)
      )
      .subscribe(() => this.onRouteChange());
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

### async pipe (preferred when possible — zero manual unsubscribe)
```typescript
// Component (ng17+ control flow syntax)
@Component({
  template: `
    @for (user of users$ | async; track user.id) {
      <div>{{ user.name }}</div>
    }
    @if (loading$ | async) {
      <p>Loading...</p>
    }
    <!-- ng14–16: *ngFor="let user of users$ | async; trackBy: trackById" -->
    <!-- ng14–16: *ngIf="loading$ | async"                                -->
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UsersComponent {
  users$ = this.userService.users$;
  loading$ = this.userService.loading$;
  constructor(private userService: UserService) {}
}
```

---

## Combining Streams

### combineLatest — emit when ANY source emits (all must have emitted at least once)
Use when you need the latest value from multiple sources simultaneously:
```typescript
// Dashboard that needs both user and permissions
vm$ = combineLatest({
  user: this.authService.currentUser$,
  permissions: this.permissionService.permissions$,
  settings: this.settingsService.settings$,
}).pipe(
  map(({ user, permissions, settings }) => ({
    canEdit: permissions.includes('edit'),
    displayName: user.firstName,
    theme: settings.theme,
  }))
);
```

### switchMap — cancel previous, start new (navigation, search, route params)
```typescript
// Route param changes → fetch new data, cancel previous request
this.route.paramMap.pipe(
  switchMap(params => {
    const id = params.get('id')!;
    return this.productService.getById(id);
  }),
  takeUntil(this.destroy$)
).subscribe(product => this.product = product);
```

### concatMap — queue, run in order (form saves, sequential uploads)
```typescript
// Each save must complete before the next begins
this.saveClicks$.pipe(
  concatMap(formValue => this.apiService.save(formValue)),
  takeUntil(this.destroy$)
).subscribe();
```

### mergeMap — run all in parallel (independent requests, order doesn't matter)
```typescript
// Delete multiple items concurrently
from(selectedIds).pipe(
  mergeMap(id => this.apiService.delete(id)),
  toArray(),
  takeUntil(this.destroy$)
).subscribe(() => this.refresh());
```

### forkJoin — wait for all to complete (page init, load multiple resources)
```typescript
// Load everything needed for a page at once
ngOnInit(): void {
  forkJoin({
    user: this.userService.getUser(this.id),
    roles: this.roleService.getRoles(),
    departments: this.deptService.getDepartments(),
  }).pipe(takeUntil(this.destroy$))
    .subscribe(({ user, roles, departments }) => {
      this.user = user;
      this.roles = roles;
      this.departments = departments;
    });
}
```

---

## Error Handling

### catchError — recover with fallback value or rethrow
```typescript
// Service: return empty array on error, log the problem
getUsers(): Observable<User[]> {
  return this.http.get<User[]>('/api/users').pipe(
    catchError(err => {
      this.errorService.log(err);
      return of([]);              // recover with empty array
    })
  );
}

// Service: rethrow a user-friendly error
saveUser(user: User): Observable<User> {
  return this.http.post<User>('/api/users', user).pipe(
    catchError(err => {
      const message = err.status === 409
        ? 'A user with this email already exists.'
        : 'Failed to save. Please try again.';
      return throwError(() => new Error(message));
    })
  );
}
```

### retry with backoff (transient network errors)
```typescript
import { retry, timer } from 'rxjs';

getWithRetry<T>(url: string): Observable<T> {
  return this.http.get<T>(url).pipe(
    retry({
      count: 3,
      delay: (error, retryIndex) => timer(retryIndex * 1000), // 1s, 2s, 3s
    })
  );
}
```

---

## shareReplay & Loading + Error State

→ See `references/http-layer.md` §5 (loading/error state) and §6 (shareReplay caching)
for the full patterns — keeping them in one place avoids drift between duplicates.

---

## Debounce / Throttle (search inputs, resize events)
```typescript
// Search input — wait 300ms after user stops typing
@Component({ ... })
export class SearchComponent implements OnInit {
  searchControl = new FormControl('');

  results$ = this.searchControl.valueChanges.pipe(
    debounceTime(300),
    distinctUntilChanged(),
    filter(term => term !== null && term.length >= 2),
    switchMap(term => this.searchService.search(term)),
    shareReplay(1),
  );
}

---

## Subject Variants — When to Use Each

| Variant | Holds current value | Late subscribers | Typical use |
|---|---|---|---|
| `Subject` | No | Miss all past emissions | Events, fire-and-forget |
| `BehaviorSubject(init)` | Yes (1 value) | Get current value immediately | UI state, selected item |
| `ReplaySubject(n)` | Yes (last n) | Replay last n emissions | Cache recent values |
| `AsyncSubject` | Last only | Get last value after `complete()` | Rarely needed |

```typescript
// Subject — late subscriber gets nothing from before subscribe
const click$ = new Subject<MouseEvent>();
click$.next(event);                          // missed by any subscriber added later

// BehaviorSubject — late subscriber always gets the current value
const currentUser$ = new BehaviorSubject<User | null>(null);
currentUser$.next(loggedInUser);
currentUser$.subscribe(u => console.log(u)); // immediately logs loggedInUser

// ReplaySubject — late subscriber gets last 3 values
const recentSearches$ = new ReplaySubject<string>(3);
recentSearches$.next('angular');
recentSearches$.next('rxjs');
recentSearches$.next('signals');
recentSearches$.subscribe(s => console.log(s)); // logs all three immediately

// AsyncSubject — emits only after complete(), only the last value
const result$ = new AsyncSubject<number>();
result$.next(1);
result$.next(2);
result$.complete();                          // subscriber now receives 2
```

---

## `takeUntilDestroyed()` (ng16+)

`takeUntilDestroyed()` from `@angular/core/rxjs-interop` replaces the manual
`destroy$ + takeUntil` pattern. In components it captures the destroy context
automatically; in services pass an explicit `DestroyRef`.

```typescript
// src/app/features/users/users.component.ts  — no args: uses component's DestroyRef
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

@Component({ ... })
export class UsersComponent {
  constructor(private userService: UserService) {
    this.userService.users$
      .pipe(takeUntilDestroyed())           // no manual ngOnDestroy needed
      .subscribe(users => this.users = users);
  }
}
```

```typescript
// src/app/core/polling.service.ts  — inject DestroyRef explicitly (service context)
import { DestroyRef, inject, Injectable } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

@Injectable()
export class PollingService {
  private destroyRef = inject(DestroyRef);

  startPolling(): void {
    interval(5000)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(() => this.refresh());
  }
}
```

For ng14–15 projects, continue using the `takeUntil(destroy$)` pattern from section 1.

---

## `withLatestFrom`

Use `withLatestFrom` when a trigger observable should sample the latest value of a
state observable without subscribing to the state as a trigger itself.
`combineLatest` re-emits whenever either source emits; `withLatestFrom` emits only
when the trigger emits.

```typescript
// Button click samples current user state — user$ changes do NOT trigger emission
@Component({ ... })
export class ProfileComponent {
  private saveClick$ = new Subject<void>();

  constructor(
    private authService: AuthService,
    private profileService: ProfileService,
  ) {
    this.saveClick$.pipe(
      withLatestFrom(this.authService.currentUser$),  // state, not a trigger
      switchMap(([_, user]) => this.profileService.save(user)),
      takeUntilDestroyed(),
    ).subscribe();
  }

  onSave(): void { this.saveClick$.next(); }
}
```

Use `combineLatest` when you need to react to changes in any of the combined streams
(e.g. a view-model built from multiple state slices). Use `withLatestFrom` when only
one stream drives the emission and the rest are read-only snapshots.
```
