---
type: regex
pattern: 'race|TOCTOU|check-then-act|concurren|double[- ]redeem|redeem(ed)? (it )?(twice|multiple)'
flags: i
match: contains
---

Flags the read-check-then-mark redemption as a race.
