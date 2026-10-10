---
type: llm
---

Keeps the same diagnosis and the same fix (PgBouncer in transaction mode, per-function pool size of 1). Fills in the missing step: each function instance opens its own connections, instances multiply under load, and Postgres accepts only a fixed number of connections. Explains what PgBouncer is and what transaction mode means in plain words. No sentence is longer than 25 words. Says nothing about a missing `CONTEXT.md` and does not suggest `/grilling` or any other skill.
