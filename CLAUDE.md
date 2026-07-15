Skills are organized into bucket folders under `skills/`:

- `engineering/` — daily code work
- `productivity/` — daily non-code workflow tools
- `misc/` — situational, kept around but rarely used
- `personal/` — tied to the maintainer's local setup, not shipped
- `in-progress/` — drafts not yet ready to ship
- `deprecated/` — no longer used

Every skill in `engineering/`, `productivity/`, or `misc/` must have a reference in the top-level `README.md` and an entry in `.claude-plugin/plugin.json`. Skills in `personal/`, `in-progress/`, and `deprecated/` must not appear in either.

Each skill entry in the top-level `README.md` must link the skill name to its `SKILL.md`.

Each bucket folder has a `README.md` that lists every skill in the bucket with a one-line description, with the skill name linked to its `SKILL.md`.

Public skill descriptions should provide enough signal for an agent to choose the skill. This includes the YAML `description` in `SKILL.md`, the top-level `README.md`, and bucket `README.md` files, which must all carry the same text — the catalog describes what ships. Prefer a two-sentence description: the first sentence describes the capability, and the second sentence may start with `Use when` to list specific trigger keywords, contexts, file types, tools, or outcomes.

Write descriptions in the third person ("Builds, modifies, and reviews…", not "Build, modify, and review…"). The description is injected into the system prompt, where a mixed point of view degrades skill selection.

Avoid overly forceful activation phrases in public descriptions, including `ALWAYS use`, `MUST use`, `Trigger when`, `Trigger on`, `proactively whenever`, `no exceptions`, and `Do NOT attempt`.

Put detailed activation boundaries inside the `SKILL.md` body under `When to Use` or `When Not to Use`, with clear boundaries against overlapping skills.

A skill that produces a reviewable artifact and hands off to another skill must end with a `## Next Step` section: a sentence naming the approval gate (if one isn't already stated elsewhere in the body), then two bullets — **If approved**, hand off to the specific next skill and why; **If not approved**, say whether to revise in place, escalate to a named skill, or pause for a specific clarifying question. Thin wrapper skills with no mechanics of their own may instead point to the skill they wrap (e.g. "See `grilling`'s Next Step section"). Skills with no natural next pipeline stage (one-shot installers, tone modifiers, session-boundary tools) don't need this section — say so explicitly if it's not obvious why one is missing. See `skills/_shared/references/artifact-paths.md` for the matching convention on where a skill's output gets written, and `skills/productivity/setup-context/SKILL.md` for how a skill reads a configured path with a documented default.

Skills follow the [Agent Skills spec](https://agentskills.io/specification): `name` matches the folder, is 1-64 lowercase alphanumeric characters with single internal hyphens, and never contains `anthropic` or `claude`; `description` is at most 1024 characters. `argument-hint` and `disable-model-invocation` are Claude Code extensions outside the spec's field list and are deliberately kept — `scripts/validate-spec.sh` tolerates exactly those two and rejects any other unknown field.

## Portability

A skill folder is copied out of this repo on its own — by the installer, by `claude --plugin-dir`, or by `npx skills add`. Only that folder travels, so **every path a `SKILL.md` names must resolve inside its own folder**. No `../`, no path into a sibling skill, no absolute path, and no symlinks: symlinked references do not survive the copy.

To share a reference across skills, add it to `skills/_shared/references/`, map the skill to it in `get_shared_refs()` in `scripts/_skills-lib.sh`, and run `./scripts/sync-shared-refs.sh`. That writes a real, committed copy into the skill's own `references/`. Edit only the canonical file in `_shared/`; the copies carry a generated header and are overwritten.

When routing to another skill, check the agent can reach it: a `disable-model-invocation: true` skill cannot be invoked by the model, so route the model to the engine (`grilling`), not the user entry point (`grill-me`).

Before finishing a new skill or changing public skill descriptions, run:

```bash
./scripts/sync-shared-refs.sh --check   # shared references materialized and in sync
./scripts/validate-skills.sh            # frontmatter, links, portability, catalog sync
./scripts/validate-spec.sh              # official Agent Skills spec validator
./scripts/list-skills.sh
```

CI runs these on every push and pull request, plus `./scripts/test-validate-skills.sh`, which breaks one rule at a time in a scratch copy to prove the validator still rejects what it should. Add a case there whenever you add a rule — this repo once shipped a check that silently passed for months because nobody had watched it fail.
