# HTTP Layer Patterns

## Table of Contents
1. API Service Abstraction (base URL, typed responses)
2. Request/Response Envelope Handling
3. Retry Logic with Exponential Backoff
4. Optimistic Updates
5. Loading & Error State Pattern
6. HTTP Caching with shareReplay
7. File Upload with Progress

---

## 1. API Service Abstraction

Wrap `HttpClient` in a base service so all requests share base URL, default headers,
and consistent error mapping. Feature services extend this — they never use `HttpClient` directly.

```typescript
// src/app/core/services/api.service.ts
@Injectable({ providedIn: 'root' })
export class ApiService {
  private baseUrl = environment.apiUrl;  // e.g. 'https://api.example.com/v1'

  constructor(private http: HttpClient) {}

  get<T>(path: string, params?: Record<string, string>): Observable<T> {
    return this.http.get<T>(`${this.baseUrl}${path}`, { params });
  }

  post<T>(path: string, body: unknown): Observable<T> {
    return this.http.post<T>(`${this.baseUrl}${path}`, body);
  }

  put<T>(path: string, body: unknown): Observable<T> {
    return this.http.put<T>(`${this.baseUrl}${path}`, body);
  }

  patch<T>(path: string, body: unknown): Observable<T> {
    return this.http.patch<T>(`${this.baseUrl}${path}`, body);
  }

  delete<T>(path: string): Observable<T> {
    return this.http.delete<T>(`${this.baseUrl}${path}`);
  }
}

// src/app/features/users/services/user.service.ts
@Injectable()
export class UserService {
  private usersSubject = new BehaviorSubject<User[]>([]);
  users$ = this.usersSubject.asObservable();

  constructor(private api: ApiService) {}  // ← extend ApiService, not HttpClient

  loadUsers(): void {
    this.api.get<User[]>('/users').pipe(
      catchError(err => { console.error(err); return EMPTY; })
    ).subscribe(users => this.usersSubject.next(users));
  }

  getById(id: number): Observable<User> {
    return this.api.get<User>(`/users/${id}`);
  }

  create(payload: CreateUserDto): Observable<User> {
    return this.api.post<User>('/users', payload).pipe(
      tap(user => this.usersSubject.next([...this.usersSubject.value, user]))
    );
  }

  update(id: number, payload: Partial<User>): Observable<User> {
    return this.api.patch<User>(`/users/${id}`, payload).pipe(
      tap(updated => this.usersSubject.next(
        this.usersSubject.value.map(u => u.id === id ? updated : u)
      ))
    );
  }

  delete(id: number): Observable<void> {
    return this.api.delete<void>(`/users/${id}`).pipe(
      tap(() => this.usersSubject.next(
        this.usersSubject.value.filter(u => u.id !== id)
      ))
    );
  }
}
```

---

## 2. Request/Response Envelope Handling

Most APIs wrap responses in an envelope. Handle this once in the base service, not in every feature service.

```typescript
// Common envelope shape: { data: T, message: string, success: boolean }
export interface ApiResponse<T> {
  data: T;
  message: string;
  success: boolean;
}

// Add an unwrapping helper in ApiService
getEnveloped<T>(path: string): Observable<T> {
  return this.http
    .get<ApiResponse<T>>(`${this.baseUrl}${path}`)
    .pipe(map(response => response.data));
}

postEnveloped<T>(path: string, body: unknown): Observable<T> {
  return this.http
    .post<ApiResponse<T>>(`${this.baseUrl}${path}`, body)
    .pipe(map(response => response.data));
}

// Feature services call getEnveloped — they receive T, not ApiResponse<T>
getById(id: number): Observable<User> {
  return this.api.getEnveloped<User>(`/users/${id}`);
}
```

---

## 3. Retry Logic with Exponential Backoff

Retry transient network failures automatically. Never retry 4xx errors — those are client errors
and retrying them will never succeed.

```typescript
// src/app/core/utils/retry.util.ts
export function retryWithBackoff(maxRetries = 3, initialDelay = 1000) {
  return <T>(source: Observable<T>): Observable<T> =>
    source.pipe(
      retryWhen(errors =>
        errors.pipe(
          concatMap((error, attempt) => {
            // Don't retry client errors (400–499)
            if (error instanceof HttpErrorResponse && error.status >= 400 && error.status < 500) {
              return throwError(() => error);
            }
            if (attempt >= maxRetries) return throwError(() => error);

            const delay = initialDelay * Math.pow(2, attempt);  // 1s, 2s, 4s
            console.warn(`Request failed. Retrying in ${delay}ms... (attempt ${attempt + 1}/${maxRetries})`);
            return timer(delay);
          })
        )
      )
    );
}

// Usage in a service
loadUsers(): void {
  this.api.get<User[]>('/users').pipe(
    retryWithBackoff(3, 1000),
    catchError(err => { console.error('Permanently failed:', err); return EMPTY; })
  ).subscribe(users => this.usersSubject.next(users));
}
```

