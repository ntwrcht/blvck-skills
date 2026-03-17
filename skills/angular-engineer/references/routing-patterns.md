# Routing Patterns

## Table of Contents
1. App Router Setup (NgModule vs Standalone)
2. Lazy Loading Feature Modules
3. Route Guards (CanActivate, CanLoad, CanDeactivate)
4. Resolvers — Pre-fetch Data Before Route Activates
5. Route Parameters & Query Params
6. Child Routes & Named Outlets
7. Wildcard & Redirect Routes
8. Scroll Restoration & Navigation Extras
9. Testing Routes

---

## 1. App Router Setup

### NgModule style (ng14–15)

```typescript
// src/app/app-routing.module.ts
const routes: Routes = [
  { path: '', redirectTo: '/dashboard', pathMatch: 'full' },
  { path: 'login', component: LoginPageComponent },
  {
    path: 'dashboard',
    loadChildren: () => import('./features/dashboard/dashboard.module').then(m => m.DashboardModule),
    canActivate: [AuthGuard],
    canLoad: [AuthLoadGuard],
  },
  { path: '**', component: NotFoundPageComponent },
];

@NgModule({
  imports: [RouterModule.forRoot(routes, {
    scrollPositionRestoration: 'enabled',
    anchorScrolling: 'enabled',
  })],
  exports: [RouterModule],
})
export class AppRoutingModule {}
```

### Standalone style (ng16+)

```typescript
// src/app/app.routes.ts
export const APP_ROUTES: Routes = [
  { path: '', redirectTo: '/dashboard', pathMatch: 'full' },
  { path: 'login', component: LoginPageComponent },
  {
    path: 'dashboard',
    loadChildren: () => import('./features/dashboard/dashboard.routes').then(r => r.DASHBOARD_ROUTES),
    canActivate: [authGuard],    // functional guard — no class needed
  },
  { path: '**', component: NotFoundPageComponent },
];

// src/main.ts
bootstrapApplication(AppComponent, {
  providers: [
    provideRouter(APP_ROUTES, withScrollPositionRestoration('enabled')),
  ],
});
```

---

## 2. Lazy Loading Feature Modules

Every feature route must be lazy-loaded — never eagerly imported in AppModule.

### NgModule feature routing

```typescript
// src/app/features/users/users-routing.module.ts
const routes: Routes = [
  {
    path: '',
    component: UsersShellComponent,   // layout shell, not a page
    children: [
      { path: '', component: UsersListPageComponent },
      { path: ':id', component: UserDetailPageComponent, resolve: { user: UserResolver } },
      { path: ':id/edit', component: UserEditPageComponent, canDeactivate: [UnsavedChangesGuard] },
    ],
  },
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule],
})
export class UsersRoutingModule {}
```

### Standalone feature routes

```typescript
// src/app/features/users/users.routes.ts
export const USERS_ROUTES: Routes = [
  {
    path: '',
    component: UsersShellComponent,
    children: [
      { path: '', component: UsersListPageComponent },
      {
        path: ':id',
        component: UserDetailPageComponent,
        resolve: { user: userResolver },   // functional resolver
      },
      {
        path: ':id/edit',
        component: UserEditPageComponent,
        canDeactivate: [unsavedChangesGuard],
      },
    ],
  },
];
```

**Rule:** Always use a shell component as the parent — it holds `<router-outlet>` and shared layout (breadcrumbs, sidebar) for the feature. Pages are children.

---

## 3. Route Guards

### CanActivate (class-based, ng14–15)

```typescript
// src/app/core/guards/auth.guard.ts
@Injectable({ providedIn: 'root' })
export class AuthGuard implements CanActivate {
  constructor(private authService: AuthService, private router: Router) {}

  canActivate(route: ActivatedRouteSnapshot, state: RouterStateSnapshot): Observable<boolean | UrlTree> {
    return this.authService.isAuthenticated$.pipe(
      take(1),
      map(isAuth =>
        isAuth
          ? true
          : this.router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } })
      )
    );
  }
}
```

### Functional guard (ng15+, preferred for standalone)

```typescript
// src/app/core/guards/auth.guard.ts
export const authGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  return authService.isAuthenticated$.pipe(
    take(1),
    map(isAuth =>
      isAuth
        ? true
        : router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } })
    )
  );
};
```

