---
type: llm
---

States that the previous reply was wrong: Python strings are immutable, and `s[0] = 'H'` raises a TypeError. Gives a working alternative such as `s = 'H' + s[1:]` or `s.capitalize()`. Never presents the false claim as true. Says nothing about a missing `CONTEXT.md` and does not suggest `/grilling` or any other skill.
