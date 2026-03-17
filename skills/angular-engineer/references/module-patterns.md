# NgModule Patterns (Angular 14–15)

Use these patterns for NgModule-based projects (ng14–15). For ng15+ standalone projects,
use `standalone: true` components with `bootstrapApplication()` and route-level providers instead.

---

## AppModule

```typescript
// src/app/app.module.ts
@NgModule({
  declarations: [AppComponent],
  imports: [
    BrowserModule,
    BrowserAnimationsModule,
    HttpClientModule,
    CoreModule,
    AppRoutingModule,
  ],
  bootstrap: [AppComponent],
})
export class AppModule {}
```

---

## CoreModule (with double-import guard)

Import only once in `AppModule`. The guard throws at runtime if it's imported anywhere else.

```typescript
// src/app/core/core.module.ts
@NgModule({
  imports: [CommonModule, HttpClientModule],
  providers: [
    { provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor, multi: true },
    { provide: HTTP_INTERCEPTORS, useClass: ErrorInterceptor, multi: true },
  ],
})
export class CoreModule {
  constructor(@Optional() @SkipSelf() parentModule: CoreModule) {
    if (parentModule) {
      throw new Error('CoreModule is already loaded. Import it only in AppModule.');
    }
  }
}
```

---

## SharedModule

Import in every feature module that needs shared UI. Re-exports the modules most features need.

```typescript
// src/app/shared/shared.module.ts
@NgModule({
  declarations: [
    LoadingSpinnerComponent,
    ConfirmDialogComponent,
    // add shared components here
  ],
  imports: [CommonModule, ReactiveFormsModule, MaterialModule],
  exports: [
    CommonModule,
    ReactiveFormsModule,
    MaterialModule,
    LoadingSpinnerComponent,
    ConfirmDialogComponent,
  ],
})
export class SharedModule {}
```

---

## MaterialModule

One shared module to centralize all Angular Material imports/exports.

```typescript
// src/app/shared/material.module.ts
const MATERIAL_MODULES = [
  MatButtonModule, MatTableModule, MatPaginatorModule,
  MatSortModule, MatFormFieldModule, MatInputModule,
  MatDialogModule, MatSnackBarModule, MatIconModule,
  MatSelectModule, MatDatepickerModule, MatNativeDateModule,
  MatProgressSpinnerModule, MatChipsModule, MatAutocompleteModule,
  // add more as needed
];

@NgModule({
  imports: MATERIAL_MODULES,
  exports: MATERIAL_MODULES,
})
export class MaterialModule {}
```

---

## Feature Module (lazy-loaded)

Each business domain gets its own module, loaded lazily via the router.

```typescript
// src/app/features/users/users.module.ts
@NgModule({
  declarations: [UsersPageComponent, UserFormComponent, UserCardComponent],
  imports: [SharedModule, UsersRoutingModule],
  providers: [UserService],   // scoped to this module — not a singleton
})
export class UsersModule {}

// src/app/features/users/users-routing.module.ts
const routes: Routes = [
  { path: '', component: UsersPageComponent },
  { path: ':id', component: UserFormComponent },
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule],
})
export class UsersRoutingModule {}
```

---

## AppRoutingModule (lazy loading all features)

```typescript
// src/app/app-routing.module.ts
const routes: Routes = [
  {
    path: 'users',
    loadChildren: () =>
      import('./features/users/users.module').then(m => m.UsersModule),
  },
  {
    path: 'dashboard',
    loadChildren: () =>
      import('./features/dashboard/dashboard.module').then(m => m.DashboardModule),
  },
  { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
  { path: '**', redirectTo: 'dashboard' },
];

@NgModule({
  imports: [RouterModule.forRoot(routes, {
    preloadingStrategy: PreloadAllModules,  // preload lazy chunks in background after startup
  })],
  exports: [RouterModule],
})
export class AppRoutingModule {}
```