### CanDeactivate — unsaved changes warning

```typescript
// src/app/core/guards/unsaved-changes.guard.ts
export interface HasUnsavedChanges {
  hasUnsavedChanges(): boolean;
}

// Class-based
@Injectable({ providedIn: 'root' })
export class UnsavedChangesGuard implements CanDeactivate<HasUnsavedChanges> {
  canDeactivate(component: HasUnsavedChanges): boolean {
    if (component.hasUnsavedChanges()) {
      return confirm('You have unsaved changes. Leave anyway?');
    }
    return true;
  }
}

// Functional (ng15+)
export const unsavedChangesGuard: CanDeactivateFn<HasUnsavedChanges> = (component) => {
  if (component.hasUnsavedChanges()) {
    return confirm('You have unsaved changes. Leave anyway?');
  }
  return true;
};
```

Implement in the page component:
```typescript
export class UserEditPageComponent implements HasUnsavedChanges {
  private isDirty = false;

  hasUnsavedChanges(): boolean {
    return this.isDirty;
  }
}
```

### CanLoad — prevent lazy module download (ng14–15 only)

```typescript
@Injectable({ providedIn: 'root' })
export class AuthLoadGuard implements CanLoad {
  constructor(private authService: AuthService, private router: Router) {}

  canLoad(): Observable<boolean | UrlTree> {
    return this.authService.isAuthenticated$.pipe(
      take(1),
      map(isAuth => isAuth || this.router.createUrlTree(['/login']))
    );
  }
}
```

> **Note:** `canLoad` is deprecated in ng15+. Use `canMatch` instead — it works identically but also applies to non-lazy routes.

---

## 4. Resolvers — Pre-fetch Data Before Route Activates

Use resolvers to guarantee data is available when the component initializes.
Avoid loading spinners inside the component itself for initial data.

### Functional resolver (ng15+, preferred)

```typescript
// src/app/features/users/resolvers/user.resolver.ts
export const userResolver: ResolveFn<User> = (route) => {
  const userService = inject(UserService);
  const router = inject(Router);
  const id = Number(route.paramMap.get('id'));

  return userService.getById(id).pipe(
    catchError(() => {
      router.navigate(['/not-found']);
      return EMPTY;   // cancel navigation cleanly
    })
  );
};
```

Consume in the component:

```typescript
@Component({ ... })
export class UserDetailPageComponent implements OnInit {
  user!: User;

  constructor(private route: ActivatedRoute) {}

  ngOnInit(): void {
    // resolved data is synchronous by the time component initializes
    this.user = this.route.snapshot.data['user'];
  }
}
```

### Class-based resolver (ng14–15)

```typescript
@Injectable({ providedIn: 'root' })
export class UserResolver implements Resolve<User> {
  constructor(private userService: UserService, private router: Router) {}

  resolve(route: ActivatedRouteSnapshot): Observable<User> {
    const id = Number(route.paramMap.get('id'));
    return this.userService.getById(id).pipe(
      catchError(() => {
        this.router.navigate(['/not-found']);
        return EMPTY;
      })
    );
  }
}
```

**When to use a resolver vs component-level loading:**
- Resolver: initial page data where a blank state is meaningless (user detail, edit form)
- Component-level: secondary data, search results, paginated lists — user expects to wait

---

## 5. Route Parameters & Query Params

### Read route params (reactive — survives re-navigation to same route)

```typescript
@Component({ ... })
export class UserDetailPageComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();
  user$!: Observable<User>;

  constructor(private route: ActivatedRoute, private userService: UserService) {}

  ngOnInit(): void {
    this.user$ = this.route.paramMap.pipe(
      takeUntil(this.destroy$),
      map(params => Number(params.get('id'))),
      distinctUntilChanged(),
      switchMap(id => this.userService.getById(id))
    );
  }

  ngOnDestroy(): void { this.destroy$.next(); this.destroy$.complete(); }
}
```

### Read query params

```typescript
// Read reactively
this.route.queryParamMap.pipe(
  map(params => params.get('search') ?? ''),
  distinctUntilChanged(),
  debounceTime(300),
  takeUntil(this.destroy$),
).subscribe(search => this.loadResults(search));

// Navigate with query params (preserves others)
this.router.navigate([], {
  relativeTo: this.route,
  queryParams: { page: 2 },
  queryParamsHandling: 'merge',   // 'preserve' to keep all, 'merge' to patch
});
```

