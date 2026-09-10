# Query Translation

Translate each access path from its MongoDB form to SQL that runs on TiDB and uses an index on purpose. The translated query is done when `EXPLAIN ANALYZE` on production-sized data shows the intended index and no `TableFullScan` on a hot path. `tidb-engineer` owns plan reading, hints, and statistics; this file owns the mapping.

Two facts shape most of the table:

- TiDB has no `JSON_TABLE`. An array is unnested through a child table, through a multi-valued index with `MEMBER OF`, `JSON_CONTAINS`, or `JSON_OVERLAPS`, or in application code.
- `GROUP BY` on TiDB does not sort. Every ordering the application relies on is an explicit `ORDER BY`.

## Query Operators

| MongoDB | SQL on TiDB | Notes |
|---|---|---|
| `{a: v}` | `WHERE a = ?` | |
| `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte` | `=`, `<>`, `>`, `>=`, `<`, `<=` | `$ne` also matches documents missing the field; SQL `<>` excludes `NULL`. Add `OR a IS NULL` when the application relied on that |
| `$in`, `$nin` | `IN (...)`, `NOT IN (...)` | `NOT IN` with a `NULL` in the list returns nothing; filter nulls first |
| `$and`, `$or`, `$not`, `$nor` | `AND`, `OR`, `NOT`, `NOT (a OR b)` | |
| `$exists: true` on a column | `IS NOT NULL` | On a JSON path: `JSON_CONTAINS_PATH(doc, 'one', '$.a')` |
| `$type` | Column type, or `JSON_TYPE(doc->'$.a')` | |
| `$regex` | `REGEXP` or `REGEXP_LIKE`, or `LIKE 'prefix%'` when the pattern is anchored | Only an anchored `LIKE` uses an index. TiDB's regex engine is RE2 (v6.3.0 and later for `REGEXP_LIKE`, `REGEXP_INSTR`, `REGEXP_SUBSTR`, `REGEXP_REPLACE`); MongoDB's is PCRE, so lookarounds and backreferences do not port |
| `$text` | Full-text search where the tier offers it, otherwise `LIKE '%term%'` on small tables or an external search index | `tidb-engineer`'s `full-text-search.md` has the availability probe |
| `$expr` | Plain SQL expression | |
| `$elemMatch` on an array of documents | `EXISTS (SELECT 1 FROM child WHERE child.parent_id = p.id AND ...)` | Child-table shape |
| `{tags: "x"}` on an array of scalars | `'x' MEMBER OF (tags)` with a multi-valued index, or a junction table | Multi-valued indexes from v6.6.0 |
| `$all: ["x", "y"]` | `JSON_CONTAINS(tags, '["x","y"]')`, or a junction table with `GROUP BY parent_id HAVING COUNT(DISTINCT tag) = 2` | |
| `$size: n` | `JSON_LENGTH(arr) = n`, or a count column, or `COUNT(*)` on the child table | `JSON_LENGTH` does not use an index; keep a count column for a hot path |
| `"arr.0"` positional | `arr->'$[0]'`, or `WHERE seq = 0` on the child table | |
| `$slice` projection | `LIMIT ? OFFSET ?` on the child table ordered by `seq` | |
| Dot path `"a.b.c"` | Column when peeled, else `doc->>'$.a.b.c'` | A generated column plus index makes the JSON path indexable |
| Projection `{a: 1, b: 1}` | `SELECT a, b` | Never `SELECT *` on a row with a `JSON` landing column |
| `.sort({a: -1, _id: -1})` | `ORDER BY a DESC, id DESC` | The tiebreaker matters for keyset pagination |
| `.skip(n).limit(m)` | Keyset: `WHERE (a, id) < (?, ?) ORDER BY a DESC, id DESC LIMIT m` | `OFFSET` is acceptable only when the offset is bounded and small |
| `.hint(index)` | `USE INDEX (...)` or an optimizer hint | Statistics first, hints second; `tidb-engineer` rules |
| `countDocuments(filter)` | `SELECT COUNT(*) ... WHERE ...` | |
| `estimatedDocumentCount()` | `SELECT TABLE_ROWS FROM information_schema.TABLES WHERE ...` | Approximate, like the original |
| `distinct("a", filter)` | `SELECT DISTINCT a ... WHERE ...` | |
| `findOne` by `_id` | `SELECT ... WHERE id = ?` | Clustered primary key makes it one lookup |

## Aggregation Stages

