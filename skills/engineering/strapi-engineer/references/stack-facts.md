# Strapi Stack Facts

The Strapi-specific facts a task must establish before generating code. The shared skeleton for reading, repairing, or skipping `.context/` is `references/project-context.md`; this file is what it points at.

## Recorded In Context

`.context/engineering.md` holds the Strapi version, data API, draft/publish and i18n posture, auth method, GraphQL, TypeScript setup, and test runner when the project records them there. Ask before generating code when either the Strapi major version or the draft/publish posture is blank and the current task depends on it.

## Facts That Change Generated Code

Establish these before writing anything non-trivial. Each one silently changes what correct code looks like.

| Fact | Where to find it | Why it matters |
|---|---|---|
| Strapi major version | `@strapi/strapi` in `package.json` | v5 uses `strapi.documents()` and `documentId`; v4 uses `strapi.entityService` and numeric `id` |
| Draft/publish | `draftAndPublish` in each `content-types/*/schema.json` | Decides whether a query must pass a status, and whether a read can return an unpublished row |
| i18n | `@strapi/plugin-i18n`, plus `pluginOptions.i18n` per schema | Decides whether every read and write needs a locale, and whether one entry means several documents |
| Auth method | `@strapi/plugin-users-permissions`, custom JWT or SSO code under `src/` | Decides where authorization belongs — a policy, a route config, or a service check |

The v4-to-v5 split is the one that produces the most confidently wrong code: the two data APIs take different arguments and return different shapes, so a v4 example dropped into a v5 project fails at runtime rather than at review.

## Stale When

Offer to update the relevant `.context/` domain file when the user mentions or the repo shows:

- A v4 to v5 migration, in progress or complete
- Draft/publish being enabled or removed on a content type
- i18n adoption, or a new locale set
- A new auth provider, custom JWT handling, or a move off users-permissions
- GraphQL being added or dropped
- A JavaScript project adopting TypeScript
- New local plugins or extensions
- Database change, especially SQLite to Postgres
- Test runner migration

## Ask For

The bundled detector (`scripts/detect-project.sh`) inspects `package.json`, `tsconfig.json`, lockfiles, the `src/api` content-type schemas, local plugins and extensions, and git history. If it cannot run, ask for:

- Strapi version, and therefore which data API applies
- Whether draft/publish is enabled, and on which content types
- Whether i18n is enabled, and the locale set
- Auth method and where authorization is enforced
- Whether GraphQL is exposed
- TypeScript or JavaScript
- Database
- Test runner, and whether API tests run against a booted instance
- Main branch name
- Ticket prefix, if commit or PR output is needed

## Read Anyway

Still read `package.json` for the Strapi major version and check one `schema.json` for `draftAndPublish` — those two reads cost nothing and prevent the most common category of wrong-version code.
