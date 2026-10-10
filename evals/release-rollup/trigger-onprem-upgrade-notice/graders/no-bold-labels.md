---
type: regex
pattern: '^\s*(?:[-*]|\d+\.)\s+\*\*[^*\n]{1,40}(?::\*\*|\*\*:)'
flags: m
match: not_contains
---

No list item opens with a bold label and a colon (humanizer §19).
