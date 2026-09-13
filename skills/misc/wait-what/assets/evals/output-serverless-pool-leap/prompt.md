---
max_turns: 5
allowed_tools: [Skill, Read, Glob]
---

/wait-what

This was your previous reply — I don't see how you got from the problem to the fix:

> You're exhausting Postgres connections because every cold-started Lambda spins up its own pool. Front the DB with PgBouncer in transaction mode and set the per-function pool to 1.
