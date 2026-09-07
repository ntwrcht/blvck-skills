# Next.js Stack Facts

The Next.js-specific facts a task must establish before generating code. The shared skeleton for reading, repairing, or skipping `.context/` is `references/project-context.md`; this file is what it points at.

## Recorded In Context

`.context/engineering.md` holds the Next.js version, router, caching model, styling system, component library, state pattern, data layer, test runner, and API conventions when the project records them there. Ask before generating code when either the Next.js version or the router is blank and the current task depends on it.

## Facts That Change Generated Code

Establish these before writing anything non-trivial. Every one of them silently changes what correct code looks like.

| Fact | Where to find it | Why it matters |
|---|---|---|
| Next.js major version | `package.json` → `next` | Decides async vs sync `params`, `proxy.ts` vs `middleware.ts`, whether `'use cache'` exists |
| Router | `app/` vs `pages/` on disk | Server Components and Server Actions only exist in the App Router |
| Caching model | `cacheComponents` in `next.config.*` | Decides whether caching is opt-in (`'use cache'`) or implicit (`fetch` options + route config) |
| Data layer | `lib/`, `server/`, `db/`, ORM dep | Decides whether new reads go through an existing DAL or a raw client |

A repo can have both `app/` and `pages/`. That is a supported hybrid, not a mistake — match whichever tree the file you are touching lives in, and see `references/pages-router.md`.

## Stale When

Offer to update the relevant `.context/` domain file when the user mentions or the repo shows:

- Next.js version upgrade, especially 14→15 (async request APIs) or 15→16 (Cache Components, `proxy.ts`)
- Pages Router to App Router migration, in progress or complete
- Cache Components adoption
- Styling system or component library change
- Bundler switch between Turbopack and webpack
- New shared UI, data-access helpers, or server-only modules
- Auth library adoption or replacement
- Branch strategy change
- Test runner migration
- Deployment target change, especially Vercel to self-hosted or the reverse

## Ask For

The bundled detector (`scripts/detect-project.sh`) inspects `package.json`, `next.config.*`, `tsconfig.json`, the route tree, and git history. If it cannot run, ask for:

- Next.js version
- Router: App, Pages, or hybrid
- Whether Cache Components (`cacheComponents: true`) is enabled
- Styling system and component library
- Data access approach: ORM, API client, or direct fetch, and where those helpers live
- Auth library and where the session is read
- Main branch name
- Ticket prefix, if commit or PR output is needed
- Test runner and e2e runner
- Deployment target

## Read Anyway

Still read `package.json` and check for `app/` vs `pages/` — those two reads cost nothing and prevent the most common category of wrong-version code.
