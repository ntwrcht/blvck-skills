---
name: next-engineer
description: "Builds, modifies, reviews, and debugs Next.js applications using project conventions, App Router patterns, Server Components, caching and rendering strategies, Server Actions, testing, and deployment guidance. Use when working on Next.js routes, layouts, data fetching, forms, auth, proxy or middleware, route handlers, migrations, performance, security, or full-stack React architecture."
---

# Next Engineer

Guide Next.js code work with senior engineering judgment: read the project first, choose version-appropriate patterns, keep the server/client boundary deliberate, and preserve local conventions.

## When to Use

Use this skill for Next.js application work: routes, layouts, Server and Client Components, data fetching, caching and revalidation, Server Actions, route handlers, proxy/middleware, forms, auth, metadata, SSR and streaming, monorepos, migrations, tests, reviews, debugging, and full-stack React architecture decisions.

Use a narrower skill when the request is mainly about generic debugging, security review, analytics, TDD workflow, or stakeholder communication and Next.js is only incidental. Use `angular-engineer` for Angular work — the two do not overlap.

Do not use this skill for Vercel platform behavior. When the Vercel plugin's skills (`vercel:nextjs` and its siblings) are installed, defer to them for deployment configuration, CDN and platform caching, firewall, storage, and AI SDK questions, and keep this skill for application code and project conventions.

## Artifacts

- Produces: code changes
- Consumes: stories at the `story` key path (if present) — see `references/artifact-paths.md` (default `docs/stories/<slug>.md`), `.context/project.md`, `.context/engineering.md`, `.context/git-workflow.md`, `.context/security.md`, `.context/learning.md`, `.context/adr/`

## Core Rule

Prefer the project's existing Next.js version, router (App or Pages), caching model, data layer, styling system, component library, state approach, and test runner over generic Next.js examples.

## Quick Path

Answer conceptual and architecture questions directly as prose with tradeoffs, and give explanations, single-line fixes, or small snippets inline. Do not run the full project-context workflow unless you are generating, modifying, reviewing, or debugging project code.

## Workflow

1. Inspect local context before changing code. Read `.context/INDEX.md` when present, then load relevant domain files such as `.context/project.md`, `.context/engineering.md`, `.context/git-workflow.md`, `.context/security.md`, `.context/learning.md`, and `.context/adr/`. If context is missing and project code changes are needed, follow `references/project-context.md`.
2. Confirm the Next.js version, router, and caching model from context, `package.json`, `next.config.*`, and whether `app/` or `pages/` holds the routes, before choosing APIs.
3. Check nearby code for naming, folder structure, shared UI, styling tokens, data-access helpers, and test style.
4. Load only the reference files needed for the task from the Reference Map.
5. Make the smallest coherent change, including tests when behavior changes.
6. Validate with the repo's focused test, lint, build, or typecheck command when practical.

## Engineering Defaults

- Keep components Server Components by default; add `'use client'` only at the leaf that needs interactivity, browser APIs, or hooks, and pass server data down as props.
- Put every secret, ORM call, and API key behind a server-only module (`import 'server-only'`) and a data-access layer that checks the session on each read.
- Treat Server Actions and route handlers as public endpoints: authorize and validate every input, never trust a hidden form field or a client-supplied id.
- Make caching explicit: read `next.config.*` for `cacheComponents` before assuming a model, then push dynamic access down the tree and wrap it in `<Suspense>` so the static shell streams first.
- Keep TypeScript strict: avoid `any`, unsafe casts, and nullable gaps unless they are explicitly justified.
- Use `next/image`, `next/font`, and `next/link` over raw `<img>`, webfont `@import`, and `<a>` for internal routes.
- Write or update tests for behavior changes. Query stable selectors such as `data-testid` where the project supports them.

## Version Guide

| Version | Default shape | Common APIs |
|---|---|---|
| Next 13.4-14 | App Router stable, Pages Router still common | `fetch` cache options, `revalidatePath`/`revalidateTag`, Server Actions, sync `params` and `cookies()` |
| Next 15 | App Router default, React 19 | async `params`/`searchParams`/`cookies()`/`headers()`, uncached `fetch` by default, `after()` |
| Next 16 | Cache Components and PPR | `'use cache'`, `cacheLife`, `cacheTag`, `updateTag`, `refresh`, `proxy.ts`, Turbopack default, React Compiler |
| Next 16.1+ | same model, refined | Turbopack filesystem caching, incremental prefetching, `'use cache: remote'` and `'use cache: private'` |

