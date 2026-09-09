# MySQL Compatibility

The lint list for SQL that must run on TiDB. TiDB speaks the MySQL protocol and most of its dialect, but it is a different engine: distributed, without stored code, and with its own DDL rules. Run this list over any SQL ported from MySQL and over any SQL an ORM generates for the first time against TiDB.

## Detect the engine first

```sql
SELECT VERSION();
SELECT @@version_comment;
```

A version string containing `TiDB` means TiDB. Parse the version from it, since several features below are gated by version.

## Unsupported on TiDB

Move the logic to the application or a scheduler, or drop the statement.

| MySQL feature | Status on TiDB | Replace with |
|---|---|---|
| Stored procedures and functions | Unsupported | Application code, or a job runner |
| Triggers | Unsupported | Application code, or an outbox table the app processes |
| Events (event scheduler) | Unsupported | External scheduler, TiDB Cloud scheduled jobs, or TTL attributes on the table |
| User-defined functions | Unsupported | Application code |
| `SPATIAL` / `GEOMETRY` types, functions, indexes | Unsupported | Store coordinates as `DECIMAL` columns, filter with bounding boxes |
| XML functions | Unsupported | Application code |
| `XA` transactions over SQL | Unsupported (TiDB uses 2PC internally) | Single TiDB transaction |
| `CREATE TABLE ... AS SELECT` | Unsupported | `CREATE TABLE ... LIKE` then `INSERT ... SELECT` |
| `CHECK TABLE`, `CHECKSUM TABLE`, `REPAIR TABLE`, `OPTIMIZE TABLE` | Unsupported; `OPTIMIZE TABLE` returns error 8200 | Nothing needed: TiKV compacts on its own |
| `HANDLER`, `CREATE TABLESPACE` | Unsupported | Nothing |
| `SELECT ... INTO @var` | Unsupported | Read the value in the application |
| `SKIP LOCKED`, lateral derived tables, `JOIN ... ON (subquery)` | Version-dependent | Confirm on the target version before relying on them |

Validate a non-trivial built-in function before porting SQL that uses it:

```sql
SHOW BUILTINS;
```

## Behaves differently on TiDB

- **Views are read-only.** No `INSERT`, `UPDATE`, or `DELETE` against a view. Write to the base table.
- **`GROUP BY` does not imply `ORDER BY`.** MySQL 5.7 sorted grouped output; TiDB does not. Add an explicit `ORDER BY` wherever order matters.
- **Foreign keys** are enforced from v6.6.0 (GA v8.5.0). Before that they parse but do nothing, and stay inert after an upgrade. Decide whether the application enforces referential integrity or the database does, and check the version.
- **`AUTO_INCREMENT` is unique but not sequential** across TiDB nodes, and each node caches a range of IDs. Code that assumes gapless or monotonic IDs breaks. See `references/schema-design.md` for `AUTO_RANDOM` and `AUTO_ID_CACHE 1`.
- **Removing `AUTO_INCREMENT` is possible** (guarded by `tidb_allow_remove_auto_inc`), **adding it later is not.**
- **A table with no primary key gets a hidden `_tidb_rowid`.** Its allocator interacts with `AUTO_INCREMENT` in ways that surprise MySQL users. Give every table an explicit primary key.
- **Optimizer hints are not MySQL hints.** `optimizer_switch` is read-only and has no effect. Use TiDB hints and validate with `EXPLAIN`; see `references/optimizer-hints.md`.
- **`explicit_defaults_for_timestamp` is always `ON`.** MySQL 5.7-era SQL that relies on implicit `TIMESTAMP` defaults needs explicit defaults.
- **Named time zones work from system rules** without loading time zone tables.
- **`lower_case_table_names = 2` only.** Two objects whose names differ only by case cannot coexist.

## Character sets and collations

- Stick to `utf8mb4`. TiDB supports a limited set of character sets, and exotic ones fail at DDL time.
- Defaults differ from MySQL: TiDB defaults to `utf8mb4_bin`, a binary collation, regardless of configuration. `new_collations_enabled_on_first_bootstrap` (default on) only decides whether `_general_ci`, `_unicode_ci`, and `_0900_ai_ci` collations are honoured semantically. Code that assumes case-insensitive `=` on strings must set such a collation explicitly on the column.

## DDL rules

TiDB runs online, asynchronous DDL. It is safer than MySQL's blocking DDL and stricter about what one statement may do.

- One logical change per `ALTER TABLE`. Referencing the same column or index twice in one statement fails, and packing several TiDB-specific changes into one statement is fragile.
- Not every type change is allowed in place. For an unsupported change, plan `add column, backfill, swap, drop`.
- `ALGORITHM={INSTANT,INPLACE,COPY}` is an assertion, not a selector. If TiDB cannot honour it, the statement fails.
- Primary key changes on a clustered table mean `create new table, backfill, swap`. Treat them as a migration project, not a statement.
- Index decorations `USING HASH|BTREE|RTREE|FULLTEXT` parse and are ignored. They change nothing.
- Partitioning supports `HASH`, `RANGE`, `LIST`, and `KEY`. `SUBPARTITION` is unsupported, and some partition DDL is silently ignored. Confirm on the target version.

## Deprecated MySQL syntax not worth porting

- Floating-point precision specifiers such as `FLOAT(10,2)`. Use `DECIMAL` for fixed precision.
- `ZEROFILL`. Pad in the application.

## Keyword search

MySQL `FULLTEXT` does not carry over. TiDB has its own full-text search, available on specific TiDB Cloud tiers and regions. When a user says "FULLTEXT", ask whether they mean the MySQL index or keyword search as a capability, then see `references/full-text-search.md`.
