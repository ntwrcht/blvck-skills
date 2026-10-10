---
type: regex
pattern: 'FOR UPDATE|conditional update|compare-and-(set|swap)|WHERE[^\n]*redeemed|redeemedAt:\s*null|redeemed_?at IS NULL|findOneAndUpdate|ON CONFLICT|unique (index|constraint)'
flags: i
match: contains
---

Gives a fix that holds across replicas: a conditional update, row lock, or unique constraint.