| Stage | SQL on TiDB | Notes |
|---|---|---|
| `$match` | `WHERE`, or `HAVING` after `$group` | |
| `$project`, `$addFields`, `$set` | `SELECT` expressions, CTE columns | |
| `$group` | `GROUP BY` | Add `ORDER BY`; `$first` and `$last` inside a group need window functions (`FIRST_VALUE`, `ROW_NUMBER`) |
| `$sum`, `$avg`, `$min`, `$max`, `$count` | `SUM`, `AVG`, `MIN`, `MAX`, `COUNT` | |
| `$push` in `$group` | `JSON_ARRAYAGG`, `GROUP_CONCAT` | |
| `$addToSet` in `$group` | `JSON_ARRAYAGG(DISTINCT ...)` is unsupported; `GROUP_CONCAT(DISTINCT ...)` or a subquery with `DISTINCT` | |
| `$lookup` | `JOIN` | Equality lookups become `JOIN ... ON`; pipeline lookups become `LEFT JOIN LATERAL`-style subqueries or a second query |
| `$unwind` | Read from the child table, or `MEMBER OF` against a multi-valued index; no `JSON_TABLE` | An `$unwind` over a `JSON` array with no child table is an application-side loop |
| `$sort` | `ORDER BY` | |
| `$limit`, `$skip` | `LIMIT`, keyset | |
| `$count` | `SELECT COUNT(*)` | |
| `$facet` | Several queries in one transaction, or CTEs joined on a constant | |
| `$bucket`, `$bucketAuto` | `CASE` or `FLOOR(x / width)` in `GROUP BY` | |
| `$graphLookup` | `WITH RECURSIVE` | Supported since v5.1 |
| `$setWindowFields` | Window functions | |
| `$dateToString`, `$dateTrunc` | `DATE_FORMAT`, `DATE`, `DATE_ADD` | |
| `$cond`, `$ifNull`, `$switch` | `CASE`, `IF`, `COALESCE` | |
| `$arrayElemAt` | `arr->'$[n]'`, or `seq = n` on the child | |
| `$size` | `JSON_LENGTH`, or `COUNT(*)` | |
| `$merge`, `$out` | `INSERT ... SELECT ... ON DUPLICATE KEY UPDATE`, or `CREATE TABLE ... AS SELECT` | |
| `$sample` | `TABLESAMPLE REGIONS()` for a rough sample, `ORDER BY RAND() LIMIT n` on small tables | |
| `$collStats`, `$indexStats` | `information_schema.TABLES`, `SHOW INDEX`, `information_schema.TIDB_INDEX_USAGE` | |

Analytical pipelines that scan a large table land on a TiFlash replica; the SQL is the same and the optimizer picks the replica.

## Write Operators

MongoDB gives single-document atomicity; TiDB gives multi-row transactions. A document update that touched a parent and an embedded array becomes one pessimistic transaction touching two tables.

| MongoDB | SQL on TiDB | Notes |
|---|---|---|
| `insertOne` | `INSERT` | The application keeps generating the id when the id format must survive |
| `insertMany` | Multi-row `INSERT`, chunked | A few thousand rows per statement, under the transaction size limit |
| `updateOne` with `$set` | `UPDATE ... SET ... WHERE id = ?` | |
| `$inc` | `SET n = n + ?` | |
| `$unset` | `SET col = NULL`, or `JSON_REMOVE` | |
| `$push` | `INSERT INTO child (parent_id, seq, ...) VALUES (?, ?, ...)` plus the parent's `updated_at` and count in the same transaction | `seq` comes from a count column read `FOR UPDATE`, or from a `(parent_id, ts, id)` key when order is by time |
| `$push` with `$each`, `$slice` | Insert the rows, then delete beyond the cap in the same transaction | |
| `$addToSet` | `INSERT IGNORE` against a unique key on `(parent_id, value)` | |
| `$pull` | `DELETE FROM child WHERE parent_id = ? AND ...` | |
| `$pop` | `DELETE ... ORDER BY seq DESC LIMIT 1` | |
| Positional `$` and `arrayFilters` | `UPDATE child SET ... WHERE parent_id = ? AND <filter>` | The child table is what makes this simple |
| `$set` on a JSON path | `JSON_SET(doc, '$.a.b', ?)` | |
| `upsert: true` | `INSERT ... ON DUPLICATE KEY UPDATE` | Needs a unique key on the match fields |
| `replaceOne` | `REPLACE INTO`, or `DELETE` plus `INSERT` in one transaction | `REPLACE` deletes and reinserts; child rows need their own handling |
| `findOneAndUpdate` | `SELECT ... FOR UPDATE` then `UPDATE`, in one pessimistic transaction | Returns the old or new row as the original did. `FOR UPDATE NOWAIT` exists; `SKIP LOCKED` does not, so a work-queue pattern needs a claim column instead |
| `updateMany` | `UPDATE ... WHERE ...` chunked by primary-key range | Under the transaction size limit; TTL for age-based deletes |
| `deleteMany` by age | TTL attribute on the table | `tidb-engineer`'s `schema-design.md` |
| `bulkWrite` ordered | One transaction with the statements in order | |
| `bulkWrite` unordered | Independent statements, each with its own error handling | |
| Multi-document transaction | `BEGIN ... COMMIT`, pessimistic by default | Optimistic mode needs a whole-transaction retry loop |
| Change stream consumer | No equivalent inside TiDB; TiCDC publishes row changes to Kafka or MySQL sinks | An application that consumed change streams needs a design decision, not a translation |

## Pagination

Every list endpoint gets keyset pagination unless the page depth is provably bounded. The cursor is the last row's `(sort_column, id)`, the index covers `(filter columns..., sort_column, id)`, and the query is:

```sql
SELECT id, subject, updated_at
FROM tickets
WHERE assignee_id = ? AND status = ?
  AND (updated_at < ? OR (updated_at = ? AND id < ?))
ORDER BY updated_at DESC, id DESC
LIMIT 50;
```

`EXPLAIN` shows `IndexRangeScan` reading backward and no `Sort` operator when the index matches.

## The Repository Seam

Applications that route every database call through a repository or data-access layer are translated module by module behind the same interface, and the old and new implementations run side by side for shadow reads. Applications with driver calls scattered through handlers get the seam first; `codebase-design` owns that refactor. Choosing between `mysql2`, Kysely, Prisma, and the serverless driver is `tidb-engineer`'s call.
