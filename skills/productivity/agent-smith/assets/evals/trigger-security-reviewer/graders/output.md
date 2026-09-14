---
type: llm
---

Presents one agent file meant for `.claude/agents/<name>.md`. Its `tools` list is explicit and contains no Edit or Write, and the response ties that to the agent only returning findings. It sets a `model` and gives a one-line reason for the choice. The body opens with a one-sentence role naming the security domain (Next.js, Supabase auth, or row-level security), states that the agent does not apply fixes, and shows the findings format it returns, with each finding carrying a `file:line` location.
