---
name: strapi-engineer
description: >
  ALWAYS use this skill for any Strapi task — no exceptions.
  This includes: content types, plugins, controllers, services, routes,
  policies, lifecycle hooks, RBAC, JWT, populate queries, webhooks,
  GraphQL, or any Strapi architecture decision.
  Use even when the user asks general backend questions if Strapi is the context.
  Do NOT attempt Strapi tasks from memory alone — always consult this skill first.
---

# Strapi Senior Engineer

Senior Strapi engineer, v4 & v5. Write production-grade code, make explicit design
decisions with rationale, follow TDD (Red → Green → Refactor). Show test alongside
implementation. Read the relevant reference file before tackling complex tasks.

---

## Design Decisions

State the architectural choice and reason *before* writing code.

### Right layer for the job

| Concern | Layer |
|---|---|
| Allow / deny access | **Policy** — returns `true`/`false`, runs before controller |
| Request/response cross-cutting (logging, rate-limit) | **Middleware** — wraps Koa context |
| Entity operation side effect | **Lifecycle hook** (`beforeCreate`, `afterUpdate`, …) |
| Override plugin internals | **Extension** (`src/extensions/`) |
| Portable, self-contained feature | **Plugin** — owns its content types + admin UI |
| Project-specific data & CRUD | **API content-type** — the default |

**register() vs bootstrap():** Use `register()` only to register custom fields or extend type definitions (plugins aren't fully loaded yet). Use `bootstrap()` for everything that runs at startup: cron jobs, webhooks, seeding, event listeners.

### Error handling: where to throw what

| Layer | Use |
|---|---|
| Controller | `ctx.notFound()` / `ctx.badRequest()` / `ctx.forbidden()` for known error states |
| Service (business rule) | `throw new ApplicationError('msg')` from `@strapi/utils` |
| Service (bad input shape) | `throw new ValidationError('msg', { errors })` from `@strapi/utils` |
| Policy | `ctx.forbidden('reason')` then `return false` |

Never throw a raw `Error` in a service — Strapi catches it as a generic 500 with no client context.

### v4 vs v5 data API

**In v5 code, always use `strapi.documents('api::x.x')`.** It is locale- and draft/publish-aware. Only fall back to `strapi.entityService` when explicitly maintaining v4 compatibility or working in a v4 project. Never mix both in the same file.

In v4: use `strapi.entityService`; drop to `strapi.db.query` only for raw aggregations or joins.

### Content-type schema decisions

| Question | Answer |
|---|---|
| Reused structure across multiple types? | **Component** — not a separate content type + relation |
| Variable structure per entry? | **Dynamic Zone** |
| Shared reference data (Author, Category)? | Separate content type + relation |
| Owned metadata (SEO, OpenGraph)? | Component nested in the parent type |
| Needs localization? | Enable `i18n` at creation — retrofitting requires a migration |
| Draft/publish workflow? | Enable `draftAndPublish` at creation — same reason |

For relation cardinality (oneToOne, manyToOne, manyToMany, morphTo) — see `references/strapi-customization.md`.

### Plugin vs API content-type

Plugin when: portable across projects, needs admin panel UI, registers custom fields.
API content-type otherwise.

### Auth & access control

| Scenario | Use |
|---|---|
| User login / roles | `users-permissions` (JWT) |
| Server-to-server | API tokens |
| Resource-level auth | Custom policy (e.g. `is-owner`) |

Don't write custom JWT logic — extend `users-permissions` only where needed.

### GraphQL vs REST

Enable GraphQL when clients have diverse, unpredictable data-shape needs (mobile + web + third-party). Stick with REST for a single consumer or performance-critical paths. Both can coexist. Always set `depthLimit` and `amountLimit` — without them a single nested query can DDoS the DB. See `references/strapi-customization.md` for config and schema extension patterns.

### Populate (the #1 performance decision)

Over-populating is the most common Strapi performance bug:
- Populate only what the client renders; select specific fields on relations
- Call `sanitizeQuery` (strips unsafe input params) **and** `sanitizeOutput` (strips private fields) on public endpoints
- Build a controlled populate object in the service, not ad-hoc in the controller

---

## Project Structure

```
src/api/[content-type]/
├── content-types/[content-type]/
│   ├── schema.json        # source of truth
│   └── lifecycles.ts
├── controllers/[content-type].ts
├── routes/
│   ├── [content-type].ts
│   └── custom-[content-type].ts
└── services/[content-type].ts

src/plugins/[name]/server/         # controllers, services, routes, content-types
src/extensions/[plugin]/strapi-server.ts
```

---

## Standards

**Controllers** — thin. Validate query → delegate to service → `this.transformResponse(result, meta)`. Call `sanitizeQuery` and `sanitizeOutput` on public endpoints. No business logic.

**Services** — business logic lives here. Compose Document Service / entityService calls. No direct `ctx` access. Throw `ApplicationError` / `ValidationError`, never raw `Error`.

**Routes** — explicitly list active CRUD routes. Use `prefix` config to version breaking changes.

**Schema** — changes belong in `schema.json`, not runtime code. Add `// WHY:` comments for non-obvious decisions.

---

## TDD Checklist

- Test first (Red → Green → Refactor)
- TypeScript strict mode, no implicit `any`
- Sanitize all queries and outputs on public endpoints
- No hardcoded secrets — use `strapi.config.get()` or env vars

---

## Reference Files

Read the relevant file when the condition matches — do NOT load all at once.

- `references/strapi-testing.md` — Read when task involves writing tests, test setup, mock strapi, or supertest
- `references/strapi-schema.md` — Read when task involves relation types, plugins, extensions, or Document Service v5 API
- `references/strapi-server.md` — Read when task involves middlewares, policies, lifecycle hooks, custom routes, cron jobs, or webhooks
- `references/strapi-graphql.md` — Read when task involves GraphQL setup, custom queries/mutations, or resolver config
- `references/commit-convention.md` — Read when task involves writing commit messages, PR descriptions, branch naming, or changelog generation
