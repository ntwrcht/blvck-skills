# NgModule Patterns (Angular 14–15)

Use these patterns for NgModule-based projects (ng14–15). For ng15+ standalone projects,
use `standalone: true` components with `bootstrapApplication()` and route-level providers instead.

## Table of Contents
- [AppModule](#appmodule)
- [CoreModule (with double-import guard)](#coremodule-with-double-import-guard)
- [SharedModule](#sharedmodule)
- [MaterialModule](#materialmodule)
- [Feature Module (lazy-loaded)](#feature-module-lazy-loaded)
- [AppRoutingModule (lazy loading all features)](#approutingmodule-lazy-loading-all-features)
- [`forRoot()` / `forChild()` Pattern](#forroot--forchild-pattern)
- [Multi-provider InjectionTokens](#multi-provider-injectiontokens)
- [Dynamic Component Creation (ng14+)](#dynamic-component-creation-ng14)

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

---

## `forRoot()` / `forChild()` Pattern

Use `ModuleWithProviders<T>` to let a module accept configuration at import time.
`forRoot()` registers singleton providers in the root injector; `forChild()` registers
no providers (avoids duplicating singletons in lazy modules).

```typescript
// src/app/logging/logging.module.ts
export interface LoggingConfig { apiUrl: string; }
export const LOGGING_CONFIG = new InjectionToken<LoggingConfig>('LOGGING_CONFIG');

@NgModule({})
export class LoggingModule {
  static forRoot(config: LoggingConfig): ModuleWithProviders<LoggingModule> {
    return {
      ngModule: LoggingModule,
      providers: [{ provide: LOGGING_CONFIG, useValue: config }, LoggingService],
    };
  }
  static forChild(): ModuleWithProviders<LoggingModule> {
    return { ngModule: LoggingModule };  // no providers — reuses root singleton
  }
}

// src/app/app.module.ts  — registers config once
// imports: [ LoggingModule.forRoot({ apiUrl: 'https://logs.example.com' }) ]

// src/app/features/users/users.module.ts  — consumes without re-providing
// imports: [ LoggingModule.forChild() ]
```

```typescript
// src/app/logging/logging.service.ts
@Injectable()
export class LoggingService {
  constructor(@Inject(LOGGING_CONFIG) private config: LoggingConfig) {}
  log(message: string): void {
    fetch(`${this.config.apiUrl}/events`, { method: 'POST', body: JSON.stringify({ message }) });
  }
}
```

---

## Multi-provider InjectionTokens

`multi: true` lets multiple providers contribute to the same token. The injector
collects all values into an array. Used by Angular itself for `APP_INITIALIZER` and
`HTTP_INTERCEPTORS`; apply the same pattern for your own plugin registries.

```typescript
// src/app/core/plugin.token.ts
export interface AppPlugin { name: string; initialize(): void; }
export const APP_PLUGINS = new InjectionToken<AppPlugin[]>('APP_PLUGINS');
```

```typescript
// src/app/core/core.module.ts  — multiple providers for the same token
providers: [
  { provide: APP_PLUGINS, useClass: AnalyticsPlugin,   multi: true },
  { provide: APP_PLUGINS, useClass: ChatPlugin,        multi: true },
  { provide: APP_PLUGINS, useClass: FeatureFlagPlugin, multi: true },
]
```

```typescript
// src/app/core/plugin-runner.service.ts
@Injectable({ providedIn: 'root' })
export class PluginRunnerService {
  constructor(@Inject(APP_PLUGINS) private plugins: AppPlugin[]) {}
  initializeAll(): void { this.plugins.forEach(p => p.initialize()); }
}
```

---

## Dynamic Component Creation (ng14+)

`ViewContainerRef.createComponent()` replaces the deprecated `ComponentFactoryResolver`.
Pass the class directly. Use `componentRef.setInput()` (ng14+) to bind inputs; call
`componentRef.destroy()` for cleanup.

```typescript
// src/app/shared/dynamic-host.directive.ts
@Directive({ selector: '[dynamicHost]' })
export class DynamicHostDirective {
  constructor(public viewContainerRef: ViewContainerRef) {}
}
```

```typescript
// src/app/shell/banner.component.ts
@Component({
  template: `<ng-template dynamicHost></ng-template>`,
})
export class BannerComponent implements OnDestroy {
  @ViewChild(DynamicHostDirective, { static: true })
  host!: DynamicHostDirective;

  private componentRef?: ComponentRef<unknown>;

  load(type: 'info' | 'error'): void {
    const component = type === 'info' ? InfoBannerComponent : ErrorBannerComponent;
    const vcr = this.host.viewContainerRef;
    vcr.clear();
    this.componentRef = vcr.createComponent(component);
    this.componentRef.setInput('message', 'Something happened');
    this.componentRef.setInput('dismissible', true);
  }

  ngOnDestroy(): void {
    this.componentRef?.destroy();
  }
}
```
