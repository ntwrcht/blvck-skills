# Advanced Testing Patterns (Karma + Jasmine)

---
 
## Table of Contents
1. Testing Components with Routing
2. Testing Angular Material Components
3. Testing HTTP Interceptors
4. Testing Route Guards
5. Testing Async Operations
6. Reactive Form Testing
7. Useful Testing Utilities
 
---

## Testing Components with Routing

### Testing components that use ActivatedRoute
```typescript
import { ActivatedRoute, convertToParamMap } from '@angular/router';
import { of } from 'rxjs';

describe('UserDetailComponent', () => {
  let component: UserDetailComponent;
  let fixture: ComponentFixture<UserDetailComponent>;
  let userService: jasmine.SpyObj<UserService>;

  beforeEach(async () => {
    const userServiceSpy = jasmine.createSpyObj('UserService', ['getById']);
    userServiceSpy.getById.and.returnValue(of(mockUser));

    await TestBed.configureTestingModule({
      declarations: [UserDetailComponent],
      imports: [NoopAnimationsModule],
      providers: [
        { provide: UserService, useValue: userServiceSpy },
        {
          provide: ActivatedRoute,
          useValue: {
            paramMap: of(convertToParamMap({ id: '42' })),
            snapshot: { paramMap: convertToParamMap({ id: '42' }) },
          },
        },
      ],
    }).compileComponents();

    userService = TestBed.inject(UserService) as jasmine.SpyObj<UserService>;
    fixture = TestBed.createComponent(UserDetailComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should load user by id from route params', () => {
    expect(userService.getById).toHaveBeenCalledWith('42');
  });
});
```

### Testing Router.navigate calls
```typescript
import { Router } from '@angular/router';

let router: Router;

beforeEach(async () => {
  await TestBed.configureTestingModule({
    declarations: [LoginComponent],
    imports: [RouterTestingModule],  // use RouterTestingModule, not RouterModule
    providers: [/* ... */],
  }).compileComponents();

  router = TestBed.inject(Router);
  spyOn(router, 'navigate');
});

it('should redirect to dashboard after successful login', fakeAsync(() => {
  component.form.setValue({ email: 'test@test.com', password: 'Pass123!' });
  component.onSubmit();
  tick();
  expect(router.navigate).toHaveBeenCalledWith(['/dashboard']);
}));
```

---

## Testing Angular Material Components

### Mat-Dialog — opening and closing
```typescript
import { MatDialog } from '@angular/material/dialog';
import { MatDialogHarness } from '@angular/material/dialog/testing';
import { HarnessLoader } from '@angular/cdk/testing';
import { TestbedHarnessEnvironment } from '@angular/cdk/testing/testbed';

describe('UserListComponent with dialog', () => {
  let loader: HarnessLoader;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [UserListComponent, ConfirmDialogComponent],
      imports: [MatDialogModule, NoopAnimationsModule, OverlayModule],
    }).compileComponents();

    fixture = TestBed.createComponent(UserListComponent);
    loader = TestbedHarnessEnvironment.documentRootLoader(fixture);
    fixture.detectChanges();
  });

  it('should open confirm dialog when delete is clicked', async () => {
    const deleteBtn = fixture.debugElement.query(By.css('[data-testid="delete-btn"]'));
    deleteBtn.nativeElement.click();
    fixture.detectChanges();

    const dialogs = await loader.getAllHarnesses(MatDialogHarness);
    expect(dialogs.length).toBe(1);
  });
});
```

### Mat-Select — selecting an option
```typescript
import { MatSelectHarness } from '@angular/material/select/testing';

it('should filter by role when role is selected', async () => {
  const select = await loader.getHarness(MatSelectHarness);
  await select.open();
  await select.clickOptions({ text: 'Admin' });

  expect(component.selectedRole).toBe('admin');
});
```

### Mat-Table — verifying rows
```typescript
it('should render one row per user', () => {
  component.users = [mockUser1, mockUser2, mockUser3];
  fixture.detectChanges();

  const rows = fixture.debugElement.queryAll(By.css('mat-row'));
  expect(rows.length).toBe(3);
});

it('should display correct data in cells', () => {
  component.users = [mockUser1];
  fixture.detectChanges();

  const cells = fixture.debugElement.queryAll(By.css('mat-cell'));
  expect(cells[0].nativeElement.textContent.trim()).toBe(mockUser1.name);
});
```

---

## Testing HTTP Interceptors

```typescript
describe('AuthInterceptor', () => {
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule],
      providers: [
        AuthService,
        { provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor, multi: true },
      ],
    });
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => httpMock.verify());

  it('should attach Bearer token to outgoing requests', () => {
    const authService = TestBed.inject(AuthService);
    spyOn(authService, 'getToken').and.returnValue('my-jwt-token');

    TestBed.inject(HttpClient).get('/api/users').subscribe();

    const req = httpMock.expectOne('/api/users');
    expect(req.request.headers.get('Authorization')).toBe('Bearer my-jwt-token');
  });

  it('should call logout when a 401 response is received', () => {
    const authService = TestBed.inject(AuthService);
    const logoutSpy = spyOn(authService, 'logout');
    spyOn(authService, 'getToken').and.returnValue('expired-token');

    TestBed.inject(HttpClient).get('/api/users').subscribe({
      error: () => {},  // absorb the error
    });

    const req = httpMock.expectOne('/api/users');
    req.flush('Unauthorized', { status: 401, statusText: 'Unauthorized' });

    expect(logoutSpy).toHaveBeenCalled();
  });
});
```

