---
name: setup-context
description: "Scaffold shared project context files in .context/ so skills read domain knowledge without re-asking orientation questions. Use when onboarding skills to a new or existing repo, or when skills appear to lack shared project context."
disable-model-invocation: true
---

# Setup Context

Scaffold the per-project context files that skills read before doing work — so they operate with shared domain knowledge instead of asking the same orientation questions every session.

## When to Use

Run once per project before first use of `angular-engineer`, `python-engineer`, `strapi-engineer`, `diagnose`, `tdd`, `security-audit`, `ga4-measurement`, `triage`, `post-mortem`, `scrutinize`, or `stakeholder-update`. Re-run only to add domains or reset from scratch.

Do not use to update domain content — edit `.context/*.md` files directly instead.

## Core Rule

Explore first, ask second, write last. Never scaffold a domain file the user has not explicitly confirmed.

## Process

### 1. Explore

Before asking anything, read what already exists:

- `.context/` — existing domain files and `INDEX.md`
- `CLAUDE.md` — is there already a `## Context` block?
- `package.json`, `angular.json`, `pyproject.toml`, `Cargo.toml` — detect tech stack
- `git remote -v` — project name and remote

### 2. Present findings

Summarise what was detected and what is missing, then begin the domain interview.

### 3. Interview — one domain at a time

Walk through domains in this order: `project` → `engineering` → `git-workflow` → `security` → `analytics` → `adr` → `triage` → `post-mortem` → `learning`.

For each: give a one-line explainer of what it contains and which skills read it, then ask if it applies to this project. Do not present all domains at once.

Load `references/domains.md` for domain descriptions, consuming skills, and seed templates.

### 4. Confirm drafts

Show draft content for each selected domain file and `INDEX.md` before writing. Let the user edit.

### 5. Write

- Create `.context/<domain>.md` for each confirmed domain (or `.context/adr/` directory)
- Create `.context/INDEX.md` listing each file with a one-line description
- Add or update `## Context` block in `CLAUDE.md`:

```markdown
## Context

Project context lives in `.context/`. Read `.context/INDEX.md` first to see which domains
are available, then load the ones relevant to your task. Proceed silently if a domain file
does not exist.
```

If `CLAUDE.md` does not exist, ask whether to create it before writing.

### 6. Done

Tell the user which skills will now read from `.context/`. Mention they can edit domain files directly — re-running this skill is only needed to add domains or reset.

## Reference Map

- `references/domains.md`: domain list, consuming skills, and seed content templates.
