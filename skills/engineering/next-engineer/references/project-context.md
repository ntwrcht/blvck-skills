# Next.js Project Context

Use this reference when project code changes are needed and `.context/INDEX.md`, `.context/project.md`, or `.context/engineering.md` is missing, stale, or too incomplete to choose Next.js patterns safely.

## Existing Context

If `.context/INDEX.md` exists, read it first to see which domain files are available. Then read only the files needed for the Next.js task:

- `.context/project.md` for stack, repo layout, environment, and vocabulary.
- `.context/engineering.md` for Next.js version, router, caching model, styling system, component library, state pattern, data layer, test runner, and API conventions when the project records them there.
- `.context/git-workflow.md` when branch names, commits, or PR text are involved.
- `.context/security.md`, `.context/learning.md`, or `.context/adr/` when the task touches those concerns.

Ask before generating code when either the Next.js version or the router is blank and the current task depends on it.

## The Four Facts That Change Generated Code

Establish these before writing anything non-trivial. Every one of them silently changes what correct code looks like.

| Fact | Where to find it | Why it matters |
|---|---|---|
| Next.js major version | `package.json` → `next` | Decides async vs sync `params`, `proxy.ts` vs `middleware.ts`, whether `'use cache'` exists |
| Router | `app/` vs `pages/` on disk | Server Components and Server Actions only exist in the App Router |
| Caching model | `cacheComponents` in `next.config.*` | Decides whether caching is opt-in (`'use cache'`) or implicit (`fetch` options + route config) |
| Data layer | `lib/`, `server/`, `db/`, ORM dep | Decides whether new reads go through an existing DAL or a raw client |

A repo can have both `app/` and `pages/`. That is a supported hybrid, not a mistake — match whichever tree the file you are touching lives in, and see `references/pages-router.md`.

## Stale Context

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

## Missing Context

Run the detector from the skill directory:

```bash
bash <skill-dir>/scripts/detect-project.sh .
```

The script inspects `package.json`, `next.config.*`, `tsconfig.json`, the route tree, and git history, then prints draft content for `.context/project.md`, `.context/engineering.md`, and `.context/git-workflow.md`.

If the detector cannot run, ask for the missing values that affect the work:

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

## Files to Create

When context files are missing and the user accepts context setup, use the `setup-context` skill. It creates:

- `.context/INDEX.md`: available context domains
- `.context/project.md`: stack, repo layout, environment, and vocabulary
- `.context/engineering.md`: Next.js and testing conventions
- `.context/git-workflow.md`: branch, commit, and release conventions

Use `skills/productivity/setup-context/references/domains.md` for exact structure.

Create provider stubs only if they do not already exist:

- `CLAUDE.md`
- `AGENTS.md`
- `GEMINI.md`
- `.cursorrules`
- `.github/copilot-instructions.md`
- `.windsurfrules`

Next.js 16.3+ ships bundled `AGENTS.md` docs. If the project already has one from `create-next-app`, extend it rather than replacing it.

## If the User Says to Skip Context

Proceed with reasonable assumptions, state those assumptions briefly, and avoid broad architectural changes that depend on unknown project conventions. Still read `package.json` and check for `app/` vs `pages/` — those two reads cost nothing and prevent the most common category of wrong-version code.
