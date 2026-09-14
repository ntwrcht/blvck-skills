---
type: llm
---

Makes an explicit choice between three separate agents and one agent parameterized by lens, and gives a reason. Gives each lens a one-sentence expert role that names its domain and what it looks for. Sets a read-only `tools` list, since reviewers return findings and do not edit the PRD. States what the caller's delegation prompt must pass in (at least the PRD location, plus the lens if parameterized), because a subagent does not see the parent conversation. Defines the findings format each reviewer returns.
