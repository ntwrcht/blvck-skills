# State Management Patterns

## Decision Matrix — What to Use When

This is the most important section. Pick the right tool before writing any state code.

| Scenario | Recommended | Why |
|---|---|---|
| Component-local UI state (loading, open, selected) | `signal()` | Scoped, no boilerplate, template-reactive |
| Derived/computed values from other state | `computed()` | Memoized, auto-tracks dependencies |
| Feature-scoped shared state (ng17+ standalone) | Signal Service | Simple, no library needed |
| Feature-scoped shared state (ng14–16 NgModule) | `BehaviorSubject` Service | Proven, RxJS-compatible |
| Cross-feature shared state (simple) | Signal Service at root | `providedIn: 'root'` |
| Cross-feature shared state (complex, with side effects) | NgRx + Effects | Explicit actions, devtools, time-travel debug |
| Complex async pipelines (debounce, retry, race) | RxJS Observable | Operators are unmatched for async composition |
| Server state (cache, refetch, optimistic) | RxJS + `shareReplay(1)` or NgRx | Avoid re-fetching on every subscription |
| Two-way binding across component boundary | `model()` | Cleaner than `@Input` + `@Output` pair |
| Form state | `ReactiveFormsModule` | Never manage form state manually |

**Rule of thumb:**
- `signal()` — state that changes synchronously in response to user actions
- RxJS — state that arrives asynchronously or needs operator composition
- NgRx — when you need audit trail, time-travel debug, or >3 features sharing state

---

## 1. Signal Service (Feature-Scoped State)

Best for: ng17+ projects, feature-level state, no cross-feature sharing needed.

```typescript
// src/app/features/users/services/user-state.service.ts
@Injectable()   // Provided in feature module/routes — NOT root
export class UserStateService {
  private _users = signal<User[]>([]);
  private _loading = signal(false);
  private _error = signal<string | null>(null);
  private _selectedId = signal<number | null>(null);

  // Public read-only surface
  readonly users = this._users.asReadonly();
  readonly loading = this._loading.asReadonly();
  readonly error = this._error.asReadonly();

  // Derived state — computed automatically
  readonly selectedUser = computed(() =>
    this._users().find(u => u.id === this._selectedId()) ?? null
  );
  readonly activeCount = computed(() =>
    this._users().filter(u => u.status === 'active').length
  );

  constructor(private api: ApiService) {}

  load(): void {
    this._loading.set(true);
    this._error.set(null);

    this.api.get<User[]>('/users').subscribe({
      next: users => {
        this._users.set(users);
        this._loading.set(false);
      },
      error: () => {
        this._error.set('Failed to load users. Please try again.');
        this._loading.set(false);
      },
    });
  }

  select(id: number): void {
    this._selectedId.set(id);
  }

  add(user: User): Observable<User> {
    return this.api.post<User>('/users', user).pipe(
      tap(created => this._users.update(list => [...list, created]))
    );
  }

  update(id: number, patch: Partial<User>): Observable<User> {
    return this.api.patch<User>(`/users/${id}`, patch).pipe(
      tap(updated =>
        this._users.update(list => list.map(u => u.id === id ? updated : u))
      )
    );
  }

  remove(id: number): Observable<void> {
    return this.api.delete<void>(`/users/${id}`).pipe(
      tap(() => this._users.update(list => list.filter(u => u.id !== id)))
    );
  }
}
```

Provide at feature route level (standalone):
```typescript
// users.routes.ts
export const USERS_ROUTES: Routes = [{
  path: '',
  providers: [UserStateService],   // scoped to this route tree
  children: [ ... ]
}];
```

---

## 2. BehaviorSubject Service (ng14–16 Compatible)

Best for: NgModule projects, teams already familiar with RxJS.

