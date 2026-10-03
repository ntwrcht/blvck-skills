---
type: regex
pattern: 'FOR UPDATE|conditional update|compare-and-(set|swap)|WHERE[^\n]*redeemed|atomic(ally)? (update|mark|flip)|findOneAndUpdate|updateOne\([^)]*redeemed'
flags: i
match: contains
---

Gives an atomic fix for the race, not just "add a lock".
