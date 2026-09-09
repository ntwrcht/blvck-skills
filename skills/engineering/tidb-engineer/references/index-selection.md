# Index Selection

Index design is the highest-impact tuning lever. TiDB chooses indexes by cost, and chooses wrong when statistics are stale or cardinality is misestimated. Everything here also applies to the probe side of an index join.

## Hints

```sql
SELECT /*+ USE_INDEX(t, idx_status_created) */ * FROM orders t WHERE t.status = 'pending' AND t.created_at > '2026-01-01';
SELECT /*+ IGNORE_INDEX(t, idx_old) */ * FROM orders t WHERE t.status = 'pending';
SELECT /*+ USE_INDEX_MERGE(t, idx_status, idx_region) */ * FROM orders t WHERE t.status = 'pending' OR t.region = 'us-east';
SELECT /*+ ORDER_INDEX(t, idx_created) */ * FROM orders t ORDER BY t.created_at DESC LIMIT 20;
SELECT /*+ NO_ORDER_INDEX(t, idx_created) */ * FROM orders t WHERE t.status = 'pending' ORDER BY t.created_at DESC LIMIT 20;
```

Index merge is the tool for `OR` across differently indexed columns.

## Composite index design

- **Leftmost prefix.** `(a, b, c)` serves filters on `a`, `a,b`, `a,b,c`, never `b` alone.
- **Equality columns first, the range column last.** For `status = ? AND region = ? AND created_at > ?` the index is `(status, region, created_at)`.
- **Higher selectivity earlier** among the equality columns.
- **Covering.** When the index holds every column the query reads (plus the primary key, which is always present), TiDB skips the table lookup. The plan shows `IndexReader` instead of `IndexLookUp`.

## Invisible indexes

Test a drop without dropping:

```sql
ALTER TABLE orders ALTER INDEX idx_old INVISIBLE;
-- observe
DROP INDEX idx_old ON orders;
-- or
ALTER TABLE orders ALTER INDEX idx_old VISIBLE;
```

## Diagnosing a wrong choice

```sql
EXPLAIN SELECT ...;                                  -- which index, if any
SHOW STATS_HEALTHY WHERE Table_name = 'orders';      -- are stats fresh
SHOW INDEX FROM orders;                              -- what exists
EXPLAIN ANALYZE SELECT /*+ USE_INDEX(orders, idx_a) */ ...;   -- compare candidates
EXPLAIN ANALYZE SELECT /*+ USE_INDEX(orders, idx_b) */ ...;
```

When a candidate wins consistently, stabilise it with a binding rather than editing application SQL:

```sql
CREATE GLOBAL BINDING FOR SELECT ... USING SELECT /*+ USE_INDEX(orders, idx_b) */ ...;
```

Remove bindings with `DROP GLOBAL BINDING`, never by deleting from `mysql.bind_info`: the in-memory cache does not follow a direct delete.

## Probe-side index for IndexJoin and IndexHashJoin

Treat the inner access path as an index-selection problem:

- Match the join equality columns first.
- Prefer an index that also absorbs pushed `=` and `IN` filters.
- Prefer a covering probe path that avoids `IndexLookUp` plus `TableRowIDScan`.
- If both `(a, b)` and `(a, b, c, d)` exist and the query filters on `b` and `d`, the longer index can be the better probe even though the join uses only `a`.

## Pitfalls

- Every index costs write amplification and storage. Index for query shapes that exist.
- `(a, b)` makes a standalone `(a)` redundant.
- A low-cardinality leading column (`gender`, `is_deleted`) wastes the prefix unless every query filters on it.
- A new index has no statistics. `ANALYZE TABLE` after creating it, or the optimizer may ignore it.
- Indexes on a monotonically increasing column create a write hotspot on the index itself. See `references/schema-design.md`.
