---
type: regex
pattern: '^\s*(?:[-*]|\d+\.)\s+\*\*(?!North Star|L1 metrics|L2 metrics|Guardrails)[^*\n]{1,40}(?::\*\*|\*\*:)'
flags: mi
match: not_contains
---

No list item opens with a bold label the PRD template does not define (humanizer §19). The template's own North Star, L1 metrics, L2 metrics, and Guardrails labels stay allowed.
