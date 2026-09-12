---
name: skill-smith
description: "Crafts reusable agent skills from confirmed use cases, with invocation design, progressive disclosure, bundled resources, and evals that prove the skill triggers and delivers the right output. Use when the user asks to create, write, review, improve, or test a skill, upgrade an existing SKILL.md, check whether a skill triggers, or package skill references, scripts, or examples."
argument-hint: "<skill idea or draft>"
---

# Skill Smith

Craft agent skills that are scoped, predictable, easy to trigger, and packaged with only the resources the work needs — and prove each one with evals before it ships.

## When to Use

Covers the whole life of one skill — use-case discovery, `SKILL.md` authoring, invocation design, bundled references and scripts, trigger and output evals, and reviewing or upgrading a skill that already exists — in whichever project it is installed.

## When Not to Use

- **An agent, not a skill.** A skill is knowledge the current agent loads; an agent is a colleague it hands work to. For a subagent or persona with its own tool budget, use `agent-smith`.
- **Installing an existing skill.** That is an installer's job — `npx skills add` or the host's plugin command — with nothing to author.
- **A one-off prompt.** An instruction block used once needs no folder, evals, or catalog entry; write the prompt directly.
- **A change to a skill, not the skill.** A pull request or diff that edits a skill goes to `scrutinize`, which verifies the change; this skill judges the skill itself.

## Artifacts

- Produces: `<skills-root>/<name>/SKILL.md` — the target's existing skills layout, else `.claude/skills/<name>/`
- Produces: `<skills-root>/<name>/assets/evals/` — the confirmed use cases as eval cases, re-runnable after every edit
- Consumes: the target's instructions (`CLAUDE.md`, `AGENTS.md`) and its existing skills, read for conventions, near-misses, and overlap

## Core Rule

Optimize for a skill another agent can load quickly and apply correctly. Keep trigger metadata short, keep the main workflow in `SKILL.md`, and move detail that only some runs need into bundled resources with clear pointers.

## Workflow

1. Read the target project's instructions (`CLAUDE.md`, `AGENTS.md`) and the layout of any skills it already has — they decide where the skill goes, how it registers, and which validators run. Then capture what the conversation already settles: the task or domain, output shape, likely tools, references, and deterministic steps. If the input is a skill that already exists, switch to **Improving an Existing Skill**.
2. Collect and confirm the use cases — see **Use Cases**. The step is done when the user has confirmed every trigger case, every near-miss, and each trigger case's output criteria.
3. Decide the invocation type — see **Invocation Design**. It decides which eval cases exist.
4. Choose the name, the folder, and the resource shape. Place the skill where the target keeps its skills; with none yet, use `.claude/skills/<name>/`, or `~/.claude/skills/<name>/` when the user says it serves all their projects. Start with `SKILL.md` alone; add `references/`, `scripts/`, or `assets/` when a file cuts context load or makes a step deterministic.
5. Write one eval case per confirmed use case into the new skill's `assets/evals/`, per `references/evals.md`. Write them before any prose, so the cases test the use cases rather than the draft.
6. Decide whether the skill should exist — see **Should It Exist**. The step is done when the user has seen the recommendation with its evidence and made the call.
7. Draft the skill: the description per **Description Format**, the body per **Writing the Instructions**, the common path in `SKILL.md` and branch-only detail behind pointers.
8. Run `bash scripts/run-evals.sh <new-skill-dir>` and fix until every case passes — a trigger failure is a description fix, an output failure is an instruction fix. Load `references/evals.md` to read a failure.
9. If the skill enforces a discipline, pressure-test it — see **Testing the Skill**.
10. Review the draft against the **Review Checklist**, then validate: run the validators the target's instructions name, or `bash scripts/check-skill.sh <new-skill-dir>` where they name none.

## Use Cases

The use cases are the skill's contract: the description is written from them, and the evals are built from them. Collect them in one round, in the house style of `references/asking-the-user.md`.

- **Trigger cases.** Ask for three to five requests the user would actually type. Then widen the set and offer the additions for confirmation: rephrasings, other vocabulary for the same job, indirect asks that name the symptom instead of the task, and requests that arrive with a file or tool attached.
- **Near-misses.** Propose requests that sound close but belong elsewhere — a neighbouring skill already in the target folder, or no skill at all. Read the folder's other skill descriptions to find them. Match the number of trigger cases.
- **Output criteria.** For each trigger case, propose what a good output must contain, as properties an observer can check in the final message.

In the same round, ask what the use cases leave open where the answer changes the design: required scripts, source material to preserve, or an output format.

