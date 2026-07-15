# Skill Structure Reference

Use this reference while drafting, reviewing, or refactoring an agent skill.

## Standard Layout

```text
skill-name/
|-- SKILL.md              # Required main instructions
|-- references/           # Optional detailed docs loaded only as needed
|   |-- examples.md
|   `-- domain-rules.md
|-- scripts/              # Optional deterministic utilities
|   `-- helper.sh
`-- assets/               # Optional templates, static files, images, or fixtures
    `-- template.ext
```

Keep the folder name stable, lowercase, and easy to type. Prefer hyphenated names such as `skill-smith`.

The spec requires the `name` field to match this folder name exactly: 1-64 characters, lowercase letters, digits, and single internal hyphens, and it must not contain the reserved words `anthropic` or `claude`.

## Everything a Skill Needs, It Carries

A skill folder is copied out of this repo on its own — by `install-skills.sh`, by `claude --plugin-dir`, or by `npx skills add`. Only that folder travels. So every path a `SKILL.md` names must resolve inside the folder:

- **Good:** `references/artifact-paths.md`, `scripts/helper.sh`
- **Broken once installed:** `../../_shared/references/artifact-paths.md`, `skills/productivity/setup-context/references/domains.md`, or any absolute path

To reference another skill, name it (`` `setup-context` ``) rather than reaching into its folder. `./scripts/validate-skills.sh` fails on any path that escapes the skill root.

## Sharing a Reference Across Skills

Common material lives in `skills/_shared/references/`. Do not symlink it and do not hand-copy it:

1. Add the file to `skills/_shared/references/`.
2. Map the skill to it in `get_shared_refs()` in `scripts/_skills-lib.sh`.
3. Run `./scripts/sync-shared-refs.sh`, which writes a real copy into the skill's own `references/` and commits it.

Edit only the canonical file in `_shared/`; the copies carry a generated header and are overwritten. `./scripts/sync-shared-refs.sh --check` fails if a copy drifts.

## SKILL.md Template

```md
---
name: skill-name
description: "Capability-focused summary for the skill. Use when the user asks for the specific task, context, file type, tool, or outcome this skill covers."
argument-hint: "<optional user input hint>"
---

# Skill Name

One short paragraph describing the reusable capability.

## When to Use

Describe activation boundaries, common user phrases, related contexts, and exclusions.

## When Not to Use

Name the neighbouring skills and contrast them. Prefer a contrast over a redirect:
"X answers <question>; this skill answers <different question>."

## Artifacts

- Produces: <what this skill writes, and at which key path — see `references/artifact-paths.md`>
- Consumes: <the context files and upstream artifacts it reads>

## Core Rule

State the main judgment the agent should optimize for.

## Workflow

1. Ingest the request and existing context.
2. Make the smallest useful decision or artifact.
3. Use references or scripts only when needed.
4. Validate the result before finishing.

## Reference Map

- `references/example.md`: load for advanced cases.

## Review Checklist

- Check the behavior the skill is meant to improve.
- Check the output format.
- Check local repository conventions.

## Next Step

<One sentence naming the approval gate — an observable event, not a vibe.>

- **If approved:** hand off to `<named skill>` and say why.
- **If not approved:** revise in place, escalate to `<named skill>`, or pause on a specific question.
```

Sections in this template are the repo's de facto convention, not spec requirements. `Artifacts` and `Next Step` are the two that `CLAUDE.md` actually enforces.

## Artifacts and Next Step

**Artifacts** records what the skill reads and writes, so a pipeline of skills can hand work along without re-deriving where things live. Name the key path from `references/artifact-paths.md` and its default, rather than hardcoding a path.

**Next Step** is required of any skill that produces a reviewable artifact and hands off. It needs an approval gate plus both branches:

- The gate should be an **observable event**, not a feeling. `prototype` is the model: "the user has driven it and stated the answer." Compare a gate that cannot be checked: "when the design feels right."
- **If approved** names the next skill and why it follows.
- **If not approved** says which: revise in place, escalate to a named skill, or pause on a specific question.

