---
type: regex
pattern: '\bdeep|small(er)? interface|\b(one|single) (module|operation|interface)\b|(merge|fold|collapse|combine)[^\n]{0,40}\b(into|behind)\b'
flags: i
match: contains
---

Recommends a deep module — the small classes merged behind one small interface — in that word or plainly.