For a user-invoked skill, the model never fires it, so skip trigger cases and near-misses and collect output criteria only; each output case's prompt starts with `/<skill-name>`, the way the user fires it.

## Should It Exist

Decide from evidence, before any prose, whether the target needs this skill at all:

1. **Overlap.** Read every skill description in the target — user-invoked skills too, since their descriptions are not in context. For each confirmed trigger case, name the skill that would fire on it today.
2. **Value.** Run `bash scripts/run-evals.sh <new-skill-dir> --baseline`: the output checks with no skill loaded. A case plain Claude already passes is a job the skill does not have.
3. **Whole job.** Check whether the skill finishes a job for the user or is one stage that always needs another skill.

| Evidence | Recommend |
|---|---|
| No overlap, and the baseline fails | **Create** — continue to drafting |
| One existing skill takes most trigger cases | **Extend** it — move these eval cases into its `assets/evals/` and follow **Improving an Existing Skill** |
| Two skills split the trigger cases, or the new skill is only a stage | **Merge**, or redraw the boundary between them |
| The baseline passes every case | **Don't build** — show the baseline outputs as proof |

Give the user the recommendation with its evidence; the call is theirs. When they build against it, carry on and name the reason in your final report.

## Improving an Existing Skill

When the input is a skill that already exists, follow `references/reviewing.md` in place of steps 2–9, then finish with step 10:

1. Read the skill and summarize it for the user.
2. Pin its current behaviour with evals; that score is the floor every change keeps.
3. Find, rank, and report the findings, each with evidence.
4. Fix one finding at a time with approval, re-running the evals after each; batch only when the user asks.
5. Close with a before/after eval table.

## Invocation Design

Every skill faces one decision first: who reaches it?

- **Model-invoked** — keep the `description` field. The agent fires it autonomously, and other skills can reach it. It costs _context load_ on every turn, since every loaded description spends tokens and attention.
- **User-invoked** — set `disable-model-invocation: true`. Only the human fires it, by typing its name. It costs no context but _cognitive load_ — the human becomes the index. When user-invoked skills multiply, a router skill that names the others and when to reach for each cures that load.

Make a skill model-invoked only when the agent must fire it on its own; make every hand-fired skill user-invoked.

## Description Format

The description is the only part of a skill the agent sees before choosing it, so it carries every trigger.

- Write two sentences, 150–300 characters — the spec's hard limit is 1,024.
- Open the first sentence with a third-person capability verb and strong task keywords: "Reviews pull requests for…", not "Review…" or "I can help…". The description is injected into the system prompt, where a mixed point of view degrades selection.
- Start the second sentence with `Use when`, then list the trigger keywords, contexts, file types, and tools from the confirmed trigger cases, the most common first.
- Keep the wording plain: all-caps commands to use the skill make current models fire it where it does not belong.
- Follow the target repository's description rules where it has them, keeping the same keywords in whatever form it requires.
- Put every trigger here, because the body loads only after the skill fires. Keep the body's `When to Use` to scope, and use `When Not to Use` to separate the skill from its neighbours once loaded. Leave `when_to_use` out of the frontmatter — it is a Claude Code extension outside the spec, and other agents ignore it.

## Writing the Instructions

Every sentence in a skill names an action the agent can take or a fact it needs. Write each to these rules; `references/writing-instructions.md` holds a before/after and the Anthropic source for every one.

**What to write**

1. Keep a sentence only if removing it would cause a mistake — the model already knows the rest.
2. Match specificity to fragility: the exact command for a fragile step, a goal plus a heuristic for judgment work. Default to the general form.
3. Give one default with an escape hatch in place of a menu of options.

**How to phrase**

4. Open with an imperative verb.
5. Give the reason in one clause in place of a MUST, so the agent can generalize.
6. Say what to do and name the alternative; a bare prohibition pulls the banned behaviour into context.
7. Set a concrete bar — a number or a checkable property — in place of an adjective.
8. State the scope explicitly; the agent applies an instruction only where it is stated.
9. Write a qualifier ("be conservative", "only if sure") only for its effect — every qualifier is obeyed literally.
10. Use one term per concept; a synonym reads as a new thing.

**Structure**

11. Number the steps where order matters, and write each decision point as an `If …, …` branch.
12. Show the format with an example or a template.
13. Reserve emphasis for the one line an eval shows being skipped.

## Reference Map

Load `references/reviewing.md` when the input is an existing skill — the six review steps, the finding order, the report table, and the regression rule.

Load `references/writing-instructions.md` when drafting or reviewing a skill's prose — a before/after and a source for each of the thirteen rules, plus a worked rewrite.

