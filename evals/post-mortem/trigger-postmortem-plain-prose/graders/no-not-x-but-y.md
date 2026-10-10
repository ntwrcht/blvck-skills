---
type: regex
pattern: '\bnot (?:just|only|merely|simply)\b[^.\n]{0,80}\bbut\b|\b(?:it|this|that)(?:''s| is) not [^.,;\n]{1,60}[,;] (?:it|this|that)(?:''s| is)\b'
flags: i
match: not_contains
---

No "not just X but Y" or "it's not X, it's Y" contrast (humanizer §1).
