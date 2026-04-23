# Build Tools & CLI Reference (Angular 17+)

## Table of Contents
1. Application Builder (esbuild) — Default in ng17+
2. angular.json Key Configurations
3. Environment Configuration
4. CI/CD Optimization
5. Bundle Analysis
6. Angular CLI Essentials

---

## 1. Application Builder (esbuild) — Default in ng17+

Angular 17+ uses **esbuild** via `@angular-devkit/build-angular:application` by default.
This replaces the old Webpack-based `browser` builder — **do not use the old builder for new projects**.

```json
// angular.json — correct builder for ng17+
"architect": {
  "build": {
    "builder": "@angular-devkit/build-angular:application",
    "options": {
      "outputPath": "dist/my-app",
      "index": "src/index.html",
      "browser": "src/main.ts",
      "polyfills": ["zone.js"],
      "tsConfig": "tsconfig.app.json",
      "assets": ["src/favicon.ico", "src/assets"],
      "styles": ["src/styles.scss"],
      "scripts": []
    }
  }
}
```

**Speed difference:** esbuild is 10–100x faster than Webpack for cold builds.
Incremental rebuilds drop from seconds to milliseconds.

---

## 2. angular.json Key Configurations

### Production build optimizations

```json
"configurations": {
  "production": {
    "budgets": [
      {
        "type": "initial",
        "maximumWarning": "500kb",
        "maximumError": "1mb"
      },
      {
        "type": "anyComponentStyle",
        "maximumWarning": "4kb",
        "maximumError": "8kb"
      }
    ],
    "outputHashing": "all",
    "optimization": true,
    "sourceMap": false,
    "namedChunks": false,
    "aot": true,
    "extractLicenses": true
  },
  "development": {
    "optimization": false,
    "sourceMap": true,
    "namedChunks": true
  }
}
```

**Budget rules:**
- Always set `initial` budget — catches bundle bloat before it reaches production
- `anyComponentStyle` at 4kb warning — forces lean component SCSS
- Adjust `maximumError` if you knowingly include heavy libraries (e.g. chart libraries)

### Lazy chunk naming (easier debugging)

```json
"namedChunks": true   // development only — human-readable chunk names
```

---

## 3. Environment Configuration

ng17+ uses `fileReplacements` — no more `environment.ts` magic imports.

```
src/
├── environments/
│   ├── environment.ts          # development (default)
│   └── environment.prod.ts     # production
```

```typescript
// src/environments/environment.ts
export const environment = {
  production: false,
  apiUrl: 'http://localhost:3000/api',
  wsUrl: 'ws://localhost:3000',
  featureFlags: {
    newDashboard: true,
  },
};
```

```json
// angular.json — fileReplacements
"production": {
  "fileReplacements": [
    {
      "replace": "src/environments/environment.ts",
      "with": "src/environments/environment.prod.ts"
    }
  ]
}
```

Never hardcode API URLs in services — always use `environment.apiUrl`.

---

## 4. CI/CD Optimization

### Faster builds in CI

```bash
# Production build with stats (for bundle analysis)
ng build --configuration=production --stats-json

# Skip source maps in CI (faster)
ng build --configuration=production --no-source-map

# Increase Node.js memory for large projects
NODE_OPTIONS=--max-old-space-size=4096 ng build --configuration=production
```

### Cache node_modules in CI (GitHub Actions example)

```yaml
- name: Cache node modules
  uses: actions/cache@v3
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: ${{ runner.os }}-node-

- name: Install dependencies
  run: npm ci   # always use ci, not install, in CI pipelines

- name: Build
  run: npm run build:prod
```

### package.json scripts

```json
"scripts": {
  "start": "ng serve",
  "build": "ng build",
  "build:prod": "ng build --configuration=production",
  "build:stats": "ng build --configuration=production --stats-json",
  "analyze": "npm run build:stats && npx esbuild-bundle-analyzer dist/my-app/browser/stats.json",
  "test": "ng test --watch=false --browsers=ChromeHeadless",
  "test:ci": "ng test --watch=false --browsers=ChromeHeadless --code-coverage",
  "lint": "ng lint"
}
```

---

## 5. Bundle Analysis

Angular 17+ uses esbuild, not Webpack — `webpack-bundle-analyzer` does not work.
Use the Angular-native approach instead:

```bash
# Generate stats file
ng build --configuration=production --stats-json

# Option A — esbuild-bundle-analyzer (recommended for ng17+)
npx esbuild-bundle-analyzer dist/my-app/browser/stats.json

# Option B — source-map-explorer (works with any bundler)
npm install --save-dev source-map-explorer
ng build --configuration=production --source-map
npx source-map-explorer 'dist/my-app/browser/*.js'
```

```json
// package.json
{
  "scripts": {
    "build:stats": "ng build --configuration=production --stats-json",
    "analyze": "npm run build:stats && npx esbuild-bundle-analyzer dist/my-app/browser/stats.json"
  }
}
```

**What to look for:**
- Duplicate libraries (lodash imported twice via different paths)
- Unexpectedly large lazy chunks (a route that's too eager)
- Third-party libraries over 50KB — look for lighter alternatives
- Angular Material modules imported fully when only a subset is used

**Quick wins:**
- Import only what you use from RxJS — modern bundlers tree-shake well but explicit imports help
- Use `@defer` blocks (ng17+) for heavy components below the fold
- Tree-shake Angular Material: import only the component modules you use
- Replace `moment` with `date-fns` (fully tree-shakeable)

---

## 6. Angular CLI Essentials

### Generate commands

```bash
# Component (standalone by default in ng17+)
ng generate component features/users/components/user-card --skip-tests=false

# Service (provided in root by default)
ng generate service core/services/auth

# Guard (functional by default in ng16+)
ng generate guard core/guards/auth --implements CanActivate

# Pipe
ng generate pipe shared/pipes/truncate

# Interface / model
ng generate interface core/models/user

# Module (if still using NgModule)
ng generate module features/users --routing
```

### Useful flags

```bash
--dry-run       # Preview what will be generated without creating files
--skip-tests    # Skip spec file generation (avoid — always write tests)
--flat          # Don't create a subdirectory
--inline-style  # Put styles inline in the component file
--standalone    # Force standalone component (default in ng17+)
```

### ng update — keep Angular current

```bash
# Check what can be updated
ng update

# Update Angular core and CLI together
ng update @angular/core @angular/cli

# Update all Angular packages
ng update @angular/core @angular/cli @angular/material @ngrx/store
```

Always run `ng update` one major version at a time. Never skip versions.

### Workspace-level schematics defaults

Set defaults in `angular.json` to enforce conventions:

```json
"schematics": {
  "@schematics/angular:component": {
    "style": "scss",
    "changeDetection": "OnPush",
    "standalone": true
  },
  "@schematics/angular:directive": {
    "standalone": true
  },
  "@schematics/angular:pipe": {
    "standalone": true
  }
}
```

After this, every `ng generate component` automatically uses SCSS, OnPush, and standalone — no flags needed.
