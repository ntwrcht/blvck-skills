---
type: regex
pattern: 'race|TOCTOU|check-then-act|concurren|double[- ]spend|atomic'
flags: i
match: contains
---

Flags the read-check-then-deduct balance update as a race.
