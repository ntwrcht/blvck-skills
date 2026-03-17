# Reactive Forms Patterns

## Table of Contents
1. FormBuilder Basics & Typed Forms (ng14+)
2. Nested FormGroups
3. Dynamic FormArrays (add/remove rows)
4. Custom Synchronous Validators
5. Custom Async Validators (server-side check)
6. Cross-Field Validation
7. ControlValueAccessor (reusable form components)
8. Form Submission Pattern (loading, error, reset)

---

## 1. FormBuilder Basics & Typed Forms

Angular 14 introduced strictly typed reactive forms. Always use typed forms — they catch
bugs at compile time that previously only appeared at runtime.

```typescript
// ✅ Typed reactive form (Angular 14+)
interface UserForm {
  name: FormControl<string>;
  email: FormControl<string>;
  role: FormControl<string | null>;
}

@Component({ ... })
export class UserFormComponent {
  form: FormGroup<UserForm> = this.fb.group({
    name:  this.fb.nonNullable.control('', [Validators.required, Validators.minLength(2)]),
    email: this.fb.nonNullable.control('', [Validators.required, Validators.email]),
    role:  this.fb.control<string | null>(null),
  });

  constructor(private fb: FormBuilder) {}

  get name() { return this.form.controls.name; }
  get email() { return this.form.controls.email; }
}
```

```html
<!-- Template — pair with mat-form-field for Material styling -->
<form [formGroup]="form" (ngSubmit)="onSubmit()">
  <mat-form-field>
    <mat-label>Name</mat-label>
    <input matInput formControlName="name" />
    <mat-error *ngIf="name.hasError('required')">Name is required</mat-error>
    <mat-error *ngIf="name.hasError('minlength')">At least 2 characters</mat-error>
  </mat-form-field>
</form>
```

---

## 2. Nested FormGroups

Use nested groups to model complex domain objects and keep validation scoped.

```typescript
form = this.fb.group({
  personal: this.fb.group({
    firstName: this.fb.nonNullable.control('', Validators.required),
    lastName:  this.fb.nonNullable.control('', Validators.required),
  }),
  address: this.fb.group({
    street:  this.fb.nonNullable.control(''),
    city:    this.fb.nonNullable.control('', Validators.required),
    country: this.fb.nonNullable.control('', Validators.required),
  }),
});

// Access nested controls cleanly
get city() { return this.form.get('address.city') as FormControl; }
```

```html
<div formGroupName="personal">
  <input matInput formControlName="firstName" />
  <input matInput formControlName="lastName" />
</div>

<div formGroupName="address">
  <input matInput formControlName="city" />
  <input matInput formControlName="country" />
</div>
```

---

## 3. Dynamic FormArrays

Use `FormArray` when the number of items is unknown at design time (line items, contacts, tags).

```typescript
@Component({ ... })
export class InvoiceFormComponent {
  form = this.fb.group({
    clientName: this.fb.nonNullable.control('', Validators.required),
    lineItems: this.fb.array<FormGroup>([]),
  });

  get lineItems(): FormArray {
    return this.form.controls.lineItems;
  }

  addLineItem(): void {
    this.lineItems.push(
      this.fb.group({
        description: this.fb.nonNullable.control('', Validators.required),
        quantity:    this.fb.nonNullable.control(1, [Validators.required, Validators.min(1)]),
        unitPrice:   this.fb.nonNullable.control(0, [Validators.required, Validators.min(0)]),
      })
    );
  }

  removeLineItem(index: number): void {
    this.lineItems.removeAt(index);
  }

  // Computed total — use a getter, not a method
  get total(): number {
    return this.lineItems.controls.reduce((sum, group) => {
      const { quantity, unitPrice } = group.value;
      return sum + (quantity ?? 0) * (unitPrice ?? 0);
    }, 0);
  }

  constructor(private fb: FormBuilder) {
    this.addLineItem(); // start with one row
  }
}
```

```html
<div formArrayName="lineItems">
  <div *ngFor="let item of lineItems.controls; let i = index"
       [formGroupName]="i" class="d-flex gap-2 align-items-center">
    <mat-form-field>
      <input matInput formControlName="description" placeholder="Description" />
    </mat-form-field>
    <mat-form-field style="width: 80px">
      <input matInput type="number" formControlName="quantity" />
    </mat-form-field>
    <mat-form-field style="width: 100px">
      <input matInput type="number" formControlName="unitPrice" />
    </mat-form-field>
    <button mat-icon-button type="button" (click)="removeLineItem(i)">
      <mat-icon>delete</mat-icon>
    </button>
  </div>
</div>

<button mat-stroked-button type="button" (click)="addLineItem()">Add Line</button>
<p>Total: {{ total | currency }}</p>
```

---

## 4. Custom Synchronous Validators

Return `null` when valid; return an error object when invalid. Keep validators pure functions.

```typescript
// src/app/shared/validators/password-strength.validator.ts
export function passwordStrengthValidator(): ValidatorFn {
  return (control: AbstractControl): ValidationErrors | null => {
    const value: string = control.value ?? '';
    const hasUpperCase  = /[A-Z]/.test(value);
    const hasLowerCase  = /[a-z]/.test(value);
    const hasNumber     = /[0-9]/.test(value);
    const hasSpecial    = /[!@#$%^&*]/.test(value);
    const isLongEnough  = value.length >= 8;

    const valid = hasUpperCase && hasLowerCase && hasNumber && hasSpecial && isLongEnough;
    return valid ? null : {
      passwordStrength: {
        hasUpperCase, hasLowerCase, hasNumber, hasSpecial, isLongEnough
      }
    };
  };
}

// Usage
password: this.fb.nonNullable.control('', [Validators.required, passwordStrengthValidator()])
```

