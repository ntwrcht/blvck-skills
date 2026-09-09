# Query Tuning

A rigorous loop from symptom to verified fix. Statistics first, plan second, hints last. `EXPLAIN ANALYZE` is the ground truth; a plausible story is not.

## Workflow

1. **Capture the plan and clues.** `EXPLAIN ANALYZE <query>`. Note `estRows` against `actRows`, the operator with the longest wall time, and memory or disk in `execution info`. Run `SHOW GLOBAL BINDINGS` to learn whether a binding is already shaping the plan. For a hard case, `PLAN REPLAYER DUMP EXPLAIN ANALYZE <query>;` exports version, config, schema, stats, and plan as one ZIP.
2. **Check statistics.** `SHOW STATS_HEALTHY WHERE Db_name = '<db>' AND Table_name = '<table>';`. Below 80, or a large estimate gap: `ANALYZE TABLE <table>;` and re-run step 1. Most investigations end here. See `references/statistics.md`.
3. **Match the bottleneck pattern.**

   | Plan shows | Load |
   |---|---|
   | Bad join order or algorithm | `references/join-strategies.md` |
   | `IndexJoin` with the wrong probe index | `references/join-strategies.md`, `references/index-selection.md` |
   | `Apply`, slow `EXISTS` / `IN` | `references/subquery-optimization.md` |
   | `TableFullScan`, missing or wrong index | `references/index-selection.md` |
   | Good stats, still a bad plan | `references/optimizer-hints.md`, `references/session-variables.md` |
   | Plans change after restart | `references/statistics.md` (startup section) |
   | Heavy scan that belongs on columnar storage | `READ_FROM_STORAGE(TIFLASH[t])` and a TiFlash replica |

4. **Apply the least invasive fix.** Refresh stats, then add or fix an index, then a SQL binding, then a hint, then a session variable. A binding fixes production without a deploy:

   ```sql
   CREATE GLOBAL BINDING FOR <stmt> USING <hinted stmt>;
   ```

   Remove bindings with `DROP GLOBAL BINDING`, which marks the row deleted so every TiDB instance drops it from cache. Deleting rows from `mysql.bind_info` directly skips that step and leaves stale cache entries that survive `ADMIN RELOAD BINDINGS`; only a TiDB restart clears them (PingCAP field experience, vendored from upstream).
5. **Verify.** `EXPLAIN ANALYZE` again. Confirm `actRows` and time improved at the operator that was the bottleneck. Comment any hint with the reason.

## Clue sources

Slow queries in the last hour:

```sql
SELECT query, query_time, process_time, wait_time, mem_max, plan_digest
FROM information_schema.slow_query
WHERE time > NOW() - INTERVAL 1 HOUR
ORDER BY query_time DESC LIMIT 10;
```

Heaviest statements by total latency:

```sql
SELECT digest_text, sum_latency, avg_latency, exec_count, avg_mem, avg_processed_keys
FROM information_schema.statements_summary
WHERE digest_text IS NOT NULL
ORDER BY sum_latency DESC LIMIT 10;
```

Hot regions (write or read hotspots):

```sql
SELECT db_name, table_name, type, flow_bytes, max_hot_degree
FROM information_schema.tidb_hot_regions
ORDER BY flow_bytes DESC LIMIT 5;
```

Whether the last statement used a binding: `SELECT @@last_plan_from_binding;`

`scripts/collect-diag.sql` runs the full baseline set in one go. TiDB Cloud exposes the same data through Diagnosis, SQL Statements, and Slow Query pages; the Key Visualizer shows hotspots as bright horizontal bands.

## Hotspots are not plan problems

A slow write path with a healthy plan is usually a hotspot: sequential keys landing on one Region. `tidb_hot_regions` and the Key Visualizer confirm it; the fix is schema-level (`AUTO_RANDOM`, `SHARD_ROW_ID_BITS`, a non-monotonic leading index column), not a hint. See `references/schema-design.md`.

## High CPU on TiDB nodes

Do not assume user SQL. Compare CPU profiles from the problem window against a same-time-of-day baseline, work backward from hot stacks to candidate query patterns, then confirm against TopSQL, statement summary, and slow query records for the same window. Internal SQL, GC, plan building, and memory tracking are all candidates. A conclusion counts only when profiles, TopSQL, and slow queries agree.

## Reproduce before recommending an upgrade

`PLAN REPLAYER LOAD` into a `tiup playground` of the target version shows whether a newer release fixes the plan. Anonymise table and column names before sharing a dump outside the team.
