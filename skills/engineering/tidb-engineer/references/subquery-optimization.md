# Subquery Optimization

TiDB decorrelates correlated subqueries into joins by default. That is right for analytics and wrong for a selective OLTP query whose subquery is well indexed. Two controls exist, and they are mutually exclusive on the same subquery.

## How TiDB executes a subquery

1. **Decorrelation (default).** `EXISTS`, `IN`, and scalar subqueries become semi-joins, anti-semi-joins, or left outer joins, which can then use hash or index join strategies.
2. **Correlated execution.** The subquery runs once per outer row as an `Apply` operator. This is the fallback when decorrelation is disabled or impossible.

## NO_DECORRELATE

Place the hint inside the subquery:

```sql
SELECT *
FROM orders o
WHERE o.status = 'disputed'
  AND o.created_at > '2026-01-01'
  AND EXISTS (
    SELECT /*+ NO_DECORRELATE() */ 1
    FROM returns r
    WHERE r.order_id = o.id AND r.reason = 'defective'
  );
```

For `EXISTS`, current TiDB injects `LIMIT 1` into the subquery for early exit (planner source; not stated in the docs).

Use it when all three hold:

- The outer query is selective, so the subquery runs few times.
- The subquery has an index on the correlation columns, so each run is a lookup.
- The inner table is large, so decorrelation would build an expensive hash table.

Leave the default when the outer side returns many rows, the correlation column is unindexed, or the inner table is small.

`tidb_opt_enable_no_decorrelate_in_select = ON` (v8.5.4+) applies the same behaviour to subqueries in the `SELECT` list session-wide. It does not touch `WHERE`-clause subqueries.

## SEMI_JOIN_REWRITE

Turns a semi-join into an inner join over a deduplicated inner side:

```sql
-- before
SELECT * FROM t WHERE EXISTS (SELECT 1 FROM s WHERE s.a = t.a);
-- after
SELECT * FROM t JOIN (SELECT a FROM s GROUP BY a) s ON t.a = s.a;
```

```sql
SELECT * FROM orders o
WHERE EXISTS (SELECT /*+ SEMI_JOIN_REWRITE() */ 1 FROM returns r WHERE r.order_id = o.id);
```

Use it when the semi-join is slow, the inner side has few duplicates on the join key, and an inner join would unlock a better strategy such as an index join. Skip it when duplicates are many (the `GROUP BY` becomes the cost) or the subquery is still correlated. It applies only to `SemiJoin`, not `LeftOuterSemiJoin`, and only with pure equality conditions. `tidb_opt_enable_semi_join_rewrite = ON` applies it session-wide.

Specifying both hints on one subquery cancels both, with a warning (planner source).

## Semi-join strategy after decorrelation

| Strategy | Works well when |
|---|---|
| Hash semi-join | Inner side fits in memory, no useful index |
| Index semi-join | Inner side indexed on the key, outer side moderate |
| Merge semi-join | Both sides sorted on the key |

Combine with join hints: `SELECT /*+ INL_JOIN(r) */ ... WHERE EXISTS (SELECT 1 FROM returns r ...)`.

## NOT EXISTS and NOT IN

Both become anti-semi-joins. `NO_DECORRELATE()` works on `NOT EXISTS`. Prefer `NOT EXISTS` over `NOT IN`: `NOT IN` carries three-valued NULL semantics that block optimisation and surprise users.

## Decision

```
Correlated?
├── no  → runs once; tune it like any query
└── yes
    ├── in SELECT list → selective outer + indexed inner? → tidb_opt_enable_no_decorrelate_in_select or the hint
    └── in WHERE
        ├── selective outer + indexed inner → NO_DECORRELATE(), verify with EXPLAIN ANALYZE
        └── otherwise → default decorrelation
            └── semi-join slow and inner has few duplicates → SEMI_JOIN_REWRITE()
            └── else → INL_JOIN / HASH_JOIN hints on the semi-join
```

Compare both forms with `EXPLAIN ANALYZE`: decorrelated shows `HashJoin` over a scan of the inner table; correlated shows `Apply` over `IndexLookUp` with the injected `Limit`.
