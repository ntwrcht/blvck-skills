# Code Review

Order findings by cost of being wrong. On TiDB the top of that list is a schema decision that cannot be changed after the table has data: a sequential primary key on a write-heavy table, a missing primary key, or an `AUTO_RANDOM` that was never added. Everything else can be fixed by a later migration.

| Severity | Meaning |
|---|---|
| **Blocking** | DDL that fails on TiDB, data loss, a hotspot baked into a primary key, an unverified TLS connection, a transaction that cannot be retried |
| **Should fix** | Real bug in an edge case, a query that cannot use an index, a missing statistics refresh after an index, a pool sized wrong for the runtime |
| **Consider** | Simplification, naming, structure; the author's call |

Label every finding.

## Pass 1: Schema

- [ ] Every new table has an explicit primary key.
- [ ] Write-heavy tables use `AUTO_RANDOM`, a scattering composite key, or an application-generated random ID; no bare `AUTO_INCREMENT` or timestamp-led primary key.
- [ ] No secondary index whose only leading column is monotonic, unless the hotspot is accepted in a comment.
- [ ] `utf8mb4`; collation set explicitly where case-insensitive comparison is expected.
- [ ] No `GEOMETRY`, `FLOAT(M,D)`, `ZEROFILL`, or `ENUM` that will need extending weekly.
- [ ] JSON columns have generated columns and indexes for the paths queries filter on.
- [ ] Expiry handled by a TTL attribute, not a scheduled `DELETE`.
- [ ] Foreign keys match the project's recorded stance.

## Pass 2: DDL and migrations

- [ ] No stored procedures, triggers, events, UDFs, or `CREATE TABLE ... AS SELECT`.
- [ ] One change per `ALTER TABLE`; no `ALGORITHM=` or `LOCK=` clauses.
- [ ] Type changes TiDB cannot do in place are expand-and-contract.
- [ ] No primary key change on a clustered table disguised as an `ALTER`.
- [ ] Migration was run against TiDB of the target version, not only MySQL.
- [ ] `ANALYZE TABLE` planned after a new index on a large table.
- [ ] Partition DDL confirmed supported on the target version; no `SUBPARTITION`.

## Pass 3: SQL

- [ ] Every `ORDER BY` that matters is explicit; nothing relies on `GROUP BY` order.
- [ ] No `INSERT`, `UPDATE`, or `DELETE` against a view.
- [ ] No `SELECT ... INTO @var`, `OPTIMIZE TABLE`, `MATCH ... AGAINST`, or MySQL-only built-ins without `SHOW BUILTINS` confirmation.
- [ ] Hints are TiDB hints, name their tables, and carry a reason comment.
- [ ] Pagination is keyset on large tables, not deep `OFFSET`.
- [ ] Bulk writes are chunked under the transaction size limit.
- [ ] `NOT EXISTS` preferred over `NOT IN` on nullable columns.
- [ ] Full-text and vector queries follow the index-eligible shape: same distance function, ascending, with `LIMIT`.

## Pass 4: Connections

- [ ] TLS with certificate and hostname verification on any TiDB Cloud endpoint; CA file for Dedicated.
- [ ] Username carries the cluster prefix; port is 4000.
- [ ] Pool idle timeout at or below 300 s, keepalive on, `connectionLimit` matched to the runtime.
- [ ] TCP driver only in a Node runtime; HTTP driver on Edge and Workers.
- [ ] `BIGINT` IDs handled as strings or `BigInt` in JavaScript.
- [ ] Credentials from environment, never under a public prefix, never logged.

## Pass 5: Transactions and retries

- [ ] Optimistic transactions wrapped in a whole-transaction retry with idempotent statements.
- [ ] Retries on 1213 and 8028; no retry on constraint violations.
- [ ] Isolation level requested is `REPEATABLE READ` or `READ COMMITTED`; nothing asks for `SERIALIZABLE`.
- [ ] No transaction expected to run longer than `tidb_gc_life_time`.

## Pass 6: Tests and conventions

- [ ] Integration tests run against TiDB (branch, Zero, or playground), not MySQL.
- [ ] Generated types or Prisma client regenerated when the schema moved.
- [ ] Matches the project's migration tool, naming, and client patterns.

## Writing the review

Lead with the conclusion:

> **Blocking (1), Should fix (2), Consider (1).** The `events` migration creates a `BIGINT AUTO_INCREMENT` primary key on a table expected to take 50k inserts per second; every write will land on one Region. Everything else is contained.

Then each finding with file, line, why it matters on TiDB specifically, and a concrete fix in a code block. State what you verified against a real TiDB and what you did not.

## Quick reference

| Look for | Why |
|---|---|
| `AUTO_INCREMENT` primary key on a hot table | Single-Region write hotspot |
| Table without a primary key | Hidden sequential `_tidb_rowid` hotspot |
| `CREATE PROCEDURE`, `CREATE TRIGGER`, `CREATE EVENT` | Fails on TiDB |
| `UPDATE v_*` | Views are read-only |
| `MATCH ... AGAINST` | Not TiDB full-text search |
| `ssl` missing on a `tidbcloud.com` host | Handshake failure or unverified peer |
| `idleTimeout` above 300 000 ms | Gateway closes the socket; first query after idle fails |
| `BEGIN OPTIMISTIC` with no retry loop | Commit conflicts become user-facing errors |
| Nightly `DELETE ... WHERE created_at <` | TTL does it without contention |
| `EXPLAIN` estimate cited as evidence | Only `EXPLAIN ANALYZE` shows what ran |
