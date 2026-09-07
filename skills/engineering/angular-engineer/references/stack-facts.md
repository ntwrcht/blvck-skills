# Angular Stack Facts

The Angular-specific facts a task must establish before generating code. The shared skeleton for reading, repairing, or skipping `.context/` is `references/project-context.md`; this file is what it points at.

## Recorded In Context

`.context/engineering.md` holds the Angular version, module style, zone mode, state pattern, test runner, design tokens, shared components, core services, and API conventions when the project records them there. Ask before generating code when either Angular version or design-system approach is blank and the current task depends on it.

## Facts That Change Generated Code

Establish these before writing anything non-trivial. Each one silently changes what correct code looks like.

| Fact | Where to find it | Why it matters |
|---|---|---|
| Angular major version | `@angular/core` in `package.json` | Decides standalone-first vs NgModule, built-in control flow, `input()`/`output()`, zoneless options |
| Module style | `standalone: true` on components, or `@NgModule` declarations | A standalone component dropped into an NgModule app, or the reverse, fails at bootstrap |
| State pattern | Signals, RxJS services, or NgRx in `package.json` and feature folders | Decides whether new state is a `signal()`, a `BehaviorSubject`, or a store slice |
| Test runner | `angular.json` test builder, `karma.conf.js`, `jest.config.*`, `vitest.config.*` | Decides spec syntax, mocking style, and how the focused test command is invoked |

## Stale When

Offer to update the relevant `.context/` domain file when the user mentions or the repo shows:

- Angular version upgrade
- Design system or CSS framework change
- New shared components or core services
- Branch strategy change
- Test runner migration
- SSR, hydration, or zoneless adoption

## Ask For

The bundled detector (`scripts/detect-project.sh`) inspects `package.json`, `angular.json`, `tsconfig.json`, source layout, and git history. If it cannot run, ask for:

- Angular version
- Module style: standalone or NgModule
- Main branch name
- Ticket prefix, if commit or PR output is needed
- Design system or CSS approach
- Shared component and token locations
- HTTP abstraction layer, if services or API calls are involved
- Test runner

## Read Anyway

Still read `package.json` for the Angular major version and check one component for `standalone: true` — those two reads cost nothing and prevent the most common category of wrong-version code.
