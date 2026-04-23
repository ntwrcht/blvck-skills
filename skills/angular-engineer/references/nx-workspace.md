# NX Workspace for Angular

NX is a monorepo tool that enforces library boundaries, accelerates builds with caching,
and structures large Angular projects into maintainable slices.

## Table of Contents
1. Workspace Setup
2. Library Architecture (4-type model)
3. Generating Libraries & Applications
4. Project Tags & Boundary Enforcement
5. nx affected — build only what changed
6. Executors & Task Pipeline
7. Shared Configuration
8. Common Commands Reference

---

## 1. Workspace Setup

```bash
# Create new NX Angular workspace
npx create-nx-workspace@latest my-org --preset=angular-monorepo --appName=my-app

# Add NX to existing Angular CLI project
ng add @nx/angular

# Install NX globally (optional — npx works too)
npm install -g nx
```

Generated structure:
```
my-org/
├── apps/
│   └── my-app/               ← Angular application
│       ├── src/
│       └── project.json      ← app-specific NX config
├── libs/                     ← shared libraries
├── nx.json                   ← NX workspace config
├── tsconfig.base.json        ← base TS config (path aliases)
└── package.json
```

---

## 2. Library Architecture — 4-Type Model

Every library in NX follows one of four types. This makes the codebase predictable and
enforces clean dependency direction.

```
apps/
  my-app/                     ← Application — assembles features, no business logic

libs/
  feature/                    ← Feature libs — smart components, routing, pages
    user-list/
    user-detail/
  data-access/                ← Data libs — services, state, API calls, models
    users/
    auth/
  ui/                         ← UI libs — dumb/presentational components only
    user-card/
    shared-table/
  util/                       ← Utility libs — pure functions, pipes, validators, constants
    formatters/
    validators/
```

**Dependency rules:**
```
app → feature → data-access → util
app → feature → ui → util
app → ui → util
app → util

feature → feature ❌ (features don't import each other)
data-access → feature ❌
ui → data-access ❌ (UI is dumb — no services)
```

---

## 3. Generating Libraries & Applications

```bash
# Generate a feature library
nx g @nx/angular:library feature-user-list \
  --directory=libs/feature \
  --standalone \
  --prefix=myapp \
  --tags=type:feature,scope:users

# Generate a data-access library
nx g @nx/angular:library data-access-users \
  --directory=libs/data-access \
  --standalone \
  --prefix=myapp \
  --tags=type:data-access,scope:users

# Generate a UI library
nx g @nx/angular:library ui-user-card \
  --directory=libs/ui \
  --standalone \
  --prefix=myapp \
  --tags=type:ui,scope:users

# Generate a utility library
nx g @nx/angular:library util-formatters \
  --directory=libs/util \
  --standalone \
  --prefix=myapp \
  --tags=type:util,scope:shared

# Add a second app to the workspace
nx g @nx/angular:application admin-app \
  --directory=apps/admin \
  --standalone \
  --routing
```

**Import path aliases** — NX auto-configures `tsconfig.base.json`:
```typescript
// tsconfig.base.json (auto-generated)
{
  "compilerOptions": {
    "paths": {
      "@my-org/feature-user-list": ["libs/feature/user-list/src/index.ts"],
      "@my-org/data-access-users": ["libs/data-access/users/src/index.ts"],
      "@my-org/ui-user-card": ["libs/ui/user-card/src/index.ts"],
      "@my-org/util-formatters": ["libs/util/formatters/src/index.ts"]
    }
  }
}
```

```typescript
// Usage in app or other libs — clean, no relative imports
import { UserListComponent } from '@my-org/feature-user-list';
import { UserService } from '@my-org/data-access-users';
import { UserCardComponent } from '@my-org/ui-user-card';
```

