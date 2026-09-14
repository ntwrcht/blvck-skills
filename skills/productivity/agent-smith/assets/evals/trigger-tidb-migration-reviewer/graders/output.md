---
type: llm
---

Presents one agent file meant for `.claude/agents/<name>.md`, with no second "canonical" copy under a top-level `agents/` folder. Its frontmatter has a lowercase hyphenated `name`; a `description` that says when to delegate and what comes back; an explicit `tools` list with no Edit or Write; a `model` value; and a `skills` list that includes `tidb-engineer`. The body opens with a one-sentence role naming TiDB migration expertise, names `schema-designer` as the owner of writing or fixing migrations, and shows an example of the report it returns.
