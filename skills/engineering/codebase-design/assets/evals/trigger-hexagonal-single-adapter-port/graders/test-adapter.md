---
type: regex
pattern: '(test|in-memory|fake)[^\n]{0,60}adapter|second adapter|two adapters'
flags: i
match: contains
---

Makes the port conditional on a test adapter existing.
