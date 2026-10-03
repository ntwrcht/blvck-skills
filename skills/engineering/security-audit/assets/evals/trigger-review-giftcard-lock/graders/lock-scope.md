---
type: regex
pattern: '(in-memory|in-process|per-process|process-local|local)[^\n]{0,80}(lock|map|mutex)|(lock|map|mutex)[^\n]{0,120}(replica|instance|process|pod|node)'
flags: i
match: contains
---

Says the in-memory lock only holds within one replica.
