---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Create a subagent that reviews our TiDB migrations before they merge. Just show me the draft file, don't write it yet.

Context: we already have a `tidb-engineer` skill in the repo that holds our TiDB conventions (online DDL rules, index naming, placement policies). Our current agents in `.claude/agents/`:

- `schema-designer` — designs tables and writes the migration files
- `sql-perf-tuner` — tunes slow queries from the slow-query log
