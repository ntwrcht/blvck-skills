<!-- portability-exempt: teaches path rules, so it quotes broken paths as anti-pattern examples. -->

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

A skill folder is copied on its own — by `npx skills add`, by `claude --plugin-dir`, or by a repo's own installer. Only that folder travels. So every path a `SKILL.md` names must resolve inside the folder:

- **Good:** `references/domain-rules.md`, `scripts/helper.sh`
- **Broken once installed:** `../../shared/references/style.md`, `skills/other-skill/references/domains.md`, or any absolute path

To reference another skill, name it (`` `other-skill` ``) rather than reaching into its folder. `scripts/check-skill.sh` fails on any path that escapes the skill folder.

## Sharing a Reference Across Skills

Copy the file into each skill's `references/`, or use the target repo's sync tool if it has one. A symlink or a path into a sibling skill breaks on install.

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

Scope only — what the skill covers. Every trigger phrase belongs in the description, which the agent reads before choosing; this body loads only after.

## When Not to Use

Name the neighbouring skills and contrast them. Prefer a contrast over a redirect:
"X answers <question>; this skill answers <different question>."

## Artifacts

- Produces: <what this skill writes, and where — by the key the target repo configures, if it keeps an output registry>
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

Sections in this template are a convention, not spec requirements. Follow the target repo's own section rules where it has them; `Artifacts` and `Next Step` earn their place in any repo that chains skills into a pipeline.

## Artifacts and Next Step

**Artifacts** records what the skill reads and writes, so a pipeline of skills can hand work along without re-deriving where things live. Where the repo keeps an output registry, name the configured key and its default rather than hardcoding a path.

**Next Step** is required of any skill that produces a reviewable artifact and hands off. It needs an approval gate plus both branches:

- The gate should be an **observable event**, not a feeling: "the user has run the prototype and stated the answer." Compare a gate that cannot be checked: "when the design feels right."
- **If approved** names the next skill and why it follows.
- **If not approved** says which: revise in place, escalate to a named skill, or pause on a specific question.

A thin wrapper may point at the skill it wraps ("See `<engine-skill>`'s Next Step"). A skill with no natural next stage — a one-shot installer, a tone modifier, a session-boundary tool — needs none, and says so with the reason.

Only name a skill the agent can actually reach: a `disable-model-invocation: true` skill cannot be invoked by the model, so route the model to a model-invocable engine skill, not a user entry point. Telling the user to run `/<entry-skill>` is fine; telling the model to use it is a dead end.

The two cases are distinguished by form. A bare `` `name` `` is a route the model takes itself and must land on a model-invocable skill; `/name` addresses the human and may name any skill. Repos that validate this key off exactly that difference.

## Progressive Disclosure

Skills should load in layers:

1. Metadata: the name and description are always visible to the agent.
2. `SKILL.md`: loaded after the skill is selected.
3. Bundled resources: loaded only when the current task needs them.

Keep the main file focused on the common workflow. The spec's limit is 500 lines (roughly 5k tokens) for the `SKILL.md` body — that is the hard ceiling. Well before it, length stops being a budget problem and becomes a scanning problem: past roughly 150 lines, move uncommon detail into `references/`.

Split on **what the agent needs when**, not to hit a number. A 120-line skill whose every line is load-bearing beats a 70-line one that hides the workflow in a reference file the agent never opens.

## Co-location

Progressive disclosure decides *how far down* a piece of content sits. Co-location decides *what sits beside it* once there.

Keep a concept's definition, rules, and caveats under one heading rather than scattered across the file, so reading one part brings its neighbours with it. The test: the skill should read like documentation written for the agent. Grouped material reads that way; scattered material does not.

Scattering is not duplication. Duplication repeats one meaning in two places; scattering fragments one meaning across many. The cure for duplication is deletion, the cure for scattering is grouping.

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

Add `assets/` files when the skill needs static templates, fixtures, visual references, or reusable starter files. Keep assets directly relevant to the skill output. A skill's eval cases live in `assets/evals/` too.
