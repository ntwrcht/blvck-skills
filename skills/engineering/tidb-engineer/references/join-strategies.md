# Join Strategies

TiDB chooses among several join algorithms by cost. Stale statistics or misestimated cardinality make it choose badly, and the fix is a hint or a binding, not a query rewrite.

## Algorithms

| Algorithm | Hint | Mechanism | Best when | Watch for |
|---|---|---|---|---|
| Hash join | `HASH_JOIN(t1, t2)` | Build a hash table on the smaller side, probe with the larger | Large equi-joins with no useful index | Build-side memory; spills governed by `tidb_mem_quota_query` |
| Index nested loop | `INL_JOIN(t)` | For each outer row, index-probe the inner table `t` | Inner side indexed on the join key, outer side small to moderate | Outer cardinality underestimated; wrong probe index |
| Index hash join | `INL_HASH_JOIN(t)` | Like INL but hash-matches on the inner side | Same as INL with duplicate-heavy inner rows | Same as INL |
| Merge join | `MERGE_JOIN(t1, t2)` | Both sides sorted on the key, merged in one pass | Both sides already ordered by index | Sort cost when they are not |
| Shuffle join | `SHUFFLE_JOIN(t1, t2)` | MPP only: redistribute both sides across TiFlash by key | Large-to-large analytical joins | Needs TiFlash replicas on both tables |
| Broadcast join | `BROADCAST_JOIN(t1, t2)` | MPP only: send the small side to every TiFlash node | One side small, one huge | Same |

## Decision guide

```
Both sides small (< 10K rows)?       → any strategy; stop tuning
Good index on one side's join key?
  ├── other side small               → INL_JOIN(indexed side)
  ├── other side moderate            → INL_JOIN still likely; verify
  └── other side large               → HASH_JOIN, smaller side as build
No index on either side              → HASH_JOIN; MERGE_JOIN only if both are pre-sorted
On TiFlash
  ├── one side small                 → BROADCAST_JOIN
  └── both large                     → SHUFFLE_JOIN
```

## Forcing order and strategy

```sql
SELECT /*+ HASH_JOIN(o, c) */ * FROM orders o JOIN customers c ON o.cust_id = c.id;
SELECT /*+ INL_JOIN(c) */ * FROM orders o JOIN customers c ON o.cust_id = c.id;          -- c is probed
SELECT /*+ LEADING(o, i, c) */ * FROM orders o JOIN items i ON i.order_id = o.id JOIN customers c ON c.id = o.cust_id;
SELECT /*+ INL_JOIN(t2) USE_INDEX(t2, idx_join_cols) */ ... ;                          -- fix the probe index too
```

Join hints choose the algorithm and the inner table. They do not choose the probe-side index; inspect the inner `access object` separately and see `references/index-selection.md`.

## Misoptimisation patterns

**Hash join with a huge build side.** `Build` child has millions of `actRows`, memory or disk spill in `execution info`. If the inner table is indexed on the join key, `INL_JOIN(inner)`.

**Index join on a non-selective outer side.** `IndexJoin` whose outer child has large `actRows`, producing millions of probes. Switch to `HASH_JOIN`.

**Right join type, wrong probe index.** `IndexJoin` looks reasonable but the probe child's `access object` does not cover the full join key, residual filters remain, or an `IndexLookUp` appears where a covering index exists. Keep the join, compare probe indexes with `USE_INDEX`, bind the winner.

**Wrong order in a multi-way join.** An intermediate join produces a huge result that then meets a small table. `LEADING(small, medium, large)`.

**Everything at `root`.** Join keys of different types or collations prevent pushdown and index use. Align the column types before hinting.
