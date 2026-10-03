---
type: regex
pattern: 'safe to (delete|remove)|defer|(delete|remove)[^\n]{0,80}(now|later|in this (PR|change|diff)|follow-?up)'
flags: i
match: contains
---

Says whether to delete it now (in this change) or defer it to a follow-up with a plan.
