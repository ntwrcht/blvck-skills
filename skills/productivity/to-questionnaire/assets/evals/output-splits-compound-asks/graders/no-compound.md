---
type: regex
pattern: '^### [^\n]*(?:,\s*(?:and|or)\b|\b(?:and|or)\s+(?:who|what|when|where|why|how|which|whether|is|are|do|does|can|could|should|would|will)\b)'
flags: mi
match: not_contains
---

No question heading joins a second ask: no "and" or "or" after a comma or before a question word. "Between now and the freeze" stays allowed.
