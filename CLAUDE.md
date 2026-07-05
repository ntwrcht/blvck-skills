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

Public skill descriptions should provide enough signal for an agent to choose the skill. This includes the YAML `description` in `SKILL.md`, the top-level `README.md`, and bucket `README.md` files. Prefer a two-sentence description: the first sentence describes the capability, and the second sentence may start with `Use when` to list specific trigger keywords, contexts, file types, tools, or outcomes.

Avoid overly forceful activation phrases in public descriptions, including `ALWAYS use`, `MUST use`, `Trigger when`, `Trigger on`, `proactively whenever`, `no exceptions`, and `Do NOT attempt`.

Put detailed activation boundaries inside the `SKILL.md` body under `When to Use` or `When Not to Use`, with clear boundaries against overlapping skills.

A skill that produces a reviewable artifact and hands off to another skill must end with a `## Next Step` section: a sentence naming the approval gate (if one isn't already stated elsewhere in the body), then two bullets — **If approved**, hand off to the specific next skill and why; **If not approved**, say whether to revise in place, escalate to a named skill, or pause for a specific clarifying question. Thin wrapper skills with no mechanics of their own may instead point to the skill they wrap (e.g. "See `grilling`'s Next Step section"). Skills with no natural next pipeline stage (one-shot installers, tone modifiers, session-boundary tools) don't need this section — say so explicitly if it's not obvious why one is missing. See `skills/_shared/references/artifact-paths.md` for the matching convention on where a skill's output gets written, and `skills/productivity/setup-context/SKILL.md` for how a skill reads a configured path with a documented default.

Before finishing a new skill or changing public skill descriptions, run:

```bash
./scripts/list-skills.sh
./scripts/validate-skill-descriptions.sh
```
