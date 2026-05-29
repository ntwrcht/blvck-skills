Skills are organized into bucket folders under `skills/`:

- `engineering/` — daily code work
- `productivity/` — daily non-code workflow tools
- `misc/` — kept around but rarely used
- `personal/` — tied to my own setup, not promoted
- `in-progress/` — drafts not yet ready to ship
- `deprecated/` — no longer used

Every skill in `engineering/`, `productivity/`, or `misc/` must have a reference in the top-level `README.md` and an entry in `.claude-plugin/plugin.json`. Skills in `personal/`, `in-progress/`, and `deprecated/` must not appear in either.

Each skill entry in the top-level `README.md` must link the skill name to its `SKILL.md`.

Each bucket folder has a `README.md` that lists every skill in the bucket with a one-line description, with the skill name linked to its `SKILL.md`.

Public skill descriptions must stay neutral and inventory-like. This includes the YAML `description` in `SKILL.md`, the top-level `README.md`, and bucket `README.md` files. Describe scope only; do not put activation policy in public descriptions.

Avoid activation-heavy phrases in public descriptions, including `ALWAYS use`, `MUST use`, `Use when`, `Trigger when`, `Trigger on`, `proactively whenever`, `no exceptions`, and `Do NOT attempt`.

Put activation guidance inside the `SKILL.md` body under `When to Use` or `When Not to Use`, with clear boundaries against overlapping skills.

Before finishing a new skill or changing public skill descriptions, run:

```bash
./scripts/list-skills.sh
./scripts/validate-skill-descriptions.sh
```
