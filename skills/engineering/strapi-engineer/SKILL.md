---
name: strapi-engineer
description: "Build, modify, review, and debug Strapi applications across content types, controllers, services, routes, policies, lifecycle hooks, plugins, auth, GraphQL, and tests. Use when working on Strapi v4 or v5 backend code, project architecture, schema design, API behavior, or production workflow."
---

# Strapi Engineer

Apply senior Strapi engineering judgment to v4 and v5 projects, with clear design choices, production-grade code, and focused validation.

## When to Use

Use this skill for Strapi application work: content-type schemas, API controllers, services, routes, policies, middleware, lifecycle hooks, plugins, extensions, RBAC, JWT, GraphQL, populate strategy, webhooks, cron, tests, migrations, and project workflow.

Use a narrower skill instead when the request is mainly generic TypeScript, frontend Angular, security auditing, analytics, or a non-Strapi backend.

## Core Rule

Choose the Strapi layer that matches the responsibility, keep controllers thin, put business logic in services, and validate behavior with tests or explicit runtime checks.

## Project Context

1. Look for `.context/INDEX.md` in the project root and read relevant domain files when present: `.context/project.md`, `.context/engineering.md`, `.context/git-workflow.md`, `.context/security.md`, `.context/learning.md`, and `.context/adr/`.
2. If project context is missing and the task depends on it, infer what you can from `package.json`, `config/`, `src/`, and existing tests before asking questions.
3. When context remains unclear, ask for only the missing decisions that affect implementation: Strapi version, draft/publish, i18n, auth method, main branch, and ticket prefix.
4. If the user asks to create project context, use the `setup-context` skill and write `.context/` domain files using `skills/productivity/setup-context/references/domains.md`.

## Workflow

1. Identify the Strapi version, package manager, TypeScript setup, test framework, and existing API/plugin structure.
2. State the important design decision before changing code, especially layer choice, data API choice, auth boundary, schema relation, or populate shape.
3. Prefer existing project conventions for factories, services, naming, route files, tests, and config.
4. Implement the smallest behavior slice. For risky or user-facing logic, write or update tests first when practical.
5. Sanitize public controller input and output, avoid hardcoded secrets, and keep populate/select explicit.
6. Validate with targeted tests, lint/typecheck, or a concrete manual check. Report any validation you could not run.

## Strapi Defaults

- Strapi v5: prefer `strapi.documents('api::x.x')` for content types because it is locale-aware and draft/publish-aware.
- Strapi v4: use `strapi.entityService`; use `strapi.db.query` only for raw aggregations, joins, or cases unsupported by Entity Service.
- Controllers validate and sanitize request data, delegate to services, and return `this.transformResponse(result, meta)`.
- Services hold business rules and should not depend on `ctx`.
- Policies authorize access before controllers and return `true` or `false`.
- Middleware handles cross-cutting request/response concerns.
- Lifecycle hooks handle entity operation side effects.
- Plugins package reusable features; extensions override existing plugin behavior without forking.

## Reference Map

Load only the reference needed for the current task:

- `references/strapi-decisions.md`: layer choice, content modeling, auth, error handling, API choice, and populate rules.
- `references/strapi-testing.md`: test setup, mocked Strapi, supertest, fixtures, or test patterns.
- `references/strapi-schema.md`: relation types, plugins, extensions, or Document Service examples.
- `references/strapi-server.md`: middleware, policies, lifecycle hooks, custom routes, cron, or webhooks.
- `references/strapi-graphql.md`: GraphQL setup, custom queries/mutations, resolvers, depth limits, or amount limits.
- `references/git-workflow.md`: branch naming, commits, tags, releases, changelog, or PR descriptions.
- `references/context-template.md`: `.context/` domain creation.

## Review Checklist

- Correct layer owns the behavior.
- v4/v5 data API usage is consistent inside each file.
- Public endpoints sanitize query input and output data.
- Populate/select returns only fields the client needs.
- Auth, RBAC, policies, and private fields are handled deliberately.
- Tests or explicit checks cover the changed behavior.