```html
<mat-error *ngIf="password.hasError('passwordStrength')">
  Password must be 8+ characters with uppercase, lowercase, number, and special character.
</mat-error>
```

---

## 5. Custom Async Validators

For server-side checks (e.g., username availability). Debounce to avoid hammering the API.

```typescript
// src/app/shared/validators/unique-email.validator.ts
@Injectable({ providedIn: 'root' })
export class UniqueEmailValidator implements AsyncValidator {
  constructor(private http: HttpClient) {}

  validate(control: AbstractControl): Observable<ValidationErrors | null> {
    if (!control.value) return of(null);

    return timer(400).pipe(   // debounce — wait 400ms after last keystroke
      switchMap(() =>
        this.http.get<{ exists: boolean }>(`/api/users/check-email?email=${control.value}`)
      ),
      map(({ exists }) => exists ? { emailTaken: true } : null),
      catchError(() => of(null))  // on network error, don't block the form
    );
  }
}

// Usage — inject and pass to control
email: this.fb.nonNullable.control(
  '',
  [Validators.required, Validators.email],
  [this.uniqueEmailValidator.validate.bind(this.uniqueEmailValidator)]
)
```

```html
<!-- Show pending state while async validator runs -->
<mat-hint *ngIf="email.pending">Checking availability…</mat-hint>
<mat-error *ngIf="email.hasError('emailTaken')">This email is already registered.</mat-error>
```

---

## 6. Cross-Field Validation

Validate relationships between fields at the group level, not the control level.

```typescript
// src/app/shared/validators/password-match.validator.ts
export function passwordMatchValidator(passwordKey: string, confirmKey: string): ValidatorFn {
  return (group: AbstractControl): ValidationErrors | null => {
    const password = group.get(passwordKey)?.value;
    const confirm  = group.get(confirmKey)?.value;
    return password === confirm ? null : { passwordMismatch: true };
  };
}

// Apply at group level, not control level
form = this.fb.group(
  {
    password:        this.fb.nonNullable.control('', [Validators.required, passwordStrengthValidator()]),
    confirmPassword: this.fb.nonNullable.control('', Validators.required),
  },
  { validators: passwordMatchValidator('password', 'confirmPassword') }
);
```

```html
<!-- Group-level error lives on the form, not a specific control -->
<mat-error *ngIf="form.hasError('passwordMismatch') && form.get('confirmPassword')?.touched">
  Passwords do not match.
</mat-error>
```

---

## 7. ControlValueAccessor (Reusable Form Components)

When a dumb component needs to work inside a reactive form as if it were a native input.
Common examples: star rating, custom date picker, tag input, rich text editor.

```typescript
// src/app/shared/components/star-rating/star-rating.component.ts
@Component({
  selector: 'app-star-rating',
  templateUrl: './star-rating.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [{
    provide: NG_VALUE_ACCESSOR,
    useExisting: forwardRef(() => StarRatingComponent),
    multi: true,
  }],
})
export class StarRatingComponent implements ControlValueAccessor {
  rating = 0;
  isDisabled = false;

  private onChange: (value: number) => void = () => {};
  private onTouched: () => void = () => {};

  // Called by Angular when the form sets a value programmatically
  writeValue(value: number): void { this.rating = value ?? 0; }

  // Register the callback Angular calls when our value changes
  registerOnChange(fn: (value: number) => void): void { this.onChange = fn; }

  // Register the callback Angular calls when the control is "touched"
  registerOnTouched(fn: () => void): void { this.onTouched = fn; }

  setDisabledState(disabled: boolean): void { this.isDisabled = disabled; }

  select(star: number): void {
    if (this.isDisabled) return;
    this.rating = star;
    this.onChange(star);
    this.onTouched();
  }
}
```

Usage in a parent form — works exactly like a native input:
```html
<app-star-rating formControlName="rating"></app-star-rating>
```

---

## 8. Form Submission Pattern

Standard pattern for handling loading state, server errors, and reset after success.

```typescript
@Component({ ... })
export class UserFormComponent implements OnDestroy {
  form = this.fb.group({ ... });
  isSubmitting = false;
  serverError: string | null = null;

  private destroy$ = new Subject<void>();

  constructor(private userService: UserService, private router: Router) {}

  onSubmit(): void {
    if (this.form.invalid || this.isSubmitting) return;

    this.isSubmitting = true;
    this.serverError = null;

    this.userService.create(this.form.getRawValue()).pipe(
      takeUntil(this.destroy$),
      finalize(() => { this.isSubmitting = false; })
    ).subscribe({
      next: () => this.router.navigate(['/users']),
      error: (err: HttpErrorResponse) => {
        this.serverError = err.error?.message ?? 'Something went wrong. Please try again.';
      },
    });
  }

  ngOnDestroy(): void { this.destroy$.next(); this.destroy$.complete(); }
}
```

```html
<form [formGroup]="form" (ngSubmit)="onSubmit()">
  <!-- fields -->

  <mat-error *ngIf="serverError">{{ serverError }}</mat-error>

  <button mat-raised-button color="primary" type="submit"
          [disabled]="form.invalid || isSubmitting">
    <mat-spinner *ngIf="isSubmitting" diameter="20"></mat-spinner>
    <span *ngIf="!isSubmitting">Save</span>
  </button>
</form>
```
