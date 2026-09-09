# EXPLAIN and Reading Plans

`EXPLAIN` shows the optimizer's estimate without running the query. `EXPLAIN ANALYZE` runs it and reports what happened. Tune from `EXPLAIN ANALYZE`; estimates lie exactly when you most need them not to.

## Forms

```sql
EXPLAIN SELECT ...;                         -- estimate only
EXPLAIN ANALYZE SELECT ...;                 -- executes; adds actRows, time, memory, disk
EXPLAIN FORMAT = "tidb_json" SELECT ...;    -- structured tree for tooling
EXPLAIN FORMAT = "dot" SELECT ...;          -- Graphviz
EXPLAIN FORMAT = "verbose" SELECT ...;      -- cost and binding information in warnings
EXPLAIN FOR CONNECTION <id>;                -- another session's running statement (needs SUPER, not PROCESS as in MySQL)
```

MySQL's `FORMAT=JSON` and `FORMAT=TREE` do not exist on TiDB. `EXPLAIN ANALYZE` on DML really executes the DML.

## Columns

| Column | Meaning |
|---|---|
| `id` | Operator and its position in the tree |
| `estRows` | Optimizer's estimate from statistics |
| `actRows` | Rows observed (`EXPLAIN ANALYZE` only) |
| `task` | `root` runs on TiDB, `cop[tikv]` on the TiKV coprocessor, `cop[tiflash]` / `mpp[tiflash]` on TiFlash |
| `access object` | Table, index, or partition touched |
| `execution info` | Wall time, loops, concurrency, memory, disk |
| `operator info` | Filters, join keys, sort keys, pushed-down conditions |

## What to look for

1. **`estRows` far from `actRows`.** Statistics are stale or missing. `ANALYZE TABLE t;` (add `ALL COLUMNS` when `@@tidb_analyze_column_options` is not `ALL`) and re-check before touching anything else.
2. **The operator with the longest `time:`.** That is the bottleneck. Everything else is noise until it moves.
3. **`TableFullScan` on a large table.** Missing index, or the optimizer rejected one. See `references/index-selection.md`.
4. **`HashJoin` with a huge Build child.** Consider `INL_JOIN` if the inner side is indexed, or `LEADING` to swap sides. See `references/join-strategies.md`.
5. **`IndexJoin` / `IndexHashJoin` with the wrong probe index.** The join type can be right and the probe-side `access object` wrong. Compare candidates with `USE_INDEX`.
6. **`Sort` above a scan that could have been ordered.** `ORDER_INDEX` or an index in the right order removes it; `TopN` is the cheap form when a `LIMIT` exists.
7. **`Apply`.** A correlated subquery running once per outer row. Fine when the outer side is small; otherwise see `references/subquery-optimization.md`.
8. **`Selection` above a scan.** A filter that did not push down to the coprocessor. Usually a function on the column, or a type mismatch.
9. **`task` is `root` for heavy work.** Rows travelled to TiDB before filtering or aggregating. Check why the coprocessor rejected the pushdown.

## Operators

| Kind | Operator | Meaning |
|---|---|---|
| Scan | `TableFullScan` | Every row |
| Scan | `TableRangeScan` | Primary key range |
| Scan | `IndexRangeScan` / `IndexFullScan` | Index range, or the whole index |
| Scan | `IndexLookUp` | Index scan then a table read for the remaining columns |
| Scan | `IndexReader` / `TableReader` | Root-side collector for a coprocessor task |
| Join | `HashJoin`, `IndexJoin`, `IndexHashJoin`, `MergeJoin`, `Apply` | See `references/join-strategies.md` |
| Aggregate | `HashAgg` / `StreamAgg` | Hash-based, or streaming over sorted input |
| Other | `Sort`, `TopN`, `Selection`, `Projection`, `Limit` | As named |

## Workflow

```
EXPLAIN ANALYZE
  → highest wall-time operator
  → estRows vs actRows there and in its children
      ├── diverges → ANALYZE TABLE, re-run
      └── close   → operator choice is the problem
  → match the pattern above, apply the least invasive fix
  → EXPLAIN ANALYZE again; confirm actRows and time moved
```

Least invasive first: refresh stats, add or fix an index, bind a plan, hint the query, change a session variable. Document any hint with a SQL comment saying why.

## Rendering DOT

```bash
dot plan.dot -T png -O
```
