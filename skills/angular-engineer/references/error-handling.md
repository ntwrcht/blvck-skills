# Error Handling Patterns

## Table of Contents
1. Global ErrorHandler
2. HTTP Error Interceptor (status-based routing)
3. Error Notification Service (snackbar/toast)
4. Error Logging Service
5. Component-Level HTTP Error Handling
6. Form Validation Error Display Pattern
7. Graceful Degradation (partial failure)

---

## 1. Global ErrorHandler

Catches unhandled JavaScript errors and uncaught promise rejections across the entire app.
Use this as the final safety net — it should log and notify, not silently swallow.

```typescript
// src/app/core/handlers/global-error.handler.ts
@Injectable()
export class GlobalErrorHandler implements ErrorHandler {
  constructor(private injector: Injector) {}

  handleError(error: unknown): void {
    const notificationService = this.injector.get(NotificationService);
    const loggingService = this.injector.get(LoggingService);

    // Unwrap Angular's zone.js error wrapping
    const unwrapped = (error as { rejection?: unknown })?.rejection ?? error;

    loggingService.logError(unwrapped);

    if (unwrapped instanceof HttpErrorResponse) {
      // HTTP errors are handled by the interceptor — skip double notification
      return;
    }

    notificationService.showError('An unexpected error occurred. Please refresh and try again.');

    // Re-throw in development so DevTools still shows the error
    if (!environment.production) {
      throw unwrapped;
    }
  }
}

// Register in AppModule — replaces Angular's default ErrorHandler
providers: [
  { provide: ErrorHandler, useClass: GlobalErrorHandler }
]
```

Use `Injector` instead of direct constructor injection to avoid circular dependency issues
(services like `Router` or `MatSnackBar` depend on things that are initialized after `ErrorHandler`).

---

## 2. HTTP Error Interceptor

Centralizes all HTTP error handling. Maps status codes to user-facing messages,
handles session expiry (401), and access denied (403) in one place.

```typescript
// src/app/core/interceptors/error.interceptor.ts
@Injectable()
export class ErrorInterceptor implements HttpInterceptor {
  constructor(
    private notificationService: NotificationService,
    private authService: AuthService,
    private router: Router
  ) {}

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    return next.handle(req).pipe(
      catchError((error: HttpErrorResponse) => {
        switch (error.status) {
          case 401:
            // Token refresh interceptor runs first — if we still get 401 here, session is dead
            this.authService.logout();
            this.notificationService.showError('Your session has expired. Please log in again.');
            break;

          case 403:
            this.router.navigate(['/unauthorized']);
            this.notificationService.showError('You do not have permission to perform this action.');
            break;

          case 404:
            this.notificationService.showError('The requested resource was not found.');
            break;

          case 422:
            // Validation errors from the server — let the component handle display
            break;

          case 500:
          case 502:
          case 503:
            this.notificationService.showError('A server error occurred. Please try again shortly.');
            break;

          default:
            if (!navigator.onLine) {
              this.notificationService.showError('No internet connection. Please check your network.');
            }
        }

        return throwError(() => error);  // re-throw so services/components can also handle it
      })
    );
  }
}

// Register in CoreModule — place AFTER TokenRefreshInterceptor
providers: [
  { provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor, multi: true },
  { provide: HTTP_INTERCEPTORS, useClass: TokenRefreshInterceptor, multi: true },
  { provide: HTTP_INTERCEPTORS, useClass: ErrorInterceptor, multi: true },   // last
]
```

---

## 3. Notification Service (Snackbar / Toast)

A thin wrapper around `MatSnackBar` so components never import Material directly
and the notification style is consistent across the app.

```typescript
// src/app/core/services/notification.service.ts
export type NotificationType = 'success' | 'error' | 'info' | 'warning';

@Injectable({ providedIn: 'root' })
export class NotificationService {
  constructor(private snackBar: MatSnackBar) {}

  showSuccess(message: string, duration = 3000): void {
    this.show(message, 'success', duration);
  }

  showError(message: string, duration = 5000): void {
    this.show(message, 'error', duration);
  }

  showInfo(message: string, duration = 3000): void {
    this.show(message, 'info', duration);
  }

  private show(message: string, type: NotificationType, duration: number): void {
    this.snackBar.open(message, 'Dismiss', {
      duration,
      horizontalPosition: 'end',
      verticalPosition: 'top',
      panelClass: [`snack-${type}`],  // apply via styles.scss: .snack-error { background: $warn; }
    });
  }
}
```

Style the snackbar variants in `styles.scss`:
```scss
// styles/styles.scss
.snack-success .mdc-snackbar__surface { background-color: $success !important; }
.snack-error   .mdc-snackbar__surface { background-color: $warn !important; }
.snack-info    .mdc-snackbar__surface { background-color: $primary !important; }
.snack-warning .mdc-snackbar__surface { background-color: $accent !important; }
```

---

## 4. Error Logging Service

Centralizes logging so you can swap the backend (console, Sentry, Datadog) without
touching every service. In development, log to console. In production, send to a monitoring service.

```typescript
// src/app/core/services/logging.service.ts
@Injectable({ providedIn: 'root' })
export class LoggingService {
  logError(error: unknown, context?: Record<string, unknown>): void {
    if (environment.production) {
      // Replace with Sentry.captureException(error, { extra: context }) or similar
      this.sendToMonitoring(error, context);
    } else {
      console.error('[Error]', error, context ?? '');
    }
  }

  logWarning(message: string, context?: Record<string, unknown>): void {
    if (environment.production) {
      this.sendToMonitoring(new Error(message), { level: 'warning', ...context });
    } else {
      console.warn('[Warning]', message, context ?? '');
    }
  }

  private sendToMonitoring(error: unknown, context?: Record<string, unknown>): void {
    // Example: Sentry integration
    // Sentry.withScope(scope => {
    //   if (context) scope.setExtras(context);
    //   Sentry.captureException(error);
    // });
    console.error('[Production Error]', error, context);  // fallback until monitoring is wired
  }
}
```

