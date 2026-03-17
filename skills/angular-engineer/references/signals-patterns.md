# Signals Patterns (Angular 17+)

Signals are Angular 17+'s reactive primitive. They replace BehaviorSubject for synchronous state
and integrate tightly with OnPush change detection — a signal read inside a template automatically
marks the component for update when the signal changes.

---

## Core API

```typescript
import { signal, computed, effect, input, output, model } from '@angular/core';
import { toSignal, toObservable } from '@angular/core/rxjs-interop';
```

| API             | Purpose                                                               |
|-----------------|-----------------------------------------------------------------------|
| `signal(v)`     | Writable reactive value                                               |
| `computed(fn)`  | Derived read-only value — memoized, re-runs only when deps change     |
| `effect(fn)`    | Side effect that re-runs when any signal it reads changes             |
| `input()`       | Signal-based `@Input()` — read-only inside the component              |
| `output()`      | Signal-based `@Output()` — replaces `EventEmitter`                   |
| `model()`       | Two-way binding signal (`[(value)]`)                                  |
| `toSignal(obs)` | Wraps an Observable as a signal — handles subscription automatically  |
| `toObservable(sig)` | Converts a signal back to an Observable                           |

---

## Signal-Based Component State

```typescript
// src/app/features/users/pages/users-page.component.ts
@Component({
  selector: 'app-users-page',
  standalone: true,
  imports: [UserCardComponent, AsyncPipe],
  templateUrl: './users-page.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UsersPageComponent {
  private userService = inject(UserService);

  // Writable state
  searchTerm = signal('');
  isLoading = signal(false);

  // Derived — recomputes only when searchTerm changes
  filteredUsers = computed(() =>
    this.userService.users().filter(u =>
      u.name.toLowerCase().includes(this.searchTerm().toLowerCase())
    )
  );

  onSearch(term: string): void {
    this.searchTerm.set(term);
  }

  onDelete(id: number): void {
    this.isLoading.set(true);
    this.userService.delete(id).subscribe({
      complete: () => this.isLoading.set(false),
      error: () => this.isLoading.set(false),
    });
  }
}
```

```html
<!-- Loading and list driven by signals — no async pipe needed -->
@if (isLoading()) {
  <mat-progress-bar mode="indeterminate" />
}
@for (user of filteredUsers(); track user.id) {
  <app-user-card [user]="user" (delete)="onDelete($event)" />
}
@if (filteredUsers().length === 0) {
  <app-empty-state message="No users found" />
}
```

---

## Signal-Based Inputs and Outputs

```typescript
// src/app/features/users/components/user-card/user-card.component.ts
@Component({
  selector: 'app-user-card',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UserCardComponent {
  // Signal inputs — read-only inside the component
  user = input.required<User>();
  isSelected = input(false);  // optional with default

  // Signal output — replaces EventEmitter
  delete = output<number>();
  edit = output<User>();

  // Derived from input — recomputes when user() changes
  displayName = computed(() => `${this.user().firstName} ${this.user().lastName}`);

  onDelete(): void {
    this.delete.emit(this.user().id);
  }
}
```

```html
<!-- Template reads signal inputs with () -->
<mat-card [class.selected]="isSelected()">
  <mat-card-title>{{ displayName() }}</mat-card-title>
  <mat-card-subtitle>{{ user().email }}</mat-card-subtitle>
  <button mat-icon-button (click)="onDelete()">
    <mat-icon>delete</mat-icon>
  </button>
</mat-card>
```

---

## Signal-Based Service State

Replaces BehaviorSubject for synchronous state. Use when the state is local to a feature and
you don't need to pipe it through RxJS operators.

```typescript
// src/app/features/users/services/user.service.ts
@Injectable()
export class UserService {
  private http = inject(ApiService);

  // Private writable — public read-only surface
  private _users = signal<User[]>([]);
  private _loading = signal(false);
  private _error = signal<string | null>(null);

  // Public read-only signals
  readonly users = this._users.asReadonly();
  readonly loading = this._loading.asReadonly();
  readonly error = this._error.asReadonly();

  // Derived
  readonly activeUsers = computed(() =>
    this._users().filter(u => u.status === 'active')
  );
  readonly count = computed(() => this._users().length);

  loadUsers(): void {
    this._loading.set(true);
    this._error.set(null);
    this.http.get<User[]>('/users').subscribe({
      next: users => {
        this._users.set(users);
        this._loading.set(false);
      },
      error: err => {
        this._error.set('Failed to load users');
        this._loading.set(false);
      },
    });
  }

  add(user: User): Observable<User> {
    return this.http.post<User>('/users', user).pipe(
      tap(created => this._users.update(list => [...list, created]))
    );
  }

  remove(id: number): void {
    this._users.update(list => list.filter(u => u.id !== id));
  }
}
```

---

## Bridging Signals and RxJS

Use `toSignal` when you have an Observable but want to read it in a template or `computed()`.
Use `toObservable` when you need a signal value inside an RxJS pipeline.

```typescript
@Component({ standalone: true, changeDetection: ChangeDetectionStrategy.OnPush })
export class ProductListComponent {
  private route = inject(ActivatedRoute);
  private productService = inject(ProductService);

  // Observable → Signal: handles subscribe/unsubscribe automatically
  // initialValue required for synchronous reads
  routeId = toSignal(this.route.paramMap.pipe(map(p => p.get('id'))), {
    initialValue: null,
  });

  // Chain: signal → observable → signal (async data)
  product = toSignal(
    toObservable(this.routeId).pipe(
      filter(Boolean),
      switchMap(id => this.productService.get(id))
    ),
    { initialValue: null }
  );
}
```