Ask before defaulting when the Next.js version or router is unclear and the choice affects generated code.

## Output Shape

- Small fix: changed code plus one sentence explaining the decision.
- New feature/route: the route files, server/client split, data access, tests, and a short decision note.
- Review: findings first with file and line references; load `references/code-review.md` for full PR reviews.

## Reference Map

- `references/project-context.md`: missing or stale `.context/` domain files or provider stubs.
- `references/app-router.md`: routes, layouts, route groups, dynamic and catch-all segments, parallel and intercepting routes, navigation.
- `references/server-components.md`: the server/client boundary, composition, serialization, `server-only`.
- `references/data-fetching.md`: fetching in Server Components, the data-access layer, parallel and sequential loads, streaming.
- `references/caching-revalidation.md`: Cache Components and `'use cache'`, the legacy four-cache model, `cacheLife`, `cacheTag`, `updateTag`, `revalidateTag`, ISR.
- `references/rendering-strategies.md`: static, dynamic, ISR, PPR, streaming, `<Suspense>`, route segment config.
- `references/server-actions.md`: mutations, `useActionState`, validation, authorization, redirects, optimistic updates.
- `references/route-handlers.md`: `route.ts`, REST and webhooks, streaming responses, runtime and CORS.
- `references/proxy-middleware.md`: `proxy.ts` and legacy `middleware.ts`, matchers, rewrites, redirects, optimistic auth.
- `references/forms-patterns.md`: progressive-enhancement forms, React Hook Form, Zod, `useFormStatus`, file upload.
- `references/state-management.md`: URL state, server state, Zustand, context, TanStack Query, and when to use which.
- `references/auth-patterns.md`: sessions, cookies, the DAL, DTOs, role checks, NextAuth/Clerk/Better Auth integration.
- `references/design-system.md`: Tailwind, shadcn/ui, CSS Modules, design tokens, dark mode, fonts.
- `references/a11y.md`: semantics, focus management across navigation, ARIA, keyboard, a11y tests.
- `references/testing.md`: Vitest/Jest, React Testing Library, testing Server Components and Server Actions, mocking.
- `references/e2e-testing.md`: Playwright, page objects, network mocking, auth state reuse, CI.
- `references/performance.md`: Core Web Vitals, `next/image`, `next/font`, `dynamic()`, bundle analysis, prefetch tuning.
- `references/metadata-seo.md`: the Metadata API, `generateMetadata`, sitemaps, robots, OG images, structured data.
- `references/security-patterns.md`: XSS, `dangerouslySetInnerHTML`, env-var leakage, CSRF, CSP, open redirects, taint APIs.
- `references/error-handling.md`: `error.tsx`, `not-found.tsx`, `global-error.tsx`, action errors, logging.
- `references/pages-router.md`: `getServerSideProps`, `getStaticProps`, `_app`, `_document`, API routes, hybrid apps.
- `references/upgrade-migration.md`: version upgrades, codemods, Pages-to-App migration, Cache Components adoption.
- `references/monorepo-turborepo.md`: Turborepo pipelines, workspace packages, `transpilePackages`, shared config.
- `references/build-config.md`: `next.config.ts`, Turbopack, env vars, output modes, bundle analyzer, CI.
- `references/deployment.md`: Vercel, self-hosting, Docker, standalone output, ISR at scale, runtime choice, observability.
- `references/git-workflow.md`: branch names, commits, changelog, PR descriptions.

## Next Step

Do not treat a change as done until `next build` succeeds and the project's test suite passes on it; for a visible UI change, until the user has seen it running.

- **If approved:** hand off to `tdd` when the change needs behavior tests it does not have, to `scrutinize` for an independent review of the diff, or to `security-audit` when it touches Server Actions, route handlers, auth, proxy matchers, or rendering of user input. For a full PR review of Next.js code, load `references/code-review.md` here instead of switching skills.
- **If not approved:** revise in place. When a failure's cause is not obvious from the build or test output, escalate to `debug` rather than guessing at fixes.
