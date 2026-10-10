---
max_turns: 8
allowed_tools: [Skill, Read, Glob, Grep]
---

Poke holes in this plan before I take it to the team:

> **Move sessions to Redis.** Login p95 is 900ms and the sessions table in Postgres has 40M rows. Stand up a 3-node Redis cluster, dual-write sessions to Postgres and Redis for two weeks, then cut reads over to Redis and drop the table. No profiling done yet; we assume the session lookup is the slow part.
