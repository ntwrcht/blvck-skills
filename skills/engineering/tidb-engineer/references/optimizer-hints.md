# Optimizer Hints

Hints go in a `/*+ ... */` comment immediately after `SELECT`, `UPDATE`, or `DELETE`. Several can share one comment. They are per-statement; session variables are per-workload. See `references/session-variables.md` for the latter.

```sql
SELECT /*+ HASH_JOIN(t1, t2) NO_DECORRELATE() */ ...
```

## Catalog

| Group | Hint | Effect |
|---|---|---|
| Join strategy | `HASH_JOIN(t1, t2)` | Hash join between the named tables |
| | `INL_JOIN(t)` | Index nested loop join, `t` probed |
| | `INL_HASH_JOIN(t)` | Index hash join, `t` probed |
| | `MERGE_JOIN(t1, t2)` | Sort-merge join |
| | `SHUFFLE_JOIN(t1, t2)` / `BROADCAST_JOIN(t1, t2)` | MPP joins on TiFlash |
| Join order | `LEADING(t1, t2, t3)` | Join left to right in this order |
| | `STRAIGHT_JOIN()` | Join in `FROM` order |
| Subquery | `NO_DECORRELATE()` | Keep the correlated subquery correlated (inside the subquery) |
| | `SEMI_JOIN_REWRITE()` | Rewrite semi-join as inner join plus dedup (inside the subquery) |
| Index | `USE_INDEX(t, idx)` / `IGNORE_INDEX(t, idx)` | Force or forbid an index |
| | `USE_INDEX_MERGE(t, idx1, idx2)` | Combine indexes, useful for `OR` |
| | `ORDER_INDEX(t, idx)` / `NO_ORDER_INDEX(t, idx)` | Force or forbid an ordered index scan |
| Storage | `READ_FROM_STORAGE(TIKV[t])` / `READ_FROM_STORAGE(TIFLASH[t])` | Choose row store or columnar store per table |
| Aggregation | `HASH_AGG()` / `STREAM_AGG()` | Hash or streaming aggregation |
| | `MPP_1PHASE_AGG()` / `MPP_2PHASE_AGG()` | One- or two-phase MPP aggregation |
| Limits | `MEMORY_QUOTA(1 GB)` | Per-query memory cap |
| | `MAX_EXECUTION_TIME(5000)` | Per-query timeout in milliseconds |
| | `RESOURCE_GROUP(name)` | Run under a resource group |
| Other | `USE_TOJA(TRUE|FALSE)` | Enable or disable outer-join-to-anti/semi-join rewrite |

## Discipline

- Start with no hints. Fix statistics and indexes first; hint only a plan the optimizer gets wrong consistently.
- Name tables in every hint. Ambiguity in a multi-join query makes the hint silently inapplicable. Check `SHOW WARNINGS` after `EXPLAIN` for "hint ... is inapplicable".
- Write the reason in a SQL comment next to the hint. The next reader will otherwise delete it.
- Prefer a global binding when application SQL cannot change:

```sql
CREATE GLOBAL BINDING FOR <original statement> USING <hinted statement>;
SHOW GLOBAL BINDINGS;
DROP GLOBAL BINDING FOR <original statement>;
```

- Re-evaluate every hint after a TiDB upgrade. Optimizer improvements make old hints unnecessary or harmful.
- Hints are ignored inside a view body on older versions. Hint the outer query, or bind the view's expanded statement.
