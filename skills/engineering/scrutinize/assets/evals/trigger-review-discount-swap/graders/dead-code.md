---
type: regex
pattern: '(legacyDiscount|legacy\.ts)[\s\S]*(dead|unused|no (remaining|other|live) (caller|consumer|reference))|(dead|unused)[\s\S]*(legacyDiscount|legacy\.ts)'
flags: i
match: contains
---

Names legacyDiscount / legacy.ts as dead code.
