# Build and Configuration

---

## `next.config.ts`

```ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,

  // Next 16: opt into Cache Components
  cacheComponents: true,

  // Next 16: React Compiler (stable, not on by default)
  reactCompiler: true,

  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'cdn.example.com', pathname: '/images/**' },
    ],
    formats: ['image/avif', 'image/webp'],
    qualities: [50, 75, 90],
  },

  // Transpile workspace packages in a monorepo
  transpilePackages: ['@repo/ui'],

  // Next 16: top level, no longer under experimental
  turbopack: {
    rules: {
      '*.svg': { loaders: ['@svgr/webpack'], as: '*.js' },
    },
  },

  async redirects() {
    return [{ source: '/old-blog/:slug', destination: '/blog/:slug', permanent: true }]
  },

  async rewrites() {
    return [{ source: '/api/legacy/:path*', destination: 'https://legacy.example.com/:path*' }]
  },

  async headers() {
    return [{
      source: '/:path*',
      headers: [
        { key: 'X-Content-Type-Options', value: 'nosniff' },
        { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
      ],
    }]
  },
}

export default nextConfig
```

Static `redirects()` in config are cheaper than proxy logic — no per-request execution. Use the proxy only when the decision needs request data.

Next 16 supports native TypeScript config execution with `--experimental-next-config-strip-types`.

---

## Turbopack

Default bundler in Next 16 for both dev and build: roughly 2–5× faster production builds and up to 10× faster Fast Refresh.

```bash
next dev                   # Turbopack
next build                 # Turbopack
next dev --webpack         # opt out
next build --webpack       # opt out
```

Filesystem caching for dev, useful on large repos:

```ts
const nextConfig = {
  experimental: { turbopackFileSystemCacheForDev: true },
}
```

If a Babel config is present, Turbopack now enables Babel automatically rather than erroring.

Custom webpack config is the usual blocker for adopting Turbopack. Port loaders to `turbopack.rules` where possible; `--webpack` is the escape hatch while porting.

---

## Environment Variables

```
.env                  all environments, committed only if it holds no secrets
.env.local            local overrides, gitignored, ignored during `next test`
.env.development      loaded by `next dev`
.env.production       loaded by `next build` / `next start`
```

Precedence: `process.env` → `.env.$(NODE_ENV).local` → `.env.local` → `.env.$(NODE_ENV)` → `.env`.

```bash
DATABASE_URL=postgres://…             # server only
NEXT_PUBLIC_API_URL=https://api.example.com   # inlined into the client bundle
```

`NEXT_PUBLIC_` values are **inlined at build time**. Changing one requires a rebuild, not a restart — and the value is permanently public.

Validate at boot:

```ts
// lib/env.ts
import 'server-only'
import { z } from 'zod'

export const env = z.object({
  DATABASE_URL: z.string().url(),
  SESSION_SECRET: z.string().min(32),
  NODE_ENV: z.enum(['development', 'production', 'test']),
}).parse(process.env)
```

Import it in `next.config.ts` so an invalid environment fails the build rather than a request.

`serverRuntimeConfig` and `publicRuntimeConfig` were removed in Next 16.

Commit a `.env.example` listing every required key with placeholder values.

---

## TypeScript

```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "esnext"],
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

Next.js 16 requires TypeScript 5.1+.

`noUncheckedIndexedAccess` is worth the friction — it catches `arr[0]` being `undefined`, which is a real bug class in list rendering.

Never ship with:

```ts
// ❌ Hides real errors from every future reader
const nextConfig = {
  typescript: { ignoreBuildErrors: true },
  eslint: { ignoreDuringBuilds: true },
}
```

Typed routes:

```ts
const nextConfig = { typedRoutes: true }   // typedRoutes in Next 15+, experimental.typedRoutes before
```

---

## Linting

`next lint` was **removed in Next 16**, and `next build` no longer runs linting.

```bash
npx @next/codemod@canary next-lint-to-eslint-cli .
```

```js
// eslint.config.mjs — flat config (default in Next 16)
import { FlatCompat } from '@eslint/eslintrc'

const compat = new FlatCompat({ baseDirectory: import.meta.dirname })

export default [
  ...compat.extends('next/core-web-vitals', 'next/typescript'),
  {
    rules: {
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    },
  },
]
```

```json
// package.json
{
  "scripts": {
    "lint": "eslint .",
    "typecheck": "tsc --noEmit"
  }
}
```

Biome is a faster alternative that replaces both ESLint and Prettier.

---

## Output Modes

```ts
const nextConfig = {
  output: 'standalone',   // minimal server bundle for Docker
  // output: 'export',    // fully static HTML export
}
```

`standalone` traces only the files actually needed and writes `.next/standalone/`. See `references/deployment.md`.

`export` gives static HTML with no Node server. It disables Server Actions, route handlers, ISR, `next/image` optimization, proxy, and dynamic rendering — check the constraint list before choosing it.

---

## Bundle Analysis

```bash
npm install -D @next/bundle-analyzer
ANALYZE=true npm run build
```

```ts
import withBundleAnalyzer from '@next/bundle-analyzer'
export default withBundleAnalyzer({ enabled: process.env.ANALYZE === 'true' })(nextConfig)
```

Next 16.1 also ships an experimental built-in analyzer.

---

## Instrumentation

```ts
// instrumentation.ts
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    await import('./instrumentation.node')      // OpenTelemetry, Sentry
  }
}

export function onRequestError(err: unknown, request: Request, context: unknown) {
  // Catches server errors including RSC render failures
}
```

---

## Build Output

```
Route (app)                              Size     First Load JS
┌ ○ /                                    5.2 kB          92 kB
├ ● /blog/[slug]                         3.1 kB          89 kB
├ ◐ /dashboard                           8.4 kB         104 kB
└ ƒ /api/webhook                         0 B                0 B

○ Static   ● SSG   ◐ Partial Prerender   ƒ Dynamic
```

Next 16 also reports per-step build timings:

```
 ✓ Compiled successfully in 615ms
 ✓ Finished TypeScript in 1114ms
 ✓ Collecting page data in 208ms
 ✓ Generating static pages in 239ms
```

Read this table on every build. A route flipping from `○` to `ƒ` is the earliest signal that something started reading request data.

---

## Scripts

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:e2e": "playwright test",
    "analyze": "ANALYZE=true next build"
  }
}
```

CI gate: `typecheck && lint && test && build`, then e2e against the built app.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| `NEXT_PUBLIC_` change has no effect | Inlined at build time — rebuild required |
| Env var undefined in production | Not set on the host; `.env.local` is gitignored |
| `next lint` not found | Removed in Next 16 — run ESLint directly |
| Turbopack build fails | Custom webpack config — port to `turbopack.rules` or use `--webpack` |
| Type errors reach production | `ignoreBuildErrors: true` |
| Docker image is enormous | Not using `output: 'standalone'` |
| `output: 'export'` breaks features | Static export disables Actions, handlers, ISR, image optimization |
| Turbopack config warning | Moved to top level in Next 16 |
