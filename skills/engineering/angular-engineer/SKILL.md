---
name: angular-engineer
description: "Build, modify, review, and debug Angular applications using project conventions, modern Angular patterns, RxJS, Signals, testing, SSR, and Nx guidance. Use when working on Angular components, services, routing, forms, guards, migrations, performance, security, or frontend architecture."
---

# Angular Engineer

Guide Angular code work with senior engineering judgment: read the project first, choose version-appropriate patterns, keep changes testable, and preserve local conventions.

## When to Use

Use this skill for Angular application work: components, services, routes, guards, forms, state, RxJS streams, Signals, SSR, Nx workspaces, migrations, tests, reviews, debugging, and frontend architecture decisions.

Use a narrower skill when the request is mainly about generic debugging, security review, analytics, TDD workflow, or stakeholder communication and Angular is only incidental.

## Core Rule

Prefer the project’s existing Angular version, module style, shared components, design tokens, HTTP layer, state pattern, and test runner over generic Angular examples.

## Quick Path

Answer directly for conceptual questions, explanations, single-line fixes, or small snippets. Do not run the full project-context workflow unless you are generating, modifying, reviewing, or debugging project code.

## Workflow

1. Inspect local context before changing code. Read `.context/INDEX.md` when present, then load relevant domain files such as `.context/project.md`, `.context/engineering.md`, `.context/git-workflow.md`, `.context/security.md`, `.context/learning.md`, and `.context/adr/`. If context is missing and project code changes are needed, follow `references/project-context.md`.
2. Confirm Angular version and module style from context, `package.json`, `angular.json`, or source layout before choosing APIs.
3. Check nearby code for naming, folder structure, shared UI, design tokens, HTTP wrappers, state services, and test style.
4. Load only the reference files needed for the task from the Reference Map.
5. Make the smallest coherent change, including tests when behavior changes.
6. Validate with the repo’s focused test, lint, build, or typecheck command when practical.

## Engineering Defaults

- Prefer standalone components and `inject()` in Angular 17+ projects; respect NgModule patterns in Angular 14-16 codebases.
- Use `ChangeDetectionStrategy.OnPush` for components unless the existing feature has a documented reason not to.
- Keep TypeScript strict: avoid `any`, unsafe casts, and nullable gaps unless they are explicitly justified.
- Keep templates cheap: use `async` pipe, `trackBy` or `track`, and avoid calling non-trivial methods from templates.
- Use existing shared components, design tokens, and API abstractions before adding new ones.
- Use Signals for synchronous local or feature state in modern Angular; use RxJS for async composition; use NgRx only when the project already does or the state complexity warrants it.
- Write or update specs for behavior changes. Query stable selectors such as `data-testid` where the project supports them.

## Version Guide

| Version | Default shape | Common APIs |
|---|---|---|
| Angular 14-15 | NgModule-first | constructor DI, declarations, classic structural directives |
| Angular 15-16 | standalone opt-in | standalone components, `inject()`, early Signals |
| Angular 17+ | standalone-first | built-in control flow, Signals, `input()`/`output()` where established |
| Angular 18+ | standalone-first | zoneless options, modern signal utilities, SSR route render modes |

Ask before defaulting when the Angular version or module style is unclear and the choice affects generated code.

## Output Shape

- Small fix: changed code plus one sentence explaining the decision.
- New feature/component: spec, implementation, template, styles, and a short decision note.
- Architecture or conceptual answer: direct prose with tradeoffs.
- Review: findings first with file and line references; load `references/code-review.md` for full PR reviews.

## Reference Map

- `references/project-context.md`: missing or stale `.context/` domain files or provider stubs.
- `references/module-patterns.md`: NgModule, AppModule, CoreModule, SharedModule, Angular 14-16 projects.
- `references/signals-patterns.md`: Signals, `computed`, `effect`, `input`, `output`, `model`, `toSignal`.
- `references/rxjs-patterns.md`: RxJS operators, stream composition, multicasting, unsubscribe strategy.
- `references/state-management.md`: choosing Signals, BehaviorSubject services, RxJS, Angular Query, or NgRx.
- `references/http-layer.md`: HTTP abstractions, interceptors, retry, loading state, upload.
- `references/forms-patterns.md`: reactive forms, validators, FormArray, ControlValueAccessor.
- `references/routing-patterns.md`: lazy routes, guards, resolvers, params, child routes, navigation.
- `references/auth-patterns.md`: login, JWT, refresh, APP_INITIALIZER.
- `references/design-system.md`: SCSS, tokens, Material theme, dark mode.
- `references/a11y.md`: ARIA, focus, keyboard navigation, screen reader behavior, a11y tests.
- `references/testing-advanced.md`: dialogs, interceptors, guards, async, complex component tests.
- `references/e2e-testing.md`: Playwright, page objects, API mocking, CI e2e.
- `references/performance.md`: OnPush, virtual scroll, lazy loading, bundle analysis.
- `references/ssr-patterns.md`: SSR, hydration, transfer state, platform-aware code.
- `references/security-patterns.md`: XSS, DomSanitizer, CSRF, CSP, open redirects, sensitive data.
- `references/upgrade-migration.md`: Angular updates, standalone migration, Signals migration.
- `references/nx-workspace.md`: Nx libraries, tags, affected builds, graph checks.
- `references/build-tools.md`: `angular.json`, esbuild, CI, schematics, bundle analysis.
- `references/error-handling.md`: global error handling, notifications, error logging.
- `references/git-workflow.md`: branch names, commits, changelog, PR descriptions.
