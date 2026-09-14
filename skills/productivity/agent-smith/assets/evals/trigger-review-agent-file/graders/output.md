---
type: llm
---

Points out that the file has no `tools` field, so the agent inherits every tool including Edit and Write, which contradicts "You do not rewrite the document", and proposes an explicit read-only list. Points out that no `model` is set. Says the description does not state what comes back to the caller, and proposes a rewrite that does. Notices that the lens arrives only through the caller's prompt and says the file should state what the caller must pass in (the lens and the document). Keeps the per-lens expert framing as a strength.
