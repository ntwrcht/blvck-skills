# Session Variables

Variables tune a workload; hints tune a statement. Set them per session for a batch job, globally for a policy, and record every non-default value in application configuration so it survives a restart.

```sql
SET tidb_variable = value;            -- this connection
SET GLOBAL tidb_variable = value;     -- new connections from now on
SELECT @@tidb_variable;
```

In a pooled application a session-level `SET` leaks to whoever borrows the connection next. Reset it, or use a dedicated pool for the batch path.

## Optimizer behaviour

| Variable | Default | Effect |
|---|---|---|
| `tidb_opt_prefer_range_scan` | OFF | Prefer range scans over full scans even when cost disagrees. Use when stats underestimate selectivity. |
| `tidb_opt_insubq_to_join_and_agg` | ON | Rewrite `IN` subqueries to join plus aggregate. Turn off when the rewrite yields a worse plan. |
| `tidb_opt_derive_topn` | ON | Push TopN through outer joins and projections. |
| `tidb_opt_enable_late_materialization` | ON | Read wide columns only after filtering. |
| `tidb_opt_enable_no_decorrelate_in_select` (v8.5.4+) | OFF | Keep scalar subqueries in the `SELECT` list correlated. See `references/subquery-optimization.md`. |
| `tidb_opt_enable_semi_join_rewrite` | OFF | Apply `SEMI_JOIN_REWRITE` to every eligible semi-join. |
| `tidb_cost_model_version` | 2 | Keep 2 (v6.2+). Version 1 only for regression debugging. |
| `tidb_opt_seek_factor` | 20 | Higher favours sequential scans over index lookups. |

## Execution

| Variable | Default | Effect |
|---|---|---|
| `tidb_index_join_batch_size` | 25000 | Outer-side batch for index joins |
| `tidb_hash_join_concurrency` | 5 | Hash join workers |
| `tidb_distsql_scan_concurrency` | 15 | Concurrent coprocessor requests for a scan |
| `tidb_max_chunk_size` | 1024 | Rows per execution chunk |
| `tidb_mem_quota_query` | 1 GB | Per-query memory before spill or cancel; also bounds transaction size from v6.5.0 |
| `tidb_txn_mode` | pessimistic | Default transaction mode. See `references/transactions.md`. |

## Statistics

| Variable | Default | Effect |
|---|---|---|
| `tidb_auto_analyze_ratio` | 0.5 | Fraction of modified rows that triggers auto analyze |
| `tidb_analyze_column_options` (v8.3+) | ALL (PREDICATE on clusters created v8.3.0 to v8.5.4) | Which columns `ANALYZE` covers |
| `tidb_stats_load_sync_wait` | 100 ms | Wait for synchronous stats load during planning |
| `tidb_enable_pseudo_for_outdated_stats` | OFF | Keep OFF so stale stats produce warnings, not silent pseudo estimates |

## TiFlash and MPP

| Variable | Default | Effect |
|---|---|---|
| `tidb_isolation_read_engines` | tikv,tiflash,tidb | Which engines the optimizer may read from |
| `tidb_allow_mpp` | ON | Master switch for MPP |
| `tidb_enforce_mpp` | OFF | Force MPP for every eligible query |

## Recipes

Analytical session on TiFlash:

```sql
SET tidb_isolation_read_engines = 'tiflash';
SET tidb_enforce_mpp = ON;
```

Batch job with headroom:

```sql
SET tidb_distsql_scan_concurrency = 30;
SET tidb_hash_join_concurrency = 8;
SET tidb_index_join_batch_size = 50000;
SET tidb_mem_quota_query = 4 << 30;
```

Plan regression after a data change:

```sql
SHOW STATS_HEALTHY WHERE Db_name = 'mydb';
ANALYZE TABLE mydb.mytable ALL COLUMNS;
SELECT @@tidb_cost_model_version;
```
