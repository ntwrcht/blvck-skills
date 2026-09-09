# Statistics

Most bad plans on TiDB come from stale or missing statistics, not from the optimizer. Check statistics before anything else, and treat statistics maintenance as capacity planning rather than a one-off command.

## Check

```sql
SHOW STATS_HEALTHY WHERE Db_name = 'app' AND Table_name = 'orders';   -- 0 to 100
SHOW ANALYZE STATUS;                                                  -- running and recent jobs
SELECT @@tidb_analyze_column_options;                                 -- ALL, or PREDICATE on clusters created between v8.3.0 and v8.5.4
```

Health below 80, or `estRows` far from `actRows` in `EXPLAIN ANALYZE`, means refresh:

```sql
ANALYZE TABLE orders;                        -- predicate columns, the default
ANALYZE TABLE orders ALL COLUMNS;            -- when the variable is not ALL and a plan needs a non-predicate column
ANALYZE TABLE orders INDEX idx_status_created;
ANALYZE TABLE orders PARTITION p2026;
```

A new index or a bulk load leaves the table without useful stats. Analyze after either, before judging a plan.

## Auto analyze

TiDB re-analyzes a table when modified rows exceed `tidb_auto_analyze_ratio` (default 0.5) of the row count, inside the window `tidb_auto_analyze_start_time` to `tidb_auto_analyze_end_time`. Healthy means auto analyze refreshes tables at least as fast as they decay.

Signals that it is not keeping up: the unhealthy bucket in the dashboard grows for days, auto analyze query-per-minute sits at zero while stale tables exist, or analyze duration P95 is high.

## Decide: triggering or execution

| Symptom | Likely cause | Lever |
|---|---|---|
| Backlog grows, few jobs start | Ratio too high | Lower `tidb_auto_analyze_ratio` gradually |
| Jobs start but run long | Under-provisioned | Raise `tidb_auto_analyze_concurrency` (v8.4+), `tidb_auto_build_stats_concurrency`, `tidb_build_sampling_stats_concurrency` one at a time |
| Slow only on partitioned tables | Global stats merge | `tidb_enable_async_merge_global_stats`, `tidb_merge_partition_stats_concurrency`, `tidb_auto_analyze_partition_batch_size` |
| Analyze hurts online latency | Too much scan fan-out | Rate-limit TiKV background reads first; isolate stats ownership with `tidb_enable_stats_owner` on dedicated nodes; then reduce `tidb_analyze_distsql_scan_concurrency` |

The concurrency variables multiply. Keep the product within what TiDB CPU can absorb, or analyze gets slower, not faster.

## Startup and restarts

A freshly started TiDB node plans with pseudo statistics until stats load. Plans can differ for minutes after a rolling restart. `tidb_stats_load_sync_wait` bounds how long planning waits for a synchronous load; raise it if plans flip after restarts, and keep `tidb_enable_pseudo_for_outdated_stats` OFF so stale stats warn instead of silently degrading.

## Bindings interact with stats

A global binding pins a plan regardless of statistics. When a query stays slow after a refresh, check `SHOW GLOBAL BINDINGS` and `SELECT @@last_plan_from_binding` before blaming the optimizer.

## Discipline

- Change one variable at a time and judge by dashboard trend, not a single snapshot.
- Re-check critical plans after any statistics tuning; they can legitimately change.
- Record the analyze schedule and any non-default ratio in the project's engineering context.