---

## 5. Component-Level HTTP Error Handling

The interceptor handles global errors (401, 403, 500). Components handle business-logic errors
specific to their context — for example, a 409 conflict on a form submission.

```typescript
@Component({ ... })
export class UserFormComponent implements OnDestroy {
  form = this.fb.group({ ... });
  isSubmitting = false;
  serverErrors: Record<string, string> = {};  // field-level server validation errors
  generalError: string | null = null;

  private destroy$ = new Subject<void>();

  onSubmit(): void {
    if (this.form.invalid || this.isSubmitting) return;

    this.isSubmitting = true;
    this.serverErrors = {};
    this.generalError = null;

    this.userService.create(this.form.getRawValue()).pipe(
      takeUntil(this.destroy$),
      finalize(() => { this.isSubmitting = false; })
    ).subscribe({
      next: () => this.router.navigate(['/users']),
      error: (err: HttpErrorResponse) => {
        if (err.status === 422 && err.error?.errors) {
          // Map server field errors back to the form
          // e.g. { errors: { email: 'already taken', name: 'too short' } }
          this.serverErrors = err.error.errors;
          Object.keys(this.serverErrors).forEach(field => {
            this.form.get(field)?.setErrors({ server: this.serverErrors[field] });
          });
        } else if (err.status === 409) {
          this.generalError = 'A user with this email already exists.';
        }
        // 401, 403, 500 are already handled by the interceptor — no double notification
      },
    });
  }

  ngOnDestroy(): void { this.destroy$.next(); this.destroy$.complete(); }
}
```

```html
<mat-error *ngIf="generalError">{{ generalError }}</mat-error>

<mat-form-field>
  <input matInput formControlName="email" />
  <mat-error *ngIf="form.get('email')?.hasError('server')">
    {{ form.get('email')?.getError('server') }}
  </mat-error>
</mat-form-field>
```

---

## 6. Form Validation Error Display Pattern

A reusable approach to avoid repeating `*ngIf="control.hasError(...)"` across every template.

```typescript
// src/app/shared/utils/form-errors.util.ts
export const FORM_ERROR_MESSAGES: Record<string, string | ((err: unknown) => string)> = {
  required:      'This field is required.',
  email:         'Please enter a valid email address.',
  minlength:     (err: { requiredLength: number }) => `Minimum ${err.requiredLength} characters.`,
  maxlength:     (err: { requiredLength: number }) => `Maximum ${err.requiredLength} characters.`,
  min:           (err: { min: number }) => `Minimum value is ${err.min}.`,
  max:           (err: { max: number }) => `Maximum value is ${err.max}.`,
  passwordStrength: 'Must be 8+ chars with uppercase, lowercase, number, and special character.',
  emailTaken:    'This email is already registered.',
  passwordMismatch: 'Passwords do not match.',
  server:        (err: string) => err,  // pass through server messages as-is
};

export function getFirstError(control: AbstractControl): string | null {
  if (!control.errors || !control.touched) return null;
  const key = Object.keys(control.errors)[0];
  const message = FORM_ERROR_MESSAGES[key];
  if (!message) return `Invalid value (${key}).`;
  return typeof message === 'function' ? message(control.errors[key]) : message;
}
```

Usage in templates via a simple pipe:
```typescript
// src/app/shared/pipes/form-error.pipe.ts
@Pipe({ name: 'formError', pure: false })
export class FormErrorPipe implements PipeTransform {
  transform(control: AbstractControl | null): string | null {
    if (!control) return null;
    return getFirstError(control);
  }
}
```

```html
<!-- Clean template — no more repeated *ngIf chains per error type -->
<mat-form-field>
  <input matInput formControlName="email" />
  <mat-error>{{ form.get('email') | formError }}</mat-error>
</mat-form-field>
```

---

## 7. Graceful Degradation (Partial Failure)

When a page loads data from multiple endpoints, don't fail the whole page if one call fails.
Load what you can and show partial results with an inline error for what failed.

```typescript
@Component({ ... })
export class DashboardPageComponent implements OnInit {
  users$!: Observable<User[]>;
  stats$!: Observable<DashboardStats | null>;
  statsError$!: Observable<string | null>;

  private statsErrorSubject = new BehaviorSubject<string | null>(null);

  ngOnInit(): void {
    this.users$ = this.userService.getAll().pipe(
      catchError(() => of([]))     // empty array — table shows empty state, not a crash
    );

    this.stats$ = this.statsService.getStats().pipe(
      catchError(err => {
        this.statsErrorSubject.next('Failed to load statistics.');
        return of(null);           // null — template shows error state for this section only
      })
    );

    this.statsError$ = this.statsErrorSubject.asObservable();
  }
}
```

```html
<!-- Stats section fails independently — users table still loads -->
<app-stats-card *ngIf="stats$ | async as stats; else statsError" [stats]="stats">
</app-stats-card>
<ng-template #statsError>
  <mat-card class="p-3">
    <mat-error>{{ statsError$ | async }}</mat-error>
  </mat-card>
</ng-template>

<!-- Users table loads regardless of stats failure -->
<app-users-table [users]="users$ | async"></app-users-table>
```
