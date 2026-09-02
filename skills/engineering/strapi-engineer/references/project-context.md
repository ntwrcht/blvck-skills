# Strapi Project Context

Use this reference when project code changes are needed and `.context/INDEX.md`, `.context/project.md`, or `.context/engineering.md` is missing, stale, or too incomplete to choose Strapi patterns safely.

## Existing Context

If `.context/INDEX.md` exists, read it first to see which domain files are available. Then read only the files needed for the Strapi task:

- `.context/project.md` for stack, repo layout, environment, and vocabulary.
- `.context/engineering.md` for Strapi version, data API, draft/publish and i18n posture, auth method, GraphQL, TypeScript setup, and test runner when the project records them there.
- `.context/git-workflow.md` when branch names, commits, or PR text are involved.
- `.context/security.md`, `.context/learning.md`, or `.context/adr/` when the task touches those concerns.

Ask before generating code when either the Strapi major version or the draft/publish posture is blank and the current task depends on it.

## Four Facts That Change Generated Code

Establish these before writing anything non-trivial. Each one silently changes what correct code looks like.

| Fact | Where to find it | Why it matters |
|---|---|---|
| Strapi major version | `@strapi/strapi` in `package.json` | v5 uses `strapi.documents()` and `documentId`; v4 uses `strapi.entityService` and numeric `id` |
| Draft/publish | `draftAndPublish` in each `content-types/*/schema.json` | Decides whether a query must pass a status, and whether a read can return an unpublished row |
| i18n | `@strapi/plugin-i18n`, plus `pluginOptions.i18n` per schema | Decides whether every read and write needs a locale, and whether one entry means several documents |
| Auth method | `@strapi/plugin-users-permissions`, custom JWT or SSO code under `src/` | Decides where authorization belongs — a policy, a route config, or a service check |

The v4-to-v5 split is the one that produces the most confidently wrong code: the two data APIs take different arguments and return different shapes, so a v4 example dropped into a v5 project fails at runtime rather than at review.

## Stale Context

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

## Missing Context

Run the detector from the skill directory:

```bash
bash <skill-dir>/scripts/detect-project.sh .
```

The script inspects `package.json`, `tsconfig.json`, lockfiles, the `src/api` content-type schemas, local plugins and extensions, and git history, then prints draft content for `.context/project.md`, `.context/engineering.md`, and `.context/git-workflow.md`.

If the detector cannot run, ask for the missing values that affect the work:

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

## Files to Create

When context files are missing and the user accepts context setup, tell them to run `/setup-context`. It scaffolds:

- `.context/INDEX.md`: available context domains
- `.context/project.md`: stack, repo layout, environment, and vocabulary
- `.context/engineering.md`: Strapi and testing conventions
- `.context/git-workflow.md`: branch, commit, and release conventions

`references/context-template.md` carries this skill's own copy of the domain structure if the user wants to write the files by hand instead.

Create provider stubs only if they do not already exist:

- `CLAUDE.md`
- `AGENTS.md`
- `GEMINI.md`
- `.cursorrules`
- `.github/copilot-instructions.md`
- `.windsurfrules`

## If the User Says to Skip Context

Proceed with reasonable assumptions, state those assumptions briefly, and avoid broad schema changes that depend on unknown conventions. Still read `package.json` for the Strapi major version and check one `schema.json` for `draftAndPublish` — those two reads cost nothing and prevent the most common category of wrong-version code.