Load `references/skill-structure.md` when laying out a skill folder — the layout, the `SKILL.md` template, portability and shared references, the `Artifacts` and `Next Step` conventions, and when to add references, scripts, or assets.

Load `references/evals.md` when writing eval cases, running them, or reading a failure — case layout, grader templates, what `scripts/run-evals.sh` does, and a symptom-to-fix table.

Load `references/asking-the-user.md` before the use-case round — the house style every question round follows.

Load `references/testing-skills.md` when the skill enforces a discipline and needs a pressure test before it ships.

Load `references/principles.md` when a design decision does not follow from the rules — the reasoning behind progressive disclosure, leading words, completion criteria, single source of truth and caching, steering by the positive, and the four failure modes.

## Testing the Skill

Evals prove the skill fires for its use cases and delivers the output. A pressure test proves something else: that the skill holds a discipline — a rule with a compliance cost — when an agent is tempted to skip it. A skill that enforces a rule needs both; a pure reference skill has no rule to violate and needs evals only.

Load `references/testing-skills.md` to run one: the baseline without the skill, the pressure-scenario formats, and the four edits that close a loophole.

## Drafting Rules

- Keep `SKILL.md` on the common path; past about 150 lines, move branch-only detail into `references/`. The spec's ceiling is 500.
- Keep every path a skill names inside its own folder — only that folder is copied on install. To share a reference, copy it into each skill's `references/`, or use the target repo's sync tool if it has one; a symlink or a path into a sibling skill breaks on install.
- Put long examples, templates, domain rules, and schemas in `references/`; put deterministic validation, formatting, and conversion in `scripts/`.
- Leave out time-sensitive claims unless the skill verifies them, and bundle no secrets, private data, or unrelated files.
- Hunt for **leading words**: one pretrained term (_legwork_, _fog of war_) in place of a principle restated across several sentences.
- Keep each meaning in a **single source of truth**, and leave to the environment what one lookup finds — `package.json`, config files, `--help`. Cache only what looking cannot find: the unwritten convention, the reason behind a choice, the gotcha.
- Co-locate a concept's definition, rules, and caveats under one heading.

`references/principles.md` holds the reasoning behind the last three.

## Review Checklist

Before finalizing:

- Does `name` match the folder — lowercase letters, digits, and single hyphens, at most 64 characters?
- Is the invocation type decided — model-invoked, or `disable-model-invocation: true`?
- Does the description follow **Description Format** and any local description rules?
- Do `When to Use` and `When Not to Use` name the neighbouring skills they contrast against?
- Did the user see the **Should It Exist** recommendation and its evidence before drafting — and is any override named in the report?
- Does every confirmed use case have an eval case, with as many near-misses as trigger cases, and did the latest `scripts/run-evals.sh` run pass?
- Does the skill carry the sections the target's conventions require — in a repo that chains skills, an `Artifacts` record and a `Next Step` with an observable approval gate plus both branches?
- Does every skill it routes to exist, and can the agent reach it? A `disable-model-invocation: true` skill is a dead end for the model. In `Next Step`, a bare `` `name` `` is a route the model takes and must be model-invocable; `/name` tells the user to run it.
- Does every path resolve inside the skill folder — no `../`, no sibling-skill path, no symlink?
- Does each bundled file earn its place: references for branch-only detail, scripts where deterministic execution beats generated steps, examples concrete and representative?
- Is the skill registered where the target's instructions say — catalog, manifest, shared-reference sync — or does the target need no registration?
- If the skill enforces a discipline, did an agent fail a pressure scenario without it first — and does every rationalization it counters come from that observed failure?
- Sentence pass: does every sentence name an action or a needed fact, and hold to **Writing the Instructions** — above all rules 1, 5, 7, and 9?
- Does anything restate what `package.json`, a config file, the directory layout, or `--help` already says?
- Read the draft for its **silences**: each decision it leaves to the agent's priors is either filled or a deliberate open branch.
- Is the draft free of the four failure modes — sediment, sprawl, duplication, no-ops — and does every step have a completion criterion sharp enough to resist early exit? `references/principles.md` holds the diagnostic and cure for each.

## Next Step

Register the new skill once the user has reviewed the draft SKILL.md and its latest eval run — every case passing, or each remaining failure named and accepted by the user.

- **If approved:** register the skill the way the target's instructions say — catalog entries, manifests, shared-reference sync — and run the validators they name, or `bash scripts/check-skill.sh <new-skill-dir>` where they name none. A skill in `.claude/skills/` with no catalog to join is live from the next session.
- **If not approved:** revise the draft per the feedback, re-run the evals, then validate again.
