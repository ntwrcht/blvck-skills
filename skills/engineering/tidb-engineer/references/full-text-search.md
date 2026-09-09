# Full-Text Search

TiDB's own keyword search. It is not MySQL `FULLTEXT`: the index lives on a columnar replica, the query function is different, and availability depends on the deployment.

## Availability gate

Full-text search is available on TiDB Cloud Starter in five AWS regions at the time of vendoring (Oregon, N. Virginia, Tokyo, Frankfurt, Singapore); Essential support is inconsistent across doc pages. Self-managed TiDB and TiDB Cloud Dedicated parse the `FULLTEXT` syntax and do not build the index. Confirm on the target before designing around it:

```sql
CREATE TABLE fts_probe (id INT PRIMARY KEY, t TEXT, FULLTEXT INDEX (t) WITH PARSER STANDARD);
DROP TABLE fts_probe;
```

A rejected `CREATE` means the deployment does not offer it. Fall back to `LIKE` with a leading prefix, or to an external search index.

## Create an index

With the table:

```sql
CREATE TABLE stock_items (
  id BIGINT PRIMARY KEY AUTO_RANDOM,
  title TEXT,
  FULLTEXT INDEX (title) WITH PARSER MULTILINGUAL
);
```

On an existing table:

```sql
ALTER TABLE stock_items
  ADD FULLTEXT INDEX (title) WITH PARSER MULTILINGUAL
  ADD_COLUMNAR_REPLICA_ON_DEMAND;
```

Parsers:

| Parser | Use for |
|---|---|
| `STANDARD` | Space- and punctuation-delimited languages, English included |
| `MULTILINGUAL` | Multiple languages, including English, Chinese, Japanese, and Korean |

`ADD_COLUMNAR_REPLICA_ON_DEMAND` appears in the official examples. If the deployment rejects the clause, remove it and add a TiFlash replica explicitly.

## Query

`FTS_MATCH_WORD(query, column)` filters in `WHERE` and ranks in `ORDER BY`:

```sql
SELECT id, title
FROM stock_items
WHERE FTS_MATCH_WORD('bluetooth earbuds', title)
ORDER BY FTS_MATCH_WORD('bluetooth earbuds', title) DESC
LIMIT 10;

SELECT COUNT(*) FROM stock_items WHERE FTS_MATCH_WORD('bluetooth earbuds', title);
```

## Hybrid search

Combine full-text and vector results with reciprocal rank fusion in the application, or through pytidb's hybrid search when working from Python. See `references/vector-search.md` and `references/python-pytidb.md`.

## Porting MySQL FULLTEXT

`MATCH ... AGAINST` does not run on TiDB. Rewrite to `FTS_MATCH_WORD`, drop `IN BOOLEAN MODE` operators, and re-test relevance: the tokenizers differ.