A thin wrapper may point at the skill it wraps ("See `grilling`'s Next Step"). A skill with no natural next stage — a one-shot installer, a tone modifier, a session-boundary tool — does not need one, but should say why not if it is not obvious.

Only name a skill the agent can actually reach: a `disable-model-invocation: true` skill cannot be invoked by the model, so route the model to the engine (`grilling`), not the user entry point (`grill-me`). Telling the user to run `/grill-me` is fine; telling the model to use it is a dead end.

## Progressive Disclosure

Skills should load in layers:

1. Metadata: the name and description are always visible to the agent.
2. `SKILL.md`: loaded after the skill is selected.
3. Bundled resources: loaded only when the current task needs them.

Keep the main file focused on the common workflow. The spec's limit is 500 lines (roughly 5k tokens) for the `SKILL.md` body — that is the hard ceiling. Well before it, length stops being a budget problem and becomes a scanning problem: past roughly 150 lines, move uncommon detail into `references/`.

Split on **what the agent needs when**, not to hit a number. A 120-line skill whose every line is load-bearing beats a 70-line one that hides the workflow in a reference file the agent never opens.

## Description Guidance

Respect local repository rules first. Prefer enough trigger context for the agent to select the skill, unless the repository requires neutral public descriptions.

Use a concise two-sentence pattern when possible. Target 150-300 characters, stay under 500 characters when practical, and use a platform limit such as 1024 characters only when the skill needs unusually specific trigger coverage.

1. First sentence: describe the capability with strong task keywords.
2. Second sentence: start with `Use when` and list specific trigger keywords, contexts, file types, tools, outputs, or bundled resources.

Default description style:

```text
Craft reusable agent skills with invocation design, progressive disclosure, leading words, and bundled resources. Use when the user asks to create a skill, write a skill, build an agent skill, review a SKILL.md, or package skill references, scripts, or examples.
```

If a repository bans activation phrasing in public descriptions, rewrite the second sentence as neutral scope text with the same keywords. Keep descriptions under the platform limit.

## When to Add References

Add `references/` files when:

- `SKILL.md` is getting long.
- The content has distinct domains, frameworks, schemas, or output templates.
- Advanced details are useful but rarely needed.
- Examples are numerous enough to distract from the main workflow.

Reference files should be one level deep when possible and named by topic.

## When to Add Scripts

Add `scripts/` files when:

- The operation is deterministic.
- The agent would otherwise regenerate the same code repeatedly.
- Errors need explicit handling.
- Validation, formatting, conversion, or extraction can be automated.

Make scripts small, documented by usage comments, and safe for the expected workspace. Do not include secrets or destructive defaults.

## When to Add Assets

Add `assets/` files when the skill needs static templates, fixtures, visual references, or reusable starter files. Keep assets directly relevant to the skill output.

## Review Checklist

- Folder name and YAML `name` match.
- Invocation type decided — model-invoked (keep `description`) or user-invoked (`disable-model-invocation: true`).
- Public description follows local conventions and gives enough trigger context for skill selection.
- Activation guidance has clear inclusions and exclusions.
- `SKILL.md` covers the common path without excessive detail.
- References are named and linked from `SKILL.md`.
- Scripts are deterministic and safe.
- Examples cover realistic user prompts.
- Required README, manifest, or install metadata entries are updated.
- Required validation commands pass.
- Main `SKILL.md` is under the spec's 500-line ceiling, and split where length hurts scanning.
- `Artifacts` and `Next Step` are present, or their absence is explained.
- Every path resolves inside the skill folder — no `../`, no sibling-skill path, no symlink.
- Every skill named in a handoff exists and is reachable by whoever is being told to reach it.
- Failure modes checked: sediment, sprawl, duplication, no-ops, premature completion risk.
