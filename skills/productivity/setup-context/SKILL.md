---
name: setup-context
description: "Scaffold shared project context files in .context/ and configure the output locations pipeline skills write artifacts to (PRDs, stories, designs, ADRs, and more). Use when onboarding skills to a new or existing repo, when skills lack shared project context, or to relocate where a skill's output gets saved."
disable-model-invocation: true
---

# Setup Context

Scaffold the per-project context files that skills read before doing work, and configure where pipeline skills write their outputs — so every skill operates with shared domain knowledge and predictable file locations instead of asking the same orientation questions, or writing to a path the user didn't choose, every session.

## When to Use

Run once per project before first use of any pipeline skill — `brainstorming`, `grilling`, `write-a-prd`, `write-a-story`, `domain-modeling`, `debug-mantra`, `diagnose`, `scrutinize`, `security-audit`, `ga4-measurement`, `tdd`, `angular-engineer`, `python-engineer`, `strapi-engineer`, `subagent-driven-development`, `post-mortem`, `triage`, `management-talk`, or `stakeholder-update`. Re-run to add domains, reconfigure output locations, migrate an artifact found at an old default location, or reset from scratch.

Do not use to update domain content — edit `.context/*.md` files directly instead. Every skill above also works with no setup at all: it falls back to a sensible default path and asks no orientation questions if `.context/` doesn't exist.

## Artifacts

- Produces: `.context/INDEX.md`, `.context/<domain>.md`, `.context/output-paths.md`; moves existing artifacts found at pre-registry default locations, per user confirmation (see step 5)
- Consumes: repo files for stack detection (`package.json`, `angular.json`, `pyproject.toml`, `git remote`), `references/artifact-paths.md` (the output-location registry and its Migration table)

## Core Rule

Explore first, ask second, write last. Never scaffold a domain file, relocate an output path, or move an existing artifact the user has not explicitly confirmed.

## Process

### 1. Explore

Before asking anything, read what already exists:

- `.context/` — existing domain files, `INDEX.md`, and `output-paths.md`
- `CLAUDE.md` — is there already a `## Context` block?
- `package.json`, `angular.json`, `pyproject.toml`, `Cargo.toml` — detect tech stack
- `git remote -v` — project name and remote

### 2. Present findings

Summarise what was detected and what is missing. If domain files already exist, don't default to a full re-interview — offer the fast path: "Domains are already configured (`project`, `engineering`, ...). Add or update Output locations only, add another domain, or start over?" Only walk the full 9-domain interview again if the user asks to add domains or reset.

### 3. Interview — one domain at a time

Walk through domains in this order: `project` → `engineering` → `git-workflow` → `security` → `analytics` → `adr` → `triage` → `post-mortem` → `learning`.

For each: give a one-line explainer of what it contains and which skills read it, then ask if it applies to this project. Do not present all domains at once.

Load `references/domains.md` for domain descriptions, consuming skills, and seed templates.

### 4. Interview — output locations

A different shape from step 3: one table, one turn, not sequential questions. Load `../../_shared/references/artifact-paths.md` (or the copy under this skill's own `references/` if bundled) and present:

1. The two roots with a one-line explainer each: `docs_root` (default `docs/`) for durable, human-facing artifacts; `context_root` (default `.context/`) for ephemeral, session-scoped working state.
2. The full key → producer → default-path table, noting that most keys are directories with a per-topic slug'd filename (e.g. `docs/prd/<slug>.md`), not a single file — this lets a project accumulate more than one PRD, story set, or design doc over its life without overwriting the last one.
3. Note that `adr-dir` is the same thing as the `adr` domain from step 3 — don't ask about it twice; if the user already answered the `adr` domain question, carry that answer forward as `adr-dir`'s value.

Ask the user to confirm the roots and name any per-key overrides. Anything unmentioned keeps its default — do not require an answer for every row.

### 5. Migrate existing artifacts (pre-existing projects only)

Load the "Migration" table in `../../_shared/references/artifact-paths.md`. It lists keys whose default location changed shape when this registry was introduced (e.g. `prd` moved from the single file `docs/prd.md` to `docs/prd/<slug>.md`), plus one outright bug fix (`adr-dir` moved from `docs/adr/` to `.context/adr/`).

For each key in that table, check whether a file already exists at the **old** default path (or the old path resolved against any root override from step 4). If none do — the common case for any project that hasn't used these skills before — skip this step silently; don't ask about it.

If one or more old-location files exist:

- For directory-shaped keys, propose a slug for each file (derive one from its title/content, or ask if it's ambiguous) and show the exact move: `<old path>` → `<new-default-dir>/<slug>.md`.
- For `adr-dir`, propose moving the whole `docs/adr/` directory to `.context/adr/` — if `.context/adr/` already has entries, merge by ADR number and flag any numbering collision instead of overwriting.
- Show every proposed move as a list and get explicit confirmation before moving anything. Use `git mv` when the project is a git repo, to preserve file history; otherwise a plain move.
- Skip any file the user doesn't confirm — leave it where it is and don't reference it as migrated.

### 6. Confirm drafts

Show draft content for each selected domain file, `INDEX.md`, and `output-paths.md` before writing. Let the user edit.

### 7. Write

- Create `.context/<domain>.md` for each confirmed domain
- Create `.context/output-paths.md`: a flat list of only the roots/keys the user chose to override (omit anything left at its default)
- Create `.context/INDEX.md` listing each file, including `output-paths.md`, with a one-line description
- Add or update `## Context` block in `CLAUDE.md`:

```markdown
## Context

Project context lives in `.context/`. Read `.context/INDEX.md` first to see which domains
are available, then load the ones relevant to your task. Proceed silently if a domain file
does not exist. Output locations for pipeline skills are in `.context/output-paths.md`
(see `skills/_shared/references/artifact-paths.md` for defaults) — proceed silently if it
does not exist.
```

If `CLAUDE.md` does not exist, ask whether to create it before writing.

### 8. Done

Tell the user which skills will now read from `.context/`, which output paths were relocated (if any), and which existing artifacts were migrated (if any), with their new paths. Mention they can edit domain files or `output-paths.md` directly — re-running this skill is only needed to add domains, add another output override, migrate a file found later, or reset.

## Reference Map

- `references/domains.md`: domain list, consuming skills, and seed content templates.
- `../../_shared/references/artifact-paths.md`: output-location registry (roots, keys, defaults, resolution rule).

## Next Step

This skill is done when the user has confirmed the domain and output-location drafts, any proposed migrations, and everything has been written or moved.

- **If approved:** hand off to whichever pipeline skill prompted the setup — this skill exists to unblock that skill, not to be an end in itself.
- **If not approved:** revise the specific draft the user pushed back on and re-confirm; do not write any file the user hasn't explicitly signed off on.
