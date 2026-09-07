---
name: strapi-engineer
description: "Builds, modifies, reviews, and debugs Strapi applications across content types, controllers, services, routes, policies, lifecycle hooks, plugins, auth, GraphQL, and tests. Use when working on Strapi v4 or v5 backend code, project architecture, schema design, API behavior, or production workflow."
---

# Strapi Engineer

Apply senior Strapi engineering judgment to v4 and v5 projects, with clear design choices, production-grade code, and focused validation.

## When to Use

Use this skill for Strapi application work: content-type schemas, API controllers, services, routes, policies, middleware, lifecycle hooks, plugins, extensions, RBAC, JWT, GraphQL, populate strategy, webhooks, cron, tests, migrations, and project workflow.

Use a narrower skill instead when the request is mainly generic TypeScript, frontend Angular, security auditing, analytics, or a non-Strapi backend.

## Artifacts

- Produces: code changes
- Consumes: stories at the `story` key path (if present) — see `references/artifact-paths.md` (default `docs/stories/<slug>.md`), `.context/project.md`, `.context/engineering.md`, `.context/git-workflow.md`, `.context/security.md`, `.context/learning.md`, `.context/adr/`

## Core Rule

Choose the Strapi layer that matches the responsibility, keep controllers thin, put business logic in services, and validate behavior with tests or explicit runtime checks.

## Quick Path

Answer conceptual and architecture questions directly as prose with tradeoffs, and give explanations, single-line fixes, or small snippets inline. Do not run the full project-context workflow unless you are generating, modifying, reviewing, or debugging project code.

## Workflow

1. Inspect local context before changing code. Read `.context/INDEX.md` when present, then load relevant domain files such as `.context/project.md`, `.context/engineering.md`, `.context/git-workflow.md`, `.context/security.md`, `.context/learning.md`, and `.context/adr/`. If context is missing and project code changes are needed, follow `references/project-context.md`.
2. Confirm the Strapi version, draft/publish posture, and i18n posture from context, `package.json`, and the `content-types/*/schema.json` files, before choosing APIs.
3. Check nearby code for naming, folder structure, factories, services, route files, populate conventions, and test style.
4. Load only the reference files needed for the task from the Reference Map.
5. State the important design decision before changing code, especially layer choice, data API choice, auth boundary, schema relation, or populate shape.
6. Make the smallest coherent change, including tests when behavior changes. Sanitize public controller input and output, avoid hardcoded secrets, and keep populate/select explicit.
7. Validate with the repo's focused test, lint, or typecheck command, or a concrete manual check. Report any validation you could not run.

## Strapi Defaults

- Strapi v5: prefer `strapi.documents('api::x.x')` for content types because it is locale-aware and draft/publish-aware.
- Strapi v4: use `strapi.entityService`; use `strapi.db.query` only for raw aggregations, joins, or cases unsupported by Entity Service.
- Controllers validate and sanitize request data, delegate to services, and return `this.transformResponse(result, meta)`.
- Services hold business rules and should not depend on `ctx`.
- Policies authorize access before controllers and return `true` or `false`.
- Middleware handles cross-cutting request/response concerns.
- Lifecycle hooks handle entity operation side effects.
- Plugins package reusable features; extensions override existing plugin behavior without forking.

## Version Guide

| Version | Default shape | Common APIs |
|---|---|---|
| Strapi v4 | Entity Service | `strapi.entityService`, numeric `id`, `strapi.db.query` for raw work, `publicationState` |
| Strapi v5 | Document Service | `strapi.documents('api::x.x')`, string `documentId`, `status: 'draft' \| 'published'`, locale-aware by default |

The two data APIs take different arguments and return different shapes, so confirm the major version before writing a query. Ask before defaulting when the version is unclear and the choice affects generated code.

## Output Shape

- Small fix: changed code plus one sentence explaining the decision.
- New content type or endpoint: schema, controller, service, routes, policies, tests, and a short decision note.
- Architecture or conceptual answer: direct prose with tradeoffs.
- Review: findings first with file and line references.

## Reference Map

Load only the reference needed for the current task:

- `references/strapi-decisions.md`: layer choice, content modeling, auth, error handling, API choice, and populate rules.
- `references/strapi-testing.md`: test setup, mocked Strapi, supertest, fixtures, or test patterns.
- `references/strapi-schema.md`: relation types, plugins, extensions, or Document Service examples.
- `references/strapi-server.md`: middleware, policies, lifecycle hooks, custom routes, cron, or webhooks.
- `references/strapi-graphql.md`: GraphQL setup, custom queries/mutations, resolvers, depth limits, or amount limits.
- `references/git-workflow.md`: branch naming, commits, tags, releases, changelog, or PR descriptions.
- `references/context-template.md`: `.context/` domain creation.
- `references/project-context.md`: what to read when `.context/` is missing or stale, the four facts that change generated code, and the detector.
- `scripts/detect-project.sh`: inspects the repo and prints draft `.context/` domain files. Run it rather than interviewing the user.

## Review Checklist

- Correct layer owns the behavior.
- v4/v5 data API usage is consistent inside each file.
- Public endpoints sanitize query input and output data.
- Populate/select returns only fields the client needs.
- Auth, RBAC, policies, and private fields are handled deliberately.
- Tests or explicit checks cover the changed behavior.

## Next Step

Do not treat a change as done until the server restarts cleanly and the affected endpoints have been exercised — a content-type or schema edit has no real effect until the restart, so an untested schema change is an unverified one.

- **If approved:** hand off to `tdd` when the change needs behavior tests it does not have, to `scrutinize` for an independent review of the diff, or to `security-audit` when it touches policies, permissions, auth, lifecycle hooks, or the public API surface.
- **If not approved:** revise in place. When a failure's cause is not obvious from the server logs, escalate to `debug` rather than guessing at fixes.
