---
type: regex
pattern: '^### [^\n]*\n(?:(?!>)[^\n]*\n){4}'
flags: m
match: not_contains
---

Every question heading has a `>` answer stub within its next four lines, leaving room for one "Why this matters" note.
