# Monorepos and Turborepo

---

## Layout

```
├── apps/
│   ├── web/                 Next.js app
│   ├── admin/               Next.js app
│   └── docs/
├── packages/
│   ├── ui/                  shared components
│   ├── database/            Prisma client and schema
│   ├── config/              shared eslint/tsconfig/tailwind
│   └── types/               shared types
├── package.json
├── turbo.json
└── pnpm-workspace.yaml
```

```yaml
# pnpm-workspace.yaml
packages:
  - 'apps/*'
  - 'packages/*'
```

pnpm is the usual choice — its strict node_modules layout catches undeclared dependencies that npm and yarn silently allow, which is exactly the class of bug that bites in a monorepo.

---

## `turbo.json`

```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": ["**/.env.*local"],
  "globalEnv": ["NODE_ENV"],
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"],
      "env": ["DATABASE_URL", "NEXT_PUBLIC_*"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {
      "dependsOn": ["^lint"]
    },
    "typecheck": {
      "dependsOn": ["^build"],
      "outputs": []
    },
    "test": {
      "dependsOn": ["^build"],
      "outputs": ["coverage/**"]
    }
  }
}
```

- `dependsOn: ["^build"]` — build every dependency package first.
- `outputs` — what gets cached. Excluding `.next/cache/**` avoids caching the cache.
- `env` — **environment variables that affect the build must be declared here**, or Turbo will serve a cached build produced under different values. This is the single most common Turborepo bug: a stale build with the wrong `NEXT_PUBLIC_API_URL` baked in.
- `cache: false, persistent: true` for dev servers.

---

## Shared Packages

```json
// packages/ui/package.json
{
  "name": "@repo/ui",
  "version": "0.0.0",
  "private": true,
  "exports": {
    "./button": "./src/button.tsx",
    "./card": "./src/card.tsx"
  },
  "devDependencies": {
    "@repo/typescript-config": "workspace:*",
    "react": "^19.0.0"
  },
  "peerDependencies": {
    "react": "^19.0.0"
  }
}
```

Two decisions worth getting right:

**Ship source, not build output.** Next.js can transpile workspace TypeScript directly, so a build step per package is usually wasted time in dev. Point `exports` at `.tsx` source and let the app compile it.

**Granular export paths.** `"./button"` rather than a single barrel `"."`. A barrel file forces the bundler to pull the whole package graph to determine what is used, and it breaks tree-shaking for consumers.

```ts
// apps/web/next.config.ts
const nextConfig = {
  transpilePackages: ['@repo/ui', '@repo/database'],
}
```

React must be a `peerDependency` in shared packages. As a direct dependency it can resolve to a second copy, producing "invalid hook call" errors that look like anything but a version conflict.

---

## Shared Config

```json
// packages/typescript-config/nextjs.json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "extends": "./base.json",
  "compilerOptions": {
    "plugins": [{ "name": "next" }],
    "module": "esnext",
    "moduleResolution": "bundler",
    "jsx": "preserve",
    "noEmit": true
  }
}
```

```json
// apps/web/tsconfig.json
{
  "extends": "@repo/typescript-config/nextjs.json",
  "compilerOptions": { "paths": { "@/*": ["./*"] } },
  "include": ["**/*.ts", "**/*.tsx", "next-env.d.ts", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

Same pattern for ESLint, Tailwind, and Prettier — one package each, extended by every app.

---

## Server-Only Packages

A shared package touching the database must not be importable from a client component:

```ts
// packages/database/src/index.ts
import 'server-only'
import { PrismaClient } from '@prisma/client'

const globalForPrisma = global as unknown as { prisma?: PrismaClient }

export const db = globalForPrisma.prisma ?? new PrismaClient()
if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = db
```

The `globalThis` singleton matters in dev: hot reload otherwise creates a new `PrismaClient` per reload until the connection pool is exhausted.

---

## Commands

```bash
turbo build                                   # everything, respecting the graph
turbo build --filter=web                      # one app
turbo build --filter=web...                   # web and its dependencies
turbo build --filter=...@repo/ui              # everything depending on ui
turbo build --filter='[HEAD^1]'               # only what changed
turbo dev --filter=web --filter=@repo/ui      # dev servers for a subset
turbo build --dry-run                         # inspect the plan and cache keys
turbo build --graph                           # visualize the task graph
```

`--filter='[HEAD^1]'` in CI is the main payoff — untouched packages skip entirely.

---

## Remote Caching

```bash
npx turbo login
npx turbo link
```

Shares the build cache across the team and CI. A local build can hit a cache entry produced by CI and finish in seconds. Self-hostable if Vercel's remote cache is not an option.

`env` declarations in `turbo.json` become part of the cache key — get them wrong and remote caching amplifies the stale-build problem across the whole team.

---

## Prisma in a Monorepo

```json
// packages/database/package.json
{
  "name": "@repo/database",
  "scripts": {
    "generate": "prisma generate",
    "db:push": "prisma db push",
    "db:migrate": "prisma migrate dev"
  }
}
```

```json
// turbo.json
{
  "tasks": {
    "generate": { "cache": false },
    "build": { "dependsOn": ["^build", "generate"] }
  }
}
```

`prisma generate` writes into `node_modules`, so caching it produces confusing misses. Mark it `cache: false` and make `build` depend on it.

---

## CI

```yaml
name: CI
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 2 }        # needed for [HEAD^1] filtering
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm turbo lint typecheck test build --filter='[HEAD^1]'
        env:
          TURBO_TOKEN: ${{ secrets.TURBO_TOKEN }}
          TURBO_TEAM: ${{ vars.TURBO_TEAM }}
```

---

## Nx as an Alternative

Nx offers a richer plugin system, generators, and module-boundary enforcement via tags. Turborepo is simpler and closer to plain npm scripts.

Follow whichever the repo already uses. Migrating between them is a project, not a task.

---

## Microfrontends

Multiple Next.js apps composed under one domain, deployed independently. Vercel's `@vercel/microfrontends` and `microfrontends.json` handle path-based routing and a local proxy for development.

Real cost: shared layout duplication, cross-app navigation is a full page load, and version skew between apps. Worth it for independent team deploys at scale; overkill below that.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Stale build with wrong env values | Env var not declared in `turbo.json` `env` |
| `Module not found` for a workspace package | Missing `transpilePackages` |
| "Invalid hook call" | Two React copies — make React a peer dependency |
| Type errors only in CI | `dependsOn: ["^build"]` missing on `typecheck` |
| Prisma client not found | `generate` not wired into the build graph |
| Cache never hits | `outputs` misconfigured, or a non-deterministic build step |
| Connection pool exhausted in dev | No `globalThis` Prisma singleton |
| CI builds everything on every PR | No `--filter='[HEAD^1]'`, or `fetch-depth: 1` |