---

## Testing Route Guards

```typescript
describe('AuthGuard', () => {
  let guard: AuthGuard;
  let router: Router;
  let authService: jasmine.SpyObj<AuthService>;

  beforeEach(() => {
    const spy = jasmine.createSpyObj('AuthService', ['isLoggedIn', 'hasRole']);

    TestBed.configureTestingModule({
      imports: [RouterTestingModule],
      providers: [
        AuthGuard,
        { provide: AuthService, useValue: spy },
      ],
    });

    guard = TestBed.inject(AuthGuard);
    router = TestBed.inject(Router);
    authService = TestBed.inject(AuthService) as jasmine.SpyObj<AuthService>;
    spyOn(router, 'navigate');
  });

  it('should allow navigation for authenticated users with correct role', () => {
    authService.isLoggedIn.and.returnValue(true);
    authService.hasRole.and.returnValue(true);

    const route = { data: { role: 'admin' } } as any;
    const result = guard.canActivate(route, {} as any);

    expect(result).toBeTrue();
    expect(router.navigate).not.toHaveBeenCalled();
  });

  it('should redirect to /forbidden for users without the required role', () => {
    authService.isLoggedIn.and.returnValue(true);
    authService.hasRole.and.returnValue(false);

    const route = { data: { role: 'admin' } } as any;
    guard.canActivate(route, {} as any);

    expect(router.navigate).toHaveBeenCalledWith(['/forbidden']);
  });
});
```

---

## Testing Async Operations

### fakeAsync + tick (synchronous-style async testing)
```typescript
it('should show error message after failed save', fakeAsync(() => {
  const saveBtn = fixture.debugElement.query(By.css('[data-testid="save-btn"]'));
  userService.save.and.returnValue(throwError(() => new Error('Save failed')));

  saveBtn.nativeElement.click();
  tick();                    // flush all pending async tasks
  fixture.detectChanges();

  const error = fixture.debugElement.query(By.css('[data-testid="error-msg"]'));
  expect(error.nativeElement.textContent).toContain('Save failed');
}));
```

### Testing debounceTime
```typescript
it('should not search until 300ms after typing stops', fakeAsync(() => {
  const input = fixture.debugElement.query(By.css('[data-testid="search-input"]'));

  input.nativeElement.value = 'ang';
  input.nativeElement.dispatchEvent(new Event('input'));
  tick(200);  // not enough — search shouldn't have fired yet

  expect(searchService.search).not.toHaveBeenCalled();

  tick(100);  // total 300ms — now it should fire
  expect(searchService.search).toHaveBeenCalledWith('ang');
}));
```

### async/await with whenStable (for Promises)
```typescript
it('should load user profile on init', async () => {
  userService.getProfile.and.returnValue(Promise.resolve(mockUser));
  fixture.detectChanges();

  await fixture.whenStable();  // wait for all promises to resolve
  fixture.detectChanges();

  const name = fixture.debugElement.query(By.css('[data-testid="user-name"]'));
  expect(name.nativeElement.textContent).toBe(mockUser.name);
});
```

---

## Reactive Form Testing

```typescript
describe('RegistrationFormComponent', () => {
  let component: RegistrationFormComponent;
  let fixture: ComponentFixture<RegistrationFormComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [RegistrationFormComponent],
      imports: [ReactiveFormsModule, MatFormFieldModule, MatInputModule, NoopAnimationsModule],
    }).compileComponents();

    fixture = TestBed.createComponent(RegistrationFormComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should be invalid when empty', () => {
    expect(component.form.valid).toBeFalse();
  });

  it('should validate email format', () => {
    const emailCtrl = component.form.get('email')!;
    emailCtrl.setValue('not-an-email');
    expect(emailCtrl.hasError('email')).toBeTrue();

    emailCtrl.setValue('valid@test.com');
    expect(emailCtrl.hasError('email')).toBeFalse();
  });

  it('should fail password validation when shorter than 8 characters', () => {
    component.form.get('password')!.setValue('Short1');
    expect(component.form.get('password')!.hasError('minlength')).toBeTrue();
  });

  it('should fail password validation when no number is present', () => {
    component.form.get('password')!.setValue('NoNumberHere');
    expect(component.form.get('password')!.hasError('pattern')).toBeTrue();
  });

  it('should fail form validation when passwords do not match', () => {
    component.form.get('password')!.setValue('ValidPass1');
    component.form.get('confirmPassword')!.setValue('DifferentPass1');
    expect(component.form.hasError('passwordMismatch')).toBeTrue();
  });

  it('should be valid with all correct values', () => {
    component.form.setValue({
      email: 'user@example.com',
      password: 'ValidPass1',
      confirmPassword: 'ValidPass1',
      role: 'admin',
    });
    expect(component.form.valid).toBeTrue();
  });
});
```

---

## Useful Testing Utilities

### Mock factory helper
```typescript
// test-helpers.ts
export function createMockUser(overrides: Partial<User> = {}): User {
  return {
    id: 1,
    firstName: 'Alice',
    lastName: 'Smith',
    email: 'alice@example.com',
    role: 'viewer',
    status: 'active',
    ...overrides,
  };
}
```

### Common imports cheatsheet
```typescript
// For most component tests
imports: [
  NoopAnimationsModule,       // instead of BrowserAnimationsModule
  ReactiveFormsModule,        // for reactive forms
  MatFormFieldModule,
  MatInputModule,
  RouterTestingModule,        // when component uses Router or RouterLink
  HttpClientTestingModule,    // when component/service uses HttpClient
]
```
