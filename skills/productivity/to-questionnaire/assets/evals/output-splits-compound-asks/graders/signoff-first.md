---
type: regex
pattern: '(?<![\s\S]*^### [\s\S]*)^### [^\n]*(?:approv|sign)'
flags: mi
match: contains
---

The first question heading asks about approval or sign-off, the ask the user said matters most.