```html
@if (product(); as p) {
  <h1>{{ p.name }}</h1>
} @else {
  <mat-spinner />
}
```

---

## effect() — When and How

`effect()` is for side effects only (logging, syncing to localStorage, analytics). Never use it
to derive state — use `computed()` for that.

```typescript
export class ThemeService {
  theme = signal<'light' | 'dark'>('light');

  constructor() {
    // Runs once on init, re-runs whenever theme() changes
    effect(() => {
      document.body.setAttribute('data-theme', this.theme());
    });
  }

  toggle(): void {
    this.theme.update(t => t === 'light' ? 'dark' : 'light');
  }
}
```

**effect() rules:**
- Must be called in an injection context (constructor, field initializer, or with `injector` option)
- Never write to a signal inside `effect()` without `allowSignalWrites: true` — it creates cycles
- Prefer `computed()` for derived state — `effect()` is for DOM/external system side effects only

---

## Two-Way Binding with model()

```typescript
// Reusable input component
@Component({ selector: 'app-search-input', standalone: true })
export class SearchInputComponent {
  value = model('');  // two-way bindable signal

  onInput(event: Event): void {
    this.value.set((event.target as HTMLInputElement).value);
  }
}
```

```html
<!-- Parent uses [(value)] two-way binding -->
<app-search-input [(value)]="searchTerm" />
```

---

## Signals vs BehaviorSubject — When to Use Which

| Scenario | Use |
|---|---|
| Component-local UI state (loading, selected, open) | `signal()` |
| Derived/computed values | `computed()` |
| Feature service state (ng17+ standalone project) | `signal()` |
| Feature service state (ng14–15 NgModule project) | `BehaviorSubject` |
| Cross-component event stream | `Subject` / `EventEmitter` |
| HTTP result consumed by multiple components | `toSignal()` + `shareReplay(1)` |
| Complex async pipelines (debounce, retry, switchMap) | RxJS Observable |
| Needs operators (combineLatest, withLatestFrom) | RxJS → `toSignal()` at the end |

**Rule of thumb:** Signals for state, RxJS for async pipelines, bridge with `toSignal`/`toObservable`.

---
 
## Zone-less Applications (ng17+)
 
Angular's default change detection relies on Zone.js to patch async APIs and trigger CD.
Zone-less removes this dependency — change detection runs only when signals change.
 
### When to go Zone-less
- New ng17+ standalone project with signal-first architecture
- Performance-critical apps where Zone.js overhead is measurable
- Do NOT migrate existing NgModule projects — high risk, low reward
 
### Setup
 
```typescript
// src/main.ts
import { bootstrapApplication } from '@angular/platform-browser';
import { provideExperimentalZonelessChangeDetection } from '@angular/core';
 
bootstrapApplication(AppComponent, {
  providers: [
    provideExperimentalZonelessChangeDetection(),   // replaces zone.js
    // ... other providers
  ],
});
```
 
Remove `zone.js` from `angular.json` polyfills:
```json
// Before
"polyfills": ["zone.js"]
 
// After (zone-less)
"polyfills": []
```
 
Remove from `package.json`:
```bash
npm uninstall zone.js
```
 
### Rules for Zone-less components
 
```typescript
// ✅ Zone-less compatible — all state via signals
@Component({
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,  // required
})
export class UserCardComponent {
  user = input.required<User>();
  isSelected = input(false);
  delete = output<number>();
 
  displayName = computed(() => `${this.user().firstName} ${this.user().lastName}`);
}
```
 
```typescript
// ❌ Zone-less INCOMPATIBLE — setTimeout won't trigger CD
export class BadComponent {
  count = 0;  // plain property, not a signal
 
  increment() {
    setTimeout(() => {
      this.count++;  // CD won't run — Zone.js no longer intercepts setTimeout
    }, 1000);
  }
}
 
// ✅ Fix — use signal
export class GoodComponent {
  count = signal(0);
 
  increment() {
    setTimeout(() => {
      this.count.update(n => n + 1);  // signal change triggers CD
    }, 1000);
  }
}
```
 
### Zone-less checklist before shipping
- [ ] All component state uses `signal()` / `computed()`
- [ ] No plain class properties updated asynchronously
- [ ] All `setTimeout` / `setInterval` / Promise results write to signals
- [ ] HTTP results piped through `toSignal()` or written to signals in subscribe
- [ ] `ChangeDetectionStrategy.OnPush` on every component
- [ ] Third-party libraries tested — some rely on Zone.js internally

---

## Testing Signal Components

```typescript
describe('UsersPageComponent', () => {
  let component: UsersPageComponent;
  let fixture: ComponentFixture<UsersPageComponent>;
  let userServiceSpy: jasmine.SpyObj<UserService>;

  beforeEach(async () => {
    userServiceSpy = jasmine.createSpyObj('UserService', ['loadUsers', 'delete'], {
      users: signal<User[]>([{ id: 1, name: 'Alice', status: 'active' }]),
      loading: signal(false),
    });

    await TestBed.configureTestingModule({
      imports: [UsersPageComponent],
      providers: [{ provide: UserService, useValue: userServiceSpy }],
    }).compileComponents();

    fixture = TestBed.createComponent(UsersPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should filter users by search term', () => {
    component.searchTerm.set('ali');
    fixture.detectChanges();
    const cards = fixture.debugElement.queryAll(By.css('app-user-card'));
    expect(cards.length).toBe(1);
  });
});
```

**Signal testing rules:**
- Spy object's signal properties use `jasmine.createSpyObj` with the third argument (property map)
- Set signal values directly: `component.mySignal.set(value)` — no `fixture.debugElement` needed for state
- `fixture.detectChanges()` still required to push signal changes into the template