---

## 4. Optimistic Updates

Update the UI immediately on user action, then sync with the server in the background.
Roll back if the server call fails — the user sees instant feedback and a fallback on error.

```typescript
// Optimistic delete
delete(id: number): Observable<void> {
  const previous = this.usersSubject.value;    // snapshot for rollback

  // Update UI immediately before the HTTP call completes
  this.usersSubject.next(previous.filter(u => u.id !== id));

  return this.api.delete<void>(`/users/${id}`).pipe(
    catchError(err => {
      this.usersSubject.next(previous);         // roll back on failure
      return throwError(() => err);
    })
  );
}

// Optimistic update
update(id: number, payload: Partial<User>): Observable<User> {
  const previous = this.usersSubject.value;
  const optimistic = previous.map(u => u.id === id ? { ...u, ...payload } : u);

  this.usersSubject.next(optimistic);

  return this.api.patch<User>(`/users/${id}`, payload).pipe(
    tap(confirmed => {
      // Replace optimistic value with the server-confirmed value
      this.usersSubject.next(
        this.usersSubject.value.map(u => u.id === id ? confirmed : u)
      );
    }),
    catchError(err => {
      this.usersSubject.next(previous);
      return throwError(() => err);
    })
  );
}
```

---

## 5. Loading & Error State Pattern

Expose loading and error state from the service so components and templates can react without
managing that state themselves.

```typescript
// Generic async state wrapper — use this type across services
export interface AsyncState<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
}

// In a service
@Injectable()
export class ProductService {
  private state = new BehaviorSubject<AsyncState<Product[]>>({
    data: null,
    loading: false,
    error: null,
  });

  state$ = this.state.asObservable();
  products$ = this.state$.pipe(map(s => s.data));
  loading$ = this.state$.pipe(map(s => s.loading));
  error$   = this.state$.pipe(map(s => s.error));

  constructor(private api: ApiService) {}

  loadProducts(): void {
    this.state.next({ data: null, loading: true, error: null });

    this.api.get<Product[]>('/products').subscribe({
      next: data => this.state.next({ data, loading: false, error: null }),
      error: err => this.state.next({
        data: null,
        loading: false,
        error: err.error?.message ?? 'Failed to load products',
      }),
    });
  }
}
```

```html
<!-- Template reacts to state without any logic in the component -->
<mat-spinner *ngIf="loading$ | async"></mat-spinner>

<mat-error *ngIf="error$ | async as error">{{ error }}</mat-error>

<app-product-card
  *ngFor="let product of products$ | async; trackBy: trackById"
  [product]="product"
></app-product-card>
```

---

## 6. HTTP Caching with shareReplay

For reference data that rarely changes (countries, currencies, config), fetch once per
session and replay the result to any subscriber.

```typescript
// src/app/core/services/reference-data.service.ts
@Injectable({ providedIn: 'root' })
export class ReferenceDataService {
  // shareReplay(1): caches the last value; refCount: false keeps it alive
  readonly countries$ = this.api.get<Country[]>('/reference/countries').pipe(
    shareReplay({ bufferSize: 1, refCount: false })
  );

  readonly currencies$ = this.api.get<Currency[]>('/reference/currencies').pipe(
    shareReplay({ bufferSize: 1, refCount: false })
  );

  constructor(private api: ApiService) {}
}
```

Use `{ bufferSize: 1, refCount: false }` over `shareReplay(1)` — it keeps the subscription
alive even when all consumers unsubscribe, so the data stays cached for the session.

---

## 7. File Upload with Progress

Track upload progress and expose it as an observable for a progress bar.

```typescript
uploadFile(file: File, endpoint: string): Observable<number | null> {
  const formData = new FormData();
  formData.append('file', file, file.name);

  return this.http.post(endpoint, formData, {
    reportProgress: true,
    observe: 'events',
  }).pipe(
    map(event => {
      switch (event.type) {
        case HttpEventType.UploadProgress:
          return event.total ? Math.round(100 * event.loaded / event.total) : 0;
        case HttpEventType.Response:
          return null;  // signals completion
        default:
          return 0;
      }
    }),
    filter(progress => progress !== null)
  );
}

// Usage in component
uploadProgress = 0;

onFileSelected(event: Event): void {
  const file = (event.target as HTMLInputElement).files?.[0];
  if (!file) return;

  this.fileService.uploadFile(file, '/api/uploads').subscribe({
    next: progress => { this.uploadProgress = progress ?? 100; },
    error: err => console.error('Upload failed', err),
  });
}
```

```html
<mat-progress-bar mode="determinate" [value]="uploadProgress"></mat-progress-bar>
```
