# Auth Patterns

## Table of Contents
1. Auth Service (token storage, login/logout, state)
2. JWT Interceptor (attach token to every request)
3. Token Refresh Interceptor (silent refresh on 401)
4. Route Guards (CanActivate, CanLoad)
5. Protecting the Entire App on Startup

---

## 1. Auth Service

Single source of truth for authentication state. Persists token in `localStorage` and exposes
reactive state so components and guards can react to login/logout without polling.

> **Why `HttpClient` directly here:** Auth endpoints (login, refresh, `/me`) are called before
> any token exists, so they cannot go through `ApiService` which adds the `Authorization` header.
> This is the one intentional exception to the "never use HttpClient directly" rule.

```typescript
// src/app/core/services/auth.service.ts
export interface AuthUser {
  id: number;
  email: string;
  roles: string[];
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private currentUserSubject = new BehaviorSubject<AuthUser | null>(
    this.getUserFromStorage()
  );

  currentUser$ = this.currentUserSubject.asObservable();
  isAuthenticated$ = this.currentUser$.pipe(map(user => !!user));

  constructor(private http: HttpClient, private router: Router) {}

  login(email: string, password: string): Observable<void> {
    return this.http.post<{ token: string; user: AuthUser }>('/api/auth/login', { email, password }).pipe(
      tap(({ token, user }) => {
        localStorage.setItem('auth_token', token);
        this.currentUserSubject.next(user);
      }),
      map(() => void 0)
    );
  }

  logout(): void {
    localStorage.removeItem('auth_token');
    this.currentUserSubject.next(null);
    this.router.navigate(['/login']);
  }

  getToken(): string | null {
    return localStorage.getItem('auth_token');
  }

  hasRole(role: string): boolean {
    return this.currentUserSubject.value?.roles.includes(role) ?? false;
  }

  private getUserFromStorage(): AuthUser | null {
    const token = localStorage.getItem('auth_token');
    if (!token) return null;
    try {
      // Decode JWT payload (middle segment) — no library needed for reading claims
      const payload = JSON.parse(atob(token.split('.')[1]));
      const isExpired = payload.exp * 1000 < Date.now();
      if (isExpired) { localStorage.removeItem('auth_token'); return null; }
      return { id: payload.sub, email: payload.email, roles: payload.roles ?? [] };
    } catch {
      return null;
    }
  }
}
```

---

## 2. JWT Interceptor

Attaches the Bearer token to every outgoing request. Skips public endpoints (login, refresh).

```typescript
// src/app/core/interceptors/auth.interceptor.ts
@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  private readonly PUBLIC_URLS = ['/api/auth/login', '/api/auth/refresh'];

  constructor(private authService: AuthService) {}

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    const token = this.authService.getToken();
    const isPublic = this.PUBLIC_URLS.some(url => req.url.includes(url));

    if (!token || isPublic) return next.handle(req);

    return next.handle(
      req.clone({ setHeaders: { Authorization: `Bearer ${token}` } })
    );
  }
}
```

Register in `CoreModule`:
```typescript
providers: [
  { provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor, multi: true },
]
```

---

## 3. Token Refresh Interceptor

Silently refreshes the token on a 401 response, retries the original request once,
then logs out if refresh also fails. Uses a shared refresh observable to prevent
multiple simultaneous refresh calls (race condition guard).

```typescript
// src/app/core/interceptors/token-refresh.interceptor.ts
@Injectable()
export class TokenRefreshInterceptor implements HttpInterceptor {
  private isRefreshing = false;
  private refreshDone$ = new Subject<string>();

  constructor(private http: HttpClient, private authService: AuthService) {}

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    return next.handle(req).pipe(
      catchError(error => {
        if (error instanceof HttpErrorResponse && error.status === 401 && !req.url.includes('/auth/')) {
          return this.handle401(req, next);
        }
        return throwError(() => error);
      })
    );
  }

  private handle401(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    if (!this.isRefreshing) {
      this.isRefreshing = true;

      this.http.post<{ token: string }>('/api/auth/refresh', {}).pipe(
        tap(({ token }) => {
          localStorage.setItem('auth_token', token);
          this.refreshDone$.next(token);
        }),
        catchError(err => {
          this.authService.logout();
          return throwError(() => err);
        }),
        finalize(() => { this.isRefreshing = false; })
      ).subscribe();
    }

    // All concurrent requests wait for the new token, then retry
    return this.refreshDone$.pipe(
      take(1),
      switchMap(token =>
        next.handle(req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }))
      )
    );
  }
}
```

Register **after** `AuthInterceptor` in `CoreModule` providers so it runs on the 401 response.

---

## 4. Route Guards
 
For full guard patterns (CanActivate, CanLoad, canMatch, CanDeactivate, functional guards, role-based)
→ READ `references/routing-patterns.md` section 3.
 
Auth-specific guard usage:
 
```typescript
// Apply auth + role guard together on a route
{
  path: 'settings',
  component: SettingsPageComponent,
  canActivate: [AuthGuard, RoleGuard],
  data: { role: 'ADMIN' },
}
 
// Lazy-loaded route — always add both canActivate AND canLoad (ng14-15) or canMatch (ng15+)
{
  path: 'admin',
  loadChildren: () => import('./features/admin/admin.module').then(m => m.AdminModule),
  canActivate: [AuthGuard],
  canLoad: [AuthLoadGuard],   // ng14-15
  // canMatch: [authGuard],   // ng15+ functional style
}
```

---

## 5. Protecting the App on Startup (APP_INITIALIZER)

Validate the stored token against the server before the app renders.
Prevents a flash of authenticated UI when the token is expired.

```typescript
// src/app/core/services/auth-init.service.ts
@Injectable({ providedIn: 'root' })
export class AuthInitService {
  constructor(private http: HttpClient, private authService: AuthService) {}

  initialize(): Observable<void> {
    const token = localStorage.getItem('auth_token');
    if (!token) return of(void 0);

    return this.http.get<AuthUser>('/api/auth/me').pipe(
      tap(user => this.authService['currentUserSubject'].next(user)),
      map(() => void 0),
      catchError(() => {
        localStorage.removeItem('auth_token');
        return of(void 0);  // always resolve so the app boots
      })
    );
  }
}

// Register in AppModule:
{
  provide: APP_INITIALIZER,
  useFactory: (authInit: AuthInitService) => () => authInit.initialize(),
  deps: [AuthInitService],
  multi: true,
}
```
