# Design System — SCSS & Theming

## Starter `_variables.scss`

Use this as the base when a project has no `_variables.scss` yet.
It bridges Angular Material's theme palette with Bootstrap overrides so both
libraries draw from the same source of truth.

```scss
// src/styles/_variables.scss

// --- Colors — keep in sync with your Material theme palette ---
$primary:           #1976d2;
$primary-light:     #63a4ff;
$primary-dark:      #004ba0;
$accent:            #ff4081;
$warn:              #f44336;
$success:           #388e3c;
$surface:           #ffffff;
$background:        #f5f5f5;
$text-primary:      rgba(0, 0, 0, 0.87);
$text-secondary:    rgba(0, 0, 0, 0.54);
$text-disabled:     rgba(0, 0, 0, 0.38);
$text-on-primary:   #ffffff;
$divider:           rgba(0, 0, 0, 0.12);

// --- Spacing Scale ---
$spacing-xs:  4px;
$spacing-sm:  8px;
$spacing-md:  16px;
$spacing-lg:  24px;
$spacing-xl:  32px;
$spacing-2xl: 48px;

// --- Typography ---
$font-family-base:  'Roboto', sans-serif;
$font-size-base:    14px;
$font-size-sm:      12px;
$font-size-lg:      16px;
$font-size-h1:      24px;
$font-size-h2:      20px;
$font-size-h3:      16px;
$line-height-base:  1.5;
$font-weight-normal: 400;
$font-weight-medium: 500;
$font-weight-bold:   700;

// --- Borders & Shadows ---
$border-radius-sm:  2px;
$border-radius:     4px;
$border-radius-lg:  8px;
$border-color:      $divider;
$box-shadow-sm:     0 1px 3px rgba(0, 0, 0, 0.12);
$box-shadow:        0 2px 6px rgba(0, 0, 0, 0.15);
$box-shadow-lg:     0 4px 12px rgba(0, 0, 0, 0.18);

// --- Bootstrap Overrides (declare BEFORE @import 'bootstrap') ---
$font-family-base:  'Roboto', sans-serif;
$border-radius:     4px;
$border-radius-sm:  2px;
$border-radius-lg:  8px;

// --- Z-index Scale ---
$z-dropdown:   1000;
$z-sticky:     1020;
$z-overlay:    1040;
$z-modal:      1050;
$z-tooltip:    1070;
```

---

## Integrating with Angular Material Theme

Pull color values from the Material theme so `_variables.scss` and the theme stay in sync:

```scss
// src/styles/theme.scss
@use '@angular/material' as mat;

$primary-palette: mat.define-palette(mat.$indigo-palette, 700);
$accent-palette:  mat.define-palette(mat.$pink-palette, A200);
$warn-palette:    mat.define-palette(mat.$red-palette);

$theme: mat.define-light-theme((
  color: (
    primary: $primary-palette,
    accent:  $accent-palette,
    warn:    $warn-palette,
  ),
  typography: mat.define-typography-config(
    $font-family: 'Roboto, sans-serif',
  ),
));

@include mat.all-component-themes($theme);

// Export palette values for use in _variables.scss
$primary: mat.get-color-from-palette($primary-palette, 700);
$accent:  mat.get-color-from-palette($accent-palette, A200);
$warn:    mat.get-color-from-palette($warn-palette, 500);
```

---

## Global styles.scss Import Order

Order matters — variables must be declared before Bootstrap imports them.

```scss
// src/styles/styles.scss

// 1. Project variables (overrides Bootstrap defaults)
@use 'variables' as *;

// 2. Bootstrap (reads the overridden variables)
@import 'bootstrap/scss/bootstrap';

// 3. Angular Material theme
@use 'theme';

// 4. Global component styles
@import 'mixins';

// Snackbar type variants (used by NotificationService)
.snack-success .mdc-snackbar__surface { background-color: $success !important; color: #fff !important; }
.snack-error   .mdc-snackbar__surface { background-color: $warn !important;    color: #fff !important; }
.snack-info    .mdc-snackbar__surface { background-color: $primary !important; color: #fff !important; }
.snack-warning .mdc-snackbar__surface { background-color: $accent !important;  color: #fff !important; }
```

---

## Component SCSS Convention

Every component SCSS file imports variables at the top:

```scss
// user-card.component.scss
@use 'src/styles/variables' as *;

.user-card {
  background: $surface;
  border-radius: $border-radius;
  padding: $spacing-md;
  box-shadow: $box-shadow-sm;

  &__name {
    font-size: $font-size-lg;
    font-weight: $font-weight-medium;
    color: $text-primary;
  }

  &__email {
    font-size: $font-size-sm;
    color: $text-secondary;
  }

  &__actions {
    margin-top: $spacing-sm;
    display: flex;
    gap: $spacing-sm;
  }
}
```

---

## Dark Mode

If the project supports dark mode, define a second set of overrides:

```scss
// styles/_variables-dark.scss
$surface:         #1e1e1e;
$background:      #121212;
$text-primary:    rgba(255, 255, 255, 0.87);
$text-secondary:  rgba(255, 255, 255, 0.54);
$divider:         rgba(255, 255, 255, 0.12);
```

Apply via a theme class on `<body>` and an Angular Material dark theme:
```typescript
// In a ThemeService
toggleDarkMode(isDark: boolean): void {
  document.body.classList.toggle('dark-theme', isDark);
}
```