---

## 6. Child Routes & Named Outlets

### Child routes (tabs, sub-sections)

```typescript
const routes: Routes = [
  {
    path: 'profile',
    component: ProfileShellComponent,   // has <router-outlet>
    children: [
      { path: '', redirectTo: 'overview', pathMatch: 'full' },
      { path: 'overview', component: ProfileOverviewComponent },
      { path: 'settings', component: ProfileSettingsComponent },
      { path: 'security', component: ProfileSecurityComponent },
    ],
  },
];
```

### Named outlets (sidebars, modals, secondary panels)

```typescript
// Route config
{ path: 'help', component: HelpPanelComponent, outlet: 'sidebar' }

// Activate named outlet
this.router.navigate([{ outlets: { sidebar: ['help'] } }]);

// Deactivate
this.router.navigate([{ outlets: { sidebar: null } }]);
```

Named outlets are useful for independently navigable panels. Use sparingly — they add URL complexity.

---

## 7. Wildcard & Redirect Routes

```typescript
const routes: Routes = [
  // Always place these last — router matches top-to-bottom
  { path: 'old-path', redirectTo: '/new-path', pathMatch: 'full' },  // exact redirect
  { path: 'old-section', redirectTo: '/new-section' },               // prefix redirect (preserves child paths)
  { path: '**', component: NotFoundPageComponent },                  // catch-all — must be last
];
```

**Rule:** `pathMatch: 'full'` on redirect routes for exact paths. Omit (defaults to `prefix`) for section-level redirects.

---

## 8. Scroll Restoration & Navigation Extras

```typescript
// Enable scroll restoration globally (app-routing.module.ts or provideRouter)
RouterModule.forRoot(routes, {
  scrollPositionRestoration: 'enabled',   // restores position on back navigation
  anchorScrolling: 'enabled',             // scrolls to #fragment in URL
})

// provideRouter equivalent (standalone)
provideRouter(routes, withScrollPositionRestoration('enabled'))

// Navigate without adding to browser history (replace current entry)
this.router.navigate(['/dashboard'], { replaceUrl: true });

// Navigate and skip guards (admin use only — use carefully)
this.router.navigate(['/admin'], { skipLocationChange: true });

// Navigate with state (not in URL, survives navigation, lost on refresh)
this.router.navigate(['/confirm'], { state: { orderId: 42 } });

// Read state in destination component
const state = this.router.getCurrentNavigation()?.extras.state;
// OR in ngOnInit via history.state (after navigation completes)
const orderId = history.state['orderId'];
```

---

## 9. Testing Routes

```typescript
// src/app/features/users/pages/users-list-page.component.spec.ts
describe('UsersListPageComponent', () => {
  let router: Router;
  let location: Location;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [
        RouterTestingModule.withRoutes([
          { path: 'users', component: UsersListPageComponent },
          { path: 'users/:id', component: UserDetailPageComponent },
        ]),
        NoopAnimationsModule,
      ],
      declarations: [UsersListPageComponent, UserDetailPageComponent],
      providers: [
        { provide: UserService, useValue: jasmine.createSpyObj('UserService', ['getAll']) },
      ],
    }).compileComponents();

    router = TestBed.inject(Router);
    location = TestBed.inject(Location);
    router.initialNavigation();
  });

  it('should navigate to user detail on row click', fakeAsync(async () => {
    await router.navigate(['/users']);
    tick();

    const fixture = TestBed.createComponent(UsersListPageComponent);
    fixture.detectChanges();

    fixture.debugElement.query(By.css('[data-testid="user-row-1"]')).nativeElement.click();
    tick();

    expect(location.path()).toBe('/users/1');
  }));
});
```

**Testing rules for routing:**
- Use `RouterTestingModule.withRoutes()` — never the real `RouterModule`
- Always call `router.initialNavigation()` in `beforeEach`
- Wrap navigation assertions in `fakeAsync` + `tick()`
- Test guard logic in isolation (unit test the guard function/class directly)
- Test resolver logic in isolation — don't rely on integration tests for error paths