```typescript
// src/app/features/users/services/user-state.service.ts
@Injectable()
export class UserStateService {
  private usersSubject = new BehaviorSubject<User[]>([]);
  private loadingSubject = new BehaviorSubject(false);
  private errorSubject = new BehaviorSubject<string | null>(null);

  // Public observables
  readonly users$ = this.usersSubject.asObservable();
  readonly loading$ = this.loadingSubject.asObservable();
  readonly error$ = this.errorSubject.asObservable();

  // Derived
  readonly activeUsers$ = this.users$.pipe(
    map(users => users.filter(u => u.status === 'active'))
  );

  constructor(private api: ApiService) {}

  load(): void {
    this.loadingSubject.next(true);
    this.errorSubject.next(null);

    this.api.get<User[]>('/users').pipe(
      catchError(err => {
        this.errorSubject.next('Failed to load users.');
        return EMPTY;
      }),
      finalize(() => this.loadingSubject.next(false))
    ).subscribe(users => this.usersSubject.next(users));
  }

  add(user: User): Observable<User> {
    return this.api.post<User>('/users', user).pipe(
      tap(created => this.usersSubject.next([...this.usersSubject.value, created]))
    );
  }
}
```

---

## 3. NgRx (Cross-Feature / Complex State)

Use when: multiple features share state, you need devtools/time-travel debug, or side effects are complex.

### When NOT to use NgRx
- Feature state used only within one lazy-loaded module — use Signal Service instead
- Simple CRUD with no complex side effects — over-engineering
- Team unfamiliar with Redux pattern — adds cognitive overhead

### Minimal NgRx setup (NgRx 17+ with `createFeature`)

```typescript
// src/app/features/users/store/user.store.ts
import { createFeature, createReducer, createActionGroup, emptyProps, props, on } from '@ngrx/store';

// Actions
export const UserActions = createActionGroup({
  source: 'Users',
  events: {
    'Load Users': emptyProps(),
    'Load Users Success': props<{ users: User[] }>(),
    'Load Users Failure': props<{ error: string }>(),
    'Delete User': props<{ id: number }>(),
    'Delete User Success': props<{ id: number }>(),
  },
});

// State + Reducer
export const usersFeature = createFeature({
  name: 'users',
  reducer: createReducer(
    { users: [] as User[], loading: false, error: null as string | null },
    on(UserActions.loadUsers, state => ({ ...state, loading: true, error: null })),
    on(UserActions.loadUsersSuccess, (state, { users }) => ({ ...state, users, loading: false })),
    on(UserActions.loadUsersFailure, (state, { error }) => ({ ...state, error, loading: false })),
    on(UserActions.deleteUserSuccess, (state, { id }) => ({
      ...state,
      users: state.users.filter(u => u.id !== id),
    })),
  ),
});

// Selectors auto-generated by createFeature:
// usersFeature.selectUsers, usersFeature.selectLoading, usersFeature.selectError
```

```typescript
// src/app/features/users/store/user.effects.ts
@Injectable()
export class UserEffects {
  loadUsers$ = createEffect(() =>
    this.actions$.pipe(
      ofType(UserActions.loadUsers),
      switchMap(() =>
        this.api.get<User[]>('/users').pipe(
          map(users => UserActions.loadUsersSuccess({ users })),
          catchError(err => of(UserActions.loadUsersFailure({ error: err.message })))
        )
      )
    )
  );

  constructor(private actions$: Actions, private api: ApiService) {}
}
```

---

## 4. Signals vs BehaviorSubject — Quick Reference

```typescript
// ✅ Signal — synchronous, simpler
count = signal(0);
doubled = computed(() => this.count() * 2);
this.count.set(5);         // set
this.count.update(n => n + 1);  // update based on previous

// ✅ BehaviorSubject — async-friendly, RxJS-composable
count$ = new BehaviorSubject(0);
doubled$ = this.count$.pipe(map(n => n * 2));
this.count$.next(5);
this.count$.next(this.count$.value + 1);

// Bridge: use toSignal() when consuming Observable in template (ng17+)
countSignal = toSignal(this.count$, { initialValue: 0 });
```

---

## 5. Anti-Patterns to Avoid

- ❌ `effect()` to sync one signal into another — use `computed()` instead
- ❌ `BehaviorSubject` exposed directly (not `.asObservable()`) — allows external mutation
- ❌ Storing server responses in NgRx when only one component needs them — use `toSignal()` + HTTP directly
- ❌ Calling `.value` on BehaviorSubject inside a template — subscribe with `async` pipe instead
- ❌ Mixing signal state and BehaviorSubject state in the same service — pick one pattern per service