**Always export from `index.ts`** (the library's public API):
```typescript
// libs/ui/user-card/src/index.ts
export { UserCardComponent } from './lib/user-card/user-card.component';
export { UserAvatarComponent } from './lib/user-avatar/user-avatar.component';
// Only export what consumers should use — keep internals private
```

---

## 4. Project Tags & Boundary Enforcement

Tags enforce architectural rules at lint time — violations fail CI before they reach review.

```json
// project.json — tag each library
{
  "tags": ["type:feature", "scope:users"]
}
```

```json
// .eslintrc.json (root) — define what can import what
{
  "rules": {
    "@nx/enforce-module-boundaries": [
      "error",
      {
        "enforceBuildableLibDependency": true,
        "depConstraints": [
          {
            "sourceTag": "type:feature",
            "onlyDependOnLibsWithTags": ["type:feature", "type:data-access", "type:ui", "type:util"]
          },
          {
            "sourceTag": "type:data-access",
            "onlyDependOnLibsWithTags": ["type:data-access", "type:util"]
          },
          {
            "sourceTag": "type:ui",
            "onlyDependOnLibsWithTags": ["type:ui", "type:util"]
          },
          {
            "sourceTag": "type:util",
            "onlyDependOnLibsWithTags": ["type:util"]
          },
          // Scope rules — prevent cross-domain leaks
          {
            "sourceTag": "scope:users",
            "onlyDependOnLibsWithTags": ["scope:users", "scope:shared"]
          },
          {
            "sourceTag": "scope:auth",
            "onlyDependOnLibsWithTags": ["scope:auth", "scope:shared"]
          }
        ]
      }
    ]
  }
}
```

Check boundaries:
```bash
nx lint my-app                    # lint one project
nx run-many --target=lint        # lint everything
```

---

## 5. nx affected — Build Only What Changed

NX tracks which files changed since the last successful build and only rebuilds affected projects.
This is the biggest time-saver in a large monorepo.

```bash
# Build only apps affected by changes on this branch
nx affected --target=build

# Test only what changed (compared to main branch)
nx affected --target=test --base=main --head=HEAD

# Lint only affected projects
nx affected --target=lint

# See which projects are affected (dry run)
nx affected --target=build --dry-run

# Graph — visualize what's affected
nx affected:graph
```

**How it works:** NX builds a dependency graph. When `libs/ui/user-card` changes, it knows
that `feature/user-list` imports it, and `apps/my-app` imports `feature/user-list` — so all
three are rebuilt/tested. Unrelated libs are skipped.

**Configure the base branch in CI:**
```yaml
- name: Run affected tests
  run: nx affected --target=test --base=origin/main --head=HEAD
```

---

## 6. Executors & Task Pipeline

### Task pipeline — run tasks in the right order

```json
// nx.json
{
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"],    // build all deps first (^ means dependencies)
      "cache": true
    },
    "test": {
      "dependsOn": ["build"],
      "cache": true
    },
    "lint": {
      "cache": true
    }
  }
}
```

### Parallel task execution

```bash
# Run build, test, lint in parallel across all projects
nx run-many --target=build,test,lint --parallel=3

# Run a specific target for specific projects
nx run-many --target=test --projects=feature-user-list,data-access-users
```

### Remote caching (NX Cloud)

```bash
# Connect to NX Cloud for shared caching across team members and CI
npx nx connect-to-nx-cloud
```

Once connected, a task that ran on one developer's machine or CI won't re-run on another —
the result is pulled from the cloud cache. Significant CI time savings for large workspaces.

---

## 7. Shared Configuration

### Shared `tsconfig.base.json`

All projects extend from root:
```json
// apps/my-app/tsconfig.json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "../../dist/out-tsc",
    "types": ["jasmine"]
  }
}
```

### Shared ESLint config

```json
// .eslintrc.json (root) — inherited by all projects
{
  "root": true,
  "ignorePatterns": ["**/*"],
  "plugins": ["@nx"],
  "overrides": [
    {
      "files": ["*.ts"],
      "extends": [
        "plugin:@nx/angular",
        "plugin:@angular-eslint/template/process-inline-templates"
      ],
      "rules": {
        "@angular-eslint/directive-selector": ["error", { "type": "attribute", "prefix": "myapp", "style": "camelCase" }],
        "@angular-eslint/component-selector": ["error", { "type": "element", "prefix": "myapp", "style": "kebab-case" }]
      }
    }
  ]
}
```

### Shared Jest config (if using Jest instead of Karma)

```typescript
// jest.preset.js (root)
const nxPreset = require('@nx/jest/preset');
module.exports = {
  ...nxPreset,
  coverageReporters: ['html', 'lcov'],
};

// libs/feature/user-list/jest.config.ts
export default {
  displayName: 'feature-user-list',
  preset: '../../../jest.preset.js',
  setupFilesAfterFramework: ['<rootDir>/src/test-setup.ts'],
  coverageDirectory: '../../../coverage/libs/feature/user-list',
};
```

---

## 8. Common Commands Reference

```bash
# Generate
nx g @nx/angular:library <name>         # create library
nx g @nx/angular:component <name>       # generate component in a library
nx g @nx/angular:service <name>         # generate service

# Build
nx build my-app                         # build one app
nx build my-app --configuration=production
nx run-many --target=build              # build all

# Test
nx test my-app                          # test one project
nx affected --target=test               # test only changed

# Lint
nx lint my-app
nx run-many --target=lint

# Serve
nx serve my-app

# Graph
nx graph                                # interactive dependency graph
nx affected:graph                       # graph of affected projects

# Cache
nx reset                                # clear local NX cache
nx show project my-app                  # show project configuration

# Update
nx migrate latest                       # update NX and Angular together
nx migrate --run-migrations             # run pending migrations after update
```

**Project graph** — always check before adding a new dependency:
```bash
nx graph
```
If the graph shows an unexpected edge (a lib importing something it shouldn't), that's a
boundary violation — fix it before it spreads.
