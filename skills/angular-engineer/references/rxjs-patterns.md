# RxJS Patterns for Angular 14

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
// Component
@Component({
  template: `
    <div *ngFor="let user of users$ | async; trackBy: trackById">
      {{ user.name }}
    </div>
    <p *ngIf="loading$ | async">Loading...</p>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UsersComponent {
  users$ = this.userService.users$;
  loading$ = this.userService.loading$;
  constructor(private userService: UserService) {}
  trackById = (_: number, u: User) => u.id;
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

## shareReplay — share a single HTTP request among multiple subscribers
```typescript
// Without shareReplay: each subscriber triggers a new HTTP request
// With shareReplay(1): one request, result cached and replayed to all

@Injectable()
export class ConfigService {
  // Loaded once, shared across all components that need it
  readonly config$ = this.http.get<AppConfig>('/api/config').pipe(
    shareReplay(1)
  );

  constructor(private http: HttpClient) {}
}
```

---

## Loading + Error State Pattern
```typescript
interface AsyncState<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
}

@Injectable()
export class UserService {
  private state = new BehaviorSubject<AsyncState<User[]>>({
    data: null, loading: false, error: null
  });

  readonly state$ = this.state.asObservable();
  readonly users$ = this.state$.pipe(map(s => s.data));
  readonly loading$ = this.state$.pipe(map(s => s.loading));
  readonly error$ = this.state$.pipe(map(s => s.error));

  loadUsers(): void {
    this.state.next({ data: null, loading: true, error: null });

    this.http.get<User[]>('/api/users').subscribe({
      next: data => this.state.next({ data, loading: false, error: null }),
      error: err => this.state.next({ data: null, loading: false, error: err.message }),
    });
  }
}
```

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
```
