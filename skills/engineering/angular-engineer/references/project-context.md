# Angular Project Context

Use this reference when project code changes are needed and `.context/INDEX.md`, `.context/project.md`, or `.context/engineering.md` is missing, stale, or too incomplete to choose Angular patterns safely.

## Existing Context

If `.context/INDEX.md` exists, read it first to see which domain files are available. Then read only the files needed for the Angular task:

- `.context/project.md` for stack, repo layout, environment, and vocabulary.
- `.context/engineering.md` for Angular version, module style, zone mode, state pattern, test runner, design tokens, shared components, core services, and API conventions when the project records them there.
- `.context/git-workflow.md` when branch names, commits, or PR text are involved.
- `.context/security.md`, `.context/learning.md`, or `.context/adr/` when the task touches those concerns.

Ask before generating code when either Angular version or design-system approach is blank and the current task depends on it.

## Stale Context

Offer to update the relevant `.context/` domain file when the user mentions or the repo shows:

- Angular version upgrade
- Design system or CSS framework change
- New shared components or core services
- Branch strategy change
- Test runner migration
- SSR, hydration, or zoneless adoption

## Missing Context

Run the detector from the skill directory:

```bash
bash <skill-dir>/scripts/detect-project.sh .
```

The script inspects `package.json`, `angular.json`, `tsconfig.json`, source layout, and git history, then prints draft content for `.context/project.md`, `.context/engineering.md`, and `.context/git-workflow.md`.

If the detector cannot run, ask for the missing values that affect the work:

- Angular version
- Module style: standalone or NgModule
- Main branch name
- Ticket prefix, if commit or PR output is needed
- Design system or CSS approach
- Shared component and token locations
- HTTP abstraction layer, if services or API calls are involved
- Test runner

## Files to Create

When context files are missing and the user accepts context setup, use the `setup-context` skill. It creates:

- `.context/INDEX.md`: available context domains
- `.context/project.md`: stack, repo layout, environment, and vocabulary
- `.context/engineering.md`: Angular and testing conventions
- `.context/git-workflow.md`: branch, commit, and release conventions

Use `skills/productivity/setup-context/references/domains.md` for exact structure.

Create provider stubs only if they do not already exist:

- `CLAUDE.md`
- `GEMINI.md`
- `.cursorrules`
- `.github/copilot-instructions.md`
- `.windsurfrules`

## If the User Says to Skip Context

Proceed with reasonable assumptions, state those assumptions briefly, and avoid broad architectural changes that depend on unknown project conventions.
