# Project Context Template

Use this template to generate `PROJECT_CONTEXT.md` at the project root after gathering context
for the first time on a new project. Offer it to the user with:

> "Want me to save this as `PROJECT_CONTEXT.md` at your project root? It'll let me skip these questions next session."

After generating it, read it at the start of every subsequent session instead of asking questions.

---

```markdown
# PROJECT_CONTEXT.md
<!-- Angular skill context — update when project conventions change -->

## Angular Version
<!-- e.g. Angular 17 — standalone components, @if/@for, no NgModule -->
<!-- e.g. Angular 14 — NgModule-based, constructor injection -->

## Design Tokens
<!-- Paste your primary/accent/warn hex values and spacing scale -->
<!-- e.g. Primary: #1a73e8 | Accent: #fbbc04 | Warn: #ea4335 -->
<!-- e.g. Spacing: xs=4px, sm=8px, md=16px, lg=24px, xl=32px -->
<!-- Token file: src/styles/_variables.scss -->

## Angular Material Theme
<!-- e.g. Indigo/Pink light theme — theme.scss -->
<!-- e.g. Custom teal/amber theme — src/styles/theme.scss -->

## Existing Shared Components
<!-- List reusable components already in src/app/shared/ so nothing gets duplicated -->
<!-- e.g. app-data-table, app-confirm-dialog, app-status-badge, app-empty-state -->

## Existing Core Services
<!-- List singleton services in src/app/core/services/ -->
<!-- e.g. ApiService, AuthService, NotificationService, LoggingService -->

## Project Conventions
<!-- Any deviations from the skill's defaults -->
<!-- e.g. API base URL via environment.apiUrl -->
<!-- e.g. All forms use UntypedFormGroup (migrating gradually) -->
<!-- e.g. No Bootstrap — layout is pure CSS Grid -->
```
