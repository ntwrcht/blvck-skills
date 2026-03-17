# Commit Convention & Git Workflow

## Table of Contents
1. Conventional Commits Format
2. Type Reference
3. Scope Guidelines
4. Examples — Good vs Bad
5. Branch Naming
6. PR Description Template
7. Changelog Generation

---

## 1. Conventional Commits Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

**Rules:**
- Subject: imperative mood, lowercase, no period at end, max 72 chars
- Body: explain *what* and *why*, not *how* — wrap at 72 chars
- Footer: breaking changes, issue references

```
feat(bot-builder): add voice script configuration panel

Allow users to configure TTS voice, speed, and language per bot.
Previously this required manual API calls.

Closes #234
```

---

## 2. Type Reference

| Type | When to Use | Bumps Version |
|---|---|---|
| `feat` | New feature visible to users | Minor |
| `fix` | Bug fix | Patch |
| `perf` | Performance improvement, no behavior change | Patch |
| `refactor` | Code restructure, no behavior change | — |
| `style` | Formatting, whitespace, missing semicolons | — |
| `test` | Add or fix tests only | — |
| `docs` | Documentation only | — |
| `chore` | Build process, dependency updates, tooling | — |
| `ci` | CI/CD pipeline changes | — |
| `revert` | Revert a previous commit | — |

**Breaking change** — append `!` after type or add `BREAKING CHANGE:` in footer:
```
feat(api)!: remove deprecated v1 endpoints

BREAKING CHANGE: /api/v1/* endpoints removed. Migrate to /api/v2/*.
```

---

## 3. Scope Guidelines

Scope = the part of the codebase affected. Keep it consistent across the team.

**Define scopes based on your project structure:**

```
# Features / modules
feat(auth): ...
feat(bot-builder): ...
feat(flow-editor): ...
feat(channel): ...
feat(analytics): ...

# Layers
fix(api): ...
fix(ui): ...
fix(db): ...

# Infrastructure
chore(deps): ...
ci(deploy): ...
chore(docker): ...
```

**When to omit scope:** changes that truly span the whole codebase
```
refactor: migrate all components to standalone
chore: upgrade Angular to v17
```

---

## 4. Examples — Good vs Bad

### Features
```
# ✅
feat(channel): add WhatsApp Business channel integration
feat(bot-builder): support drag-and-drop node reordering
feat(auth): implement MFA with TOTP

# ❌
feat: add stuff
feat: WhatsApp
Added new feature for the channel page
```

### Bug Fixes
```
# ✅
fix(flow-editor): prevent infinite loop when circular nodes detected
fix(auth): refresh token not cleared on logout
fix(channel): LINE webhook signature validation fails for UTF-8 payloads

# ❌
fix: bug fix
fix: fixed the thing
fix: update code
```

### Refactors
```
# ✅
refactor(user-service): replace BehaviorSubject with signal-based state
refactor(http): centralize error handling in ApiService interceptor

# ❌
refactor: clean up code
refactor: misc changes
```

### Chores & CI
```
# ✅
chore(deps): upgrade @angular/core to 17.3.0
chore(deps-dev): bump eslint from 8.50.0 to 8.57.0
ci(deploy): add staging environment deployment step
docs(api): add OpenAPI spec for /bots endpoints

# ❌
chore: update packages
misc: various fixes
```

---

## 5. Branch Naming

```
<type>/<ticket-id>-<short-description>

type:  feat | fix | refactor | chore | docs | hotfix
```

```
# ✅
feat/BNCP-234-voice-script-panel
fix/BNCP-189-login-redirect-loop
refactor/BNCP-201-signal-state-migration
chore/BNCP-210-upgrade-angular-17
hotfix/BNCP-299-prod-webhook-timeout
docs/BNCP-215-api-openapi-spec

# ❌
new-feature
johns-branch
fix-bug-2
temp
```

**Rules:**
- Always include ticket ID — links branch to issue tracker
- Use kebab-case, no spaces or underscores
- Keep description short (3–5 words)
- `hotfix/` = production emergency, bypasses normal review (use sparingly)

---

## 6. PR Description Template

```markdown
## Summary
<!-- What does this PR do? 2–3 sentences max. -->

## Changes
<!-- Bullet list of notable changes -->
- 
- 

## Type of Change
- [ ] feat — new feature
- [ ] fix — bug fix
- [ ] refactor — no behavior change
- [ ] chore / docs / ci

## Testing
<!-- How was this tested? -->
- [ ] Unit tests added / updated
- [ ] Tested manually on local
- [ ] Tested on staging

## Screenshots (if UI change)
<!-- Before / After -->

## Related Issues
Closes #
```

---

## 7. Changelog Generation

If using **standard-version** or **semantic-release**, commits are parsed automatically:

```bash
# Install
npm install --save-dev standard-version

# Generate changelog + bump version
npx standard-version

# Dry run — preview without writing
npx standard-version --dry-run
```

**What gets included in CHANGELOG.md:**
- `feat` → Features section (minor bump)
- `fix` → Bug Fixes section (patch bump)
- `perf` → Performance section (patch bump)
- `feat!` / `BREAKING CHANGE` → Breaking Changes (major bump)
- Everything else → excluded from changelog

**Manual changelog entry format (if not automated):**
```markdown
## [2.4.0] - 2025-03-17

### Features
- **bot-builder:** add voice script configuration panel (#234)
- **channel:** add WhatsApp Business integration (#198)

### Bug Fixes
- **auth:** refresh token not cleared on logout (#241)
- **flow-editor:** prevent crash on circular node detection (#239)

### Performance
- **api:** reduce bot list query time by 60% with index optimization (#237)
```
