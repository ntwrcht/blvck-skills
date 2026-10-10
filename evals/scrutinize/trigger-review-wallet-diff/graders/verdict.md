---
type: regex
pattern: 'verdict[^\n]*(fix then ship|rework|reject)'
flags: i
match: contains
---

Closes with a verdict that does not let the race ship as-is.
