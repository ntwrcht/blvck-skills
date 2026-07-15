---
name: skill-smith
description: "Crafts reusable agent skills with invocation design, progressive disclosure, leading words, and bundled resources. Use when the user asks to create a skill, write a skill, build an agent skill, review a SKILL.md, or package skill references, scripts, or examples."
argument-hint: "<skill idea or draft>"
---

# Skill Smith

Craft agent skills that are scoped, predictable, easy to trigger, and packaged with only the resources the work needs.

## When to Use

Use this skill when the user wants to create, write, build, draft, review, or improve an agent skill. It covers new skill folders, `SKILL.md` authoring, invocation design, progressive disclosure, bundled references, utility scripts, examples, and validation checklists.

If the user is asking to install an existing skill, use a skill installation workflow instead. If they are asking for a one-off prompt or instruction block that will not become a reusable skill, keep the output lightweight and do not force the full structure.

## Artifacts

- Produces: `skills/<bucket>/<name>/SKILL.md`
- Consumes: nothing

## Core Rule

Optimize for a skill another agent can load quickly and apply correctly. Keep trigger metadata short, keep the main workflow in `SKILL.md`, and move detailed or rarely needed material into bundled resources with clear pointers.

## Workflow

1. Capture requirements from the conversation before asking questions. Identify the task or domain, expected use cases, output shape, likely tools, references, and any deterministic steps.
2. Ask only for missing details that affect the skill design: scope boundaries, common user phrasing, required scripts, examples, and source materials.
3. Decide invocation type before writing anything else. See **Invocation Design** below.
4. Choose the folder location and resource shape. Default to `SKILL.md` only; add `references/`, `scripts/`, or `assets/` only when they reduce context load or improve reliability.
5. Draft the skill using local repository conventions. Use the description format below, and put detailed activation guidance under `When to Use` or `When Not to Use`.
6. Apply progressive disclosure. Put core behavior in `SKILL.md`; point to specific bundled files for deeper rules, examples, templates, or deterministic helpers.
7. Review the draft against the checklist. Confirm the skill covers intended use cases without overlapping unrelated skills.
8. Run any repository validation scripts requested by local instructions before finishing.

## Invocation Design

Every skill faces one decision first: who reaches it?

- **Model-invoked** — keep the `description` field. The agent fires it autonomously; other skills can reach it. Costs _context load_ on every turn — every description loaded into the window spends tokens and attention. Worth it only when autonomous reach is required.
- **User-invoked** — set `disable-model-invocation: true`. Only the human can fire it by typing its name; zero context load, but costs _cognitive load_ — the human becomes the index. When user-invoked skills multiply, a router skill (one skill that names the others and when to reach for each) cures the cognitive load.

Pick model-invocation only when the agent must fire the skill on its own. If it only ever fires by hand, make it user-invoked.

## Requirement Questions

Ask concise questions when the answer is not already clear:

- What task or domain should this skill cover?
- Which user requests should activate it, and which nearby requests should not?
- What output format should the agent produce?
- Does it need executable scripts, bundled references, templates, assets, or only instructions?
- Are there example inputs, existing workflows, or source materials to preserve?

## Description Format

Use a concise two-sentence YAML description when possible. Target 150–300 characters, stay under 500 characters when practical.

1. First sentence: describe the capability with strong task keywords such as create, write, review, improve, extract, validate, or generate.
2. Second sentence: start with `Use when` and list specific trigger keywords, contexts, file types, tools, outputs, or bundled resources.

If a local repository bans activation phrasing in public descriptions, rewrite the second sentence as neutral scope text with the same keywords. Still keep detailed activation boundaries in `When to Use` and `When Not to Use`.

## Structure Guide

Load `references/skill-structure.md` when drafting or reviewing a full skill. It contains the folder layout, `SKILL.md` template, progressive disclosure rules, split-file guidance, script guidance, and review checklist.

Load `references/principles.md` when a design decision doesn't follow obviously from the rules — it explains the reasoning behind progressive disclosure, leading words, and completion criteria.

## Drafting Rules

- Keep `SKILL.md` focused on the common path. The spec's ceiling is 500 lines; move uncommon detail into `references/` well before that, around 150, when length starts hurting scanning.
- Keep every path a skill names inside its own folder — only that folder is copied on install. Share a reference via `_shared/` and `./scripts/sync-shared-refs.sh`, never a symlink or a path into a sibling skill.
- Write YAML descriptions with enough task keywords to support skill selection.
- Prefer `Use when` as the second sentence unless local instructions ban it.
- Put detailed activation boundaries in the body even when the description includes trigger context.
- Prefer references for long examples, templates, domain rules, schemas, or advanced cases.
- Prefer scripts for deterministic validation, formatting, conversion, or repeated mechanical work.
- Avoid time-sensitive claims unless the skill includes a verification step.
- Do not bundle secrets, private data, or unrelated files.
- Hunt for **leading words** — compact pretrained concepts (e.g. _legwork_, _fog of war_, _tracer bullets_) that collapse a behavioural principle into a single token. A restatement spread across two or three sentences is a candidate. Coin your own only if no pretrained word fits; a made-up word recruits no priors and costs definition tokens.

## Review Checklist

Before finalizing:

- Is the skill name stable, lowercase, and directory-friendly?
- Is invocation type decided — model-invoked (keep `description`) or user-invoked (`disable-model-invocation: true`)?
- Does the description identify the capability without violating local public-description rules?
- Are activation boundaries clear in `When to Use` and, if needed, `When Not to Use`, naming the neighbouring skills they contrast against?
- Does `Artifacts` record what the skill produces and consumes, by key path rather than a hardcoded location?
- Does `Next Step` state an observable approval gate plus both branches — or is its absence explained?
- Does every skill it routes to actually exist, and can the agent reach it? A `disable-model-invocation: true` skill is a dead end for the model.
- Does every path resolve inside the skill folder, with no `../`, no sibling-skill path, and no symlink?
- Is `SKILL.md` under the spec's 500-line ceiling, and split where length hurts scanning?
- Are detailed materials split into clearly named bundled resources?
- Are scripts included only where deterministic execution beats generated instructions?
- Are examples concrete and representative?
- Are local indexes, manifests, or install metadata updated?
- Have required validation scripts been run?
- **Failure modes:** scan for sediment (stale lines that accumulate because removing feels risky), sprawl (length itself — every line live but still too many), duplication (same meaning in two places), no-ops (instructions the agent follows by default), and premature completion risk (steps with completion criteria too vague to resist early exit).

## Next Step

Do not register the new skill until the user has reviewed the draft SKILL.md.

- **If approved:** add entries to the top-level `README.md`, the bucket `README.md`, and `.claude-plugin/plugin.json` (skip this entirely for skills placed in `personal/`, `in-progress/`, or `deprecated/`, which must not appear in those files per this repo's `CLAUDE.md`). Then run `./scripts/sync-shared-refs.sh` if the skill declares a shared reference, and `./scripts/validate-skills.sh` to check frontmatter, links, and catalog sync.
- **If not approved:** revise the draft per feedback before running the validation scripts.
