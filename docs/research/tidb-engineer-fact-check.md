# TiDB Engineer Skill: Fact Check Against Primary Sources

**Question:** Do the claims in `skills/engineering/tidb-engineer/` that came from model knowledge rather than the two vendored source repos hold up against the TiDB documentation?

**Date:** 2026-09-09. **Sources:** docs.pingcap.com (TiDB v8.5 LTS docs, TiDB Cloud docs, TiDB AI docs), pingcap/docs and pingcap/tidb source on GitHub, tidbcloud GitHub repos, the npm registry, zero.tidbcloud.com, prisma.io docs. No secondary sources were cited.

**Method:** 48 claims split across three research agents by theme. Each claim received a verdict of CONFIRMED, CORRECTED, or UNSETTLED with a citation and the version the fact holds for. Every CORRECTED verdict was applied to the skill's references before this file was written.

## Summary

| Theme | Claims | Confirmed | Corrected | Unsettled |
|---|---|---|---|---|
| Schema, DDL, JSON, partitioning | 16 | 10 | 6 | 0 (4 sub-points) |
| Transactions, isolation, recovery, tuning | 16 | 9 | 7 | 0 (4 sub-points) |
| TiDB Cloud, drivers, AI features | 16 | 9 | 6 | 1 |

## Corrections that changed the skill

| Claim as drafted | Verdict | What the skill now says |
|---|---|---|
| `JSON_TABLE` available from v6.5 | Unsupported on TiDB | Removed; unnest via multi-valued index and `MEMBER OF`, or in the application |
| Default collation depends on `new_collations_enabled_on_first_bootstrap` | Default is always `utf8mb4_bin` | Set a `_ci` collation explicitly when case-insensitive `=` is expected |
| `@prisma/adapter-tidbcloud` | Package is `@tidbcloud/prisma-adapter` | Corrected name; notes `driverAdapters` went GA in Prisma 6.16 |
| Kysely dialect `TiDBCloudServerlessDialect` | Export is `TiDBServerlessDialect` | Corrected |
| TiDB Cloud Serverless is branded TiDB X | Renamed TiDB Cloud Starter (2025-08-12); TiDB X is the architecture | Corrected; Premium tier added |
| Full-text search on Starter and Essential and recent self-managed | Starter only, five AWS regions; self-managed and Dedicated parse but do not index | Corrected in the availability gate and Version Guide |
| Pool idle timeout at or below 300 s because the gateway closes idle connections | Docs give 340 s on AWS public endpoints and recommend a 5-minute max lifetime | Kept 300 s as the safe setting, cited the 340 s figure |
| `tidb_analyze_column_options` default PREDICATE | Default ALL; PREDICATE only on clusters created v8.3.0 to v8.5.4 | Corrected in statistics and session-variables references |
| `tidb_auto_analyze_concurrency` new in v8.5 | New in v8.4.0 | Corrected |
| Setting `SERIALIZABLE` fails | Error 8048 unless `tidb_skip_isolation_level_check = 1` | Added the variable and an error-code table |
| Transaction size limit 100 MiB, up to 1 TiB | Max 1 TB; superseded by `tidb_mem_quota_query` from v6.5.0 | Corrected |
| TTL and TiFlash replicas combine | Undocumented | Now says to test it |
| `ticloud serverless branch create --name` | Flag is `--display-name` | Corrected |
| Expression defaults such as `DEFAULT (UUID())` from v8.0 | `UUID()` predates v8.0; the wider list arrived v8.0.0, GA v8.1.0 | Corrected |
| Foreign keys default-on from v7.x | Default-on from v6.6.0, GA v8.5.0 | Corrected |
| Global indexes v8.3 | v8.3.0 experimental, GA v8.4.0 | Corrected |
| `FLASHBACK CLUSTER` unavailable on Starter and Essential | Also Premium | Corrected |

## Still unsettled

- TTL behaviour on tables with TiFlash replicas: no documentation either way.
- Essential support for full-text search: the live page says Starter only; the source of that page and the `CREATE INDEX` page still list Essential.
- The version in which `NO_DECORRELATE()` began injecting `LIMIT 1` into `EXISTS` subqueries, and the version of the "both hints ineffective" warning: planner source only.
- Whether `previewFeatures = ["driverAdapters"]` can be dropped for the TiDB Prisma adapter on Prisma 6.16+: Prisma says GA, TiDB docs still show the flag.
- Any docs statement that scans or hotspots consume more Request Units: only the general "operation type and amount of data" definition exists.
- The vector index's ascending-only requirement: enforced in planner source, not stated in docs.

## Detailed findings

## Part 1: Schema, DDL, JSON, partitioning


Sources: `docs.pingcap.com/tidb/stable/` (v8.5 LTS docs; raw markdown checked on the `release-8.5` branch of `pingcap/docs`), TiDB release notes, and `pingcap/tidb` source on the `release-8.5` branch. Verified 2026-09-09.

### 1. `AUTO_ID_CACHE 1` — centrally allocated, monotonic, MySQL-compatible

**Verdict: CORRECTED** (mechanism right; "throughput cost" and the introduction version need precision).

Accurate statement: Setting `AUTO_ID_CACHE 1` enables the MySQL compatibility mode: "IDs are strictly increasing across all TiDB instances, each ID is guaranteed to be unique, and gaps between IDs are minimal compared to the default cache mode (`AUTO_ID_CACHE 0` with 30000 cached values)." The centralized allocating service arrived in **v6.4.0 (experimental)** and became **GA in v6.5.0**. The `AUTO_ID_CACHE` table option itself dates to v3.0.14. On cost: before v6.4.0 "each ID allocation requires a TiKV transaction, which affects performance"; from v6.4.0 allocation is an in-memory operation in a centralized service, and the v6.5.0 notes state "insert TPS of a table using this feature is expected to exceed 20,000". So the modern cost is a single-leader allocation path, not a per-row TiKV transaction; the docs do not quantify a throughput penalty versus `AUTO_ID_CACHE 0`.

- https://docs.pingcap.com/tidb/stable/auto-increment/#mysql-compatibility-mode (v8.5)
- https://docs.pingcap.com/tidb/stable/release-6.4.0/ — "TiDB v6.4.0 introduces the `AUTO_INCREMENT` MySQL compatibility mode ... a centralized auto-increment ID allocating service" (experimental)
- https://docs.pingcap.com/tidb/stable/release-6.5.0/ — "In v6.5.0, this feature becomes GA."
- https://docs.pingcap.com/tidb/stable/release-3.0.14/ — "Add the `ALTER TABLE ... AUTO_ID_CACHE` syntax"

### 2. TTL table attribute

**Verdict: CORRECTED** (syntax, options, history table, global switch, and FK limitation confirmed; column-type rule is documented only in source; TiFlash claim unsupported by docs; versions supplied).

Confirmed: `CREATE TABLE ... TTL = created_at + INTERVAL 3 MONTH TTL_ENABLE = 'OFF'`; `ALTER TABLE t1 TTL = ...`, `ALTER TABLE t1 TTL_ENABLE = 'OFF'`, `ALTER TABLE t1 REMOVE TTL`; "For a table with the TTL attribute, `TTL_ENABLE` is `ON` by default"; "`TTL_JOB_INTERVAL` is set to `1h` by default"; `SET @@global.tidb_ttl_job_enable = OFF` disables jobs cluster-wide (variable new in v6.5.0, default `ON`); "The `mysql.tidb_ttl_job_history` table contains information about the TTL jobs that have been executed. The record of TTL job history is kept for 90 days."

Versions: experimental in **v6.5.0** ("Provide row-level Time to live (TTL) to manage data lifecycle (experimental)"); **GA in v7.0.0** ("Time to live (TTL) is generally available").

Foreign keys: the docs phrase it as "A table with the TTL attribute does not support being referenced by other tables as the primary table in a foreign key constraint." That is: a TTL table cannot be the *parent* (referenced) table. The docs do not forbid a TTL table from being a *child* table that holds a foreign key.

Column type: the docs page does not list allowed types; it only shows `TIMESTAMP` and `DATE` examples. The source enforces it: `checkTTLInfoColumnType` rejects any non-time type with error 8148 "Field '%s' is of a not supported type for TTL config, expect DATETIME, DATE or TIMESTAMP". So the claim's type list is correct, but its authority is source, not docs.

TiFlash: neither `time-to-live.md` nor the TiFlash compatibility pages mention TTL. No documented restriction and no documented guarantee — treat "TTL works with TiFlash replicas" as unverified (see Unsettled).

- https://docs.pingcap.com/tidb/stable/time-to-live/ (v8.5)
- https://docs.pingcap.com/tidb/stable/system-variables/#tidb_ttl_job_enable-new-in-v650
- https://docs.pingcap.com/tidb/stable/release-6.5.0/ ; https://docs.pingcap.com/tidb/stable/release-7.0.0/
- https://github.com/pingcap/tidb/blob/release-8.5/pkg/ddl/ttl.go (`checkTTLInfoColumnType`) ; https://github.com/pingcap/tidb/blob/release-8.5/pkg/errno/errname.go (`ErrUnsupportedColumnInTTLConfig`, code 8148)

### 3. Multi-valued indexes and `MEMBER OF` from v6.6.0

**Verdict: CONFIRMED** (with status detail added).

"TiDB introduces MySQL-compatible multi-valued indexes in v6.6.0" (experimental in v6.6.0, listed as **GA in v7.1.0**). Syntax: `CAST(... AS ... ARRAY)` inside an index definition, e.g. `INDEX zips((CAST(custinfo->'$.zipcode' AS UNSIGNED ARRAY)))`; the claim's `CAST(payload->'$.tags' AS CHAR(64) ARRAY)` fits that form (target type may not be `BINARY`, `JSON`, `YEAR`, `FLOAT`, or `DECIMAL`). `MEMBER OF()` and `JSON_OVERLAPS()` appear in the v6.6 JSON functions page and not in the v6.5 page, so v6.6.0 is the right version for `MEMBER OF` too; v7.4.0 added TiKV push-down for it. Access is via IndexMerge from `MEMBER OF`, `JSON_CONTAINS`, `JSON_OVERLAPS` conditions. Cross-version note: such tables cannot be restored/replicated/imported into clusters earlier than v6.6.0.

- https://docs.pingcap.com/tidb/stable/sql-statement-create-index/#multi-valued-indexes
- https://docs.pingcap.com/tidb/stable/choose-index/#use-multi-valued-indexes
- https://docs.pingcap.com/tidb/stable/release-6.6.0/ (experimental) ; https://docs.pingcap.com/tidb/stable/release-7.1.0/ (GA) ; https://docs.pingcap.com/tidb/stable/release-7.4.0/ (push-down)
- https://docs.pingcap.com/tidb/v6.6/json-functions/ vs https://docs.pingcap.com/tidb/v6.5/json-functions/

### 4. `JSON_TABLE` supported from v6.5.0

**Verdict: CORRECTED.**

Accurate statement: `JSON_TABLE()` is **not supported** in TiDB. The JSON functions reference lists it under "Unsupported functions" in both the v8.5 (stable) and `master` (dev) docs, alongside `JSON_SCHEMA_VALIDATION_REPORT()` and `JSON_VALUE()`. No release note introduces it.

- https://docs.pingcap.com/tidb/stable/json-functions/#unsupported-functions (v8.5; same on /tidb/dev/)

### 5. Global indexes on partitioned tables from v8.3.0

**Verdict: CONFIRMED.**

"TiDB introduces the global indexes feature in v8.3.0" as **experimental**; **GA in v8.4.0**, when `tidb_enable_global_index` was deprecated and fixed to `ON`. A `GLOBAL` index lets "primary keys and unique keys ... remain globally unique even when they do not include partition keys." History: v7.6.0 added `tidb_enable_global_index` while "still under development". Extra detail: from v8.5.4 non-unique indexes can also be global; a primary key without the partition key must be declared `NONCLUSTERED GLOBAL`. Error when omitted: `ERROR 8264 (HY000): Global Index is needed for index 'col1', since the unique index is not including all partitioning columns, and GLOBAL is not given as IndexOption`.

- https://docs.pingcap.com/tidb/stable/global-indexes/ (Version history section)
- https://docs.pingcap.com/tidb/stable/release-8.3.0/ ; https://docs.pingcap.com/tidb/stable/release-8.4.0/
- https://docs.pingcap.com/tidb/stable/system-variables/#tidb_enable_global_index-new-in-v760

### 6. Foreign keys enforced from v6.6.0; defaults ON

**Verdict: CONFIRMED** (with GA version added).

"Starting from v6.6.0, TiDB supports foreign keys and foreign key constraints. Starting from v8.5.0, this feature becomes generally available." Earlier: "Before v6.6.0, TiDB supports the syntax of creating foreign keys, but the created foreign keys are ineffective" — and they stay ineffective after upgrade (shown as `/* FOREIGN KEY INVALID */`). Both `tidb_enable_foreign_key` (new in v6.3.0) and `foreign_key_checks`: "Before v6.6.0, the default value is `OFF`. Starting from v6.6.0, the default value is `ON`."

- https://docs.pingcap.com/tidb/stable/foreign-key/
- https://docs.pingcap.com/tidb/stable/system-variables/#tidb_enable_foreign_key-new-in-v630 ; https://docs.pingcap.com/tidb/stable/system-variables/#foreign_key_checks
- https://docs.pingcap.com/tidb/stable/release-6.6.0/ ; https://docs.pingcap.com/tidb/stable/release-8.5.0/

### 7. `tidb_ddl_enable_fast_reorg` default ON from v6.5.0

**Verdict: CONFIRMED.**

Variable new in v6.3.0 (experimental, default `OFF`); v6.5.0: "this feature becomes GA and is enabled by default"; current default `ON`. Verification: `ADMIN SHOW DDL JOBS` shows `ingest` in `JOB_TYPE`.

- https://docs.pingcap.com/tidb/stable/system-variables/#tidb_ddl_enable_fast_reorg-new-in-v630
- https://docs.pingcap.com/tidb/stable/release-6.5.0/

### 8. Expression defaults such as `DEFAULT (UUID())` from v8.0.0

**Verdict: CORRECTED** (version is right for the general feature; `UUID()`/`RAND()`/sequence defaults predate it, and GA is v8.1.0).

Accurate statement: v8.0.0 introduced (experimental) support for a limited set of expressions as column defaults; **GA in v8.1.0**, which also allowed them in `ADD COLUMN`. The v8.1.0 note clarifies pre-v8.0.0 defaults were "limited to strings, numbers, dates, and certain expressions" — the reference page lists `NEXT VALUE FOR`, `RAND()`, `UUID()`, and `UUID_TO_BIN()` as long-standing exceptions, so `DEFAULT (UUID())` alone is not the v8.0.0 novelty. The supported list today: `UPPER(SUBSTRING_INDEX(USER(), '@', 1))`, `REPLACE(UPPER(UUID()), '-', '')`, four fixed `DATE_FORMAT(NOW(), ...)` patterns, `STR_TO_DATE('1980-01-01', '%Y-%m-%d')`, `CURRENT_TIMESTAMP()`/`CURRENT_DATE()`, `JSON_OBJECT()`/`JSON_ARRAY()`/`JSON_QUOTE()`, `NEXTVAL()`, `RAND()`, `UUID()`, `UUID_TO_BIN()`, `VEC_FROM_TEXT()`. From v8.0.0, `BLOB`/`TEXT`/`JSON` columns may take defaults, but only expressions, not literals.

- https://docs.pingcap.com/tidb/stable/data-type-default-values/#specify-expressions-as-default-values
- https://docs.pingcap.com/tidb/stable/release-8.0.0/ (experimental) ; https://docs.pingcap.com/tidb/stable/release-8.1.0/ (GA)

### 9. `SPLIT TABLE`, `SHARD_ROW_ID_BITS`, `AUTO_RANDOM`

**Verdict: CONFIRMED** (one nuance on ALTER).

- `SPLIT TABLE t BETWEEN (lower) AND (upper) REGIONS n`: "the current region will be evenly spilt into the number of regions (as specified in `region_num`) between the upper and lower boundaries." `PRE_SPLIT_REGIONS` is the create-time alternative (2^N Regions).
- `SHARD_ROW_ID_BITS`: "For tables with a non-clustered primary key or no primary key, TiDB uses the automatically generated `_tidb_rowid`"; "`SHARD_ROW_ID_BITS = 4` indicates 16 shards".
- `AUTO_RANDOM(S, R)`: "`S` is the number of shard bits. The value ranges from `1` to `15`. The default value is `5`."
- ALTER: "You cannot use `ALTER TABLE` to modify the `AUTO_RANDOM` attribute, including adding or removing this attribute." Nuance: the same page documents `ALTER TABLE t MODIFY COLUMN id BIGINT AUTO_RANDOM(5)` to convert an existing `BIGINT` `AUTO_INCREMENT` primary key to `AUTO_RANDOM` (blocked only if the current max is near the type max). So "cannot add via ALTER" is true except for this AUTO_INCREMENT-to-AUTO_RANDOM conversion.
- `@@allow_auto_random_explicit_insert` (new in v4.0.3, default `OFF`): "To insert values explicitly, you need to set the value of the `@@allow_auto_random_explicit_insert` system variable to `1` (`0` by default)."
- `ALTER TABLE t AUTO_RANDOM_BASE=0`: "automatically determines an appropriate base value. Although it produces a warning message similar to `Can't reset AUTO_INCREMENT to 0 without FORCE option, using XXX instead`, the base value **will** change"; `FORCE AUTO_RANDOM_BASE = 0` is an error; `FORCE` needs a non-zero positive integer.

- https://docs.pingcap.com/tidb/stable/sql-statement-split-region/
- https://docs.pingcap.com/tidb/stable/shard-row-id-bits/
- https://docs.pingcap.com/tidb/stable/auto-random/ (Restrictions; "Modify AUTO_RANDOM_BASE")
- https://docs.pingcap.com/tidb/stable/system-variables/#allow_auto_random_explicit_insert-new-in-v403

### 10. Partition types; SUBPARTITION unsupported

**Verdict: CONFIRMED.**

"Currently, TiDB supports Range partitioning, Range COLUMNS partitioning, List partitioning, List COLUMNS partitioning, Hash partitioning, and Key partitioning. Other partitioning types that are available in MySQL are not supported yet in TiDB." Key partitioning is new in v7.0.0. MySQL-compatibility page: "The following syntaxes are not supported for partitioned tables: `SUBPARTITION`, `{CHECK|OPTIMIZE|REPAIR|IMPORT|DISCARD|REBUILD} PARTITION`". An unsupported type yields `Warning: Unsupported partition type %s, treat as normal table`.

- https://docs.pingcap.com/tidb/stable/partitioned-table/
- https://docs.pingcap.com/tidb/stable/mysql-compatibility/#partitioning

### 11. Multi-change `ALTER TABLE`; `ALGORITHM` assertion; index-type decorations

**Verdict: CONFIRMED.**

"When using a single `ALTER TABLE` statement to alter multiple schema objects (such as columns or indexes) of a table, specifying the same object in multiple changes is not supported. For example ... `ALTER TABLE t1 MODIFY COLUMN c1 INT, DROP COLUMN c1` ... the `Unsupported operate same column/index` error is output." Also: statements are validated against the schema before execution, and changes run left to right. "`ALGORITHM={INSTANT,INPLACE,COPY}` syntax functions only as an assertion"; `ALGORITHM=INSTANT` on an INPLACE op errors (`ERROR 1846`), while `ALGORITHM=COPY` on an INPLACE op only warns ("this algorithm or better"). "Different types of indexes (`HASH|BTREE|RTREE|FULLTEXT`) are not supported, and will be parsed and ignored when specified."

- https://docs.pingcap.com/tidb/stable/mysql-compatibility/#ddl-operations
- https://docs.pingcap.com/tidb/stable/sql-statement-alter-table/#mysql-compatibility

### 12. `lower_case_table_names` supports only 2

**Verdict: CONFIRMED.**

"The default value in TiDB is `2`, and only `2` is currently supported." (The variable has no entry of its own in the system-variables page; the compatibility page is the source.)

- https://docs.pingcap.com/tidb/stable/mysql-compatibility/#default-differences

### 13. Default utf8mb4 collation

**Verdict: CORRECTED** (default is right; the conditional on `new_collations_enabled_on_first_bootstrap` is wrong).

Accurate statement: TiDB's default character set is `utf8mb4` and its default collation is `utf8mb4_bin` regardless of `new_collations_enabled_on_first_bootstrap`. That config (default `true`, effective only at first bootstrap) controls whether non-binary collations are *semantically* supported — under the new framework TiDB supports `utf8_general_ci`, `utf8mb4_general_ci`, `utf8_unicode_ci`, `utf8mb4_unicode_ci`, `utf8mb4_0900_bin`, `utf8mb4_0900_ai_ci`, `gbk_chinese_ci`, `gbk_bin`; under the old framework they are accepted but treated as binary. What can change the *effective* default is the client's connection collation: "Starting from v7.4.0, if your client uses `utf8mb4_0900_ai_ci` as the connection collation, TiDB follows the client's configuration"; before v7.4.0 it fell back to `utf8mb4_bin`.

- https://docs.pingcap.com/tidb/stable/character-set-and-collation/ (charset table: utf8mb4 -> `utf8mb4_bin`; "New framework for collations")
- https://docs.pingcap.com/tidb/stable/tidb-configuration-file/#new_collations_enabled_on_first_bootstrap
- https://docs.pingcap.com/tidb/stable/mysql-compatibility/#default-differences

### 14. `OPTIMIZE TABLE` errors (not a silent no-op)

**Verdict: CONFIRMED.**

Docs: the MySQL-compatibility "Unsupported features" list includes "`OPTIMIZE TABLE` syntax". Behaviour (source, `release-8.5` and `master`): the parser accepts the statement, and the planner returns `dbterror.ErrGeneralUnsupportedDDL.GenWithStack("OPTIMIZE TABLE is not supported")`; the integration test asserts the exact message `[ddl:8200]OPTIMIZE TABLE is not supported` (error code 8200). The docs do not print the error text; only source does.

- https://docs.pingcap.com/tidb/stable/mysql-compatibility/#unsupported-features
- https://github.com/pingcap/tidb/blob/release-8.5/pkg/planner/core/planbuilder.go (`case *ast.OptimizeTableStmt`, ~line 5757)
- https://github.com/pingcap/tidb/blob/release-8.5/pkg/ddl/db_integration_test.go (`tk.MustGetErrMsg("optimize table t", "[ddl:8200]OPTIMIZE TABLE is not supported")`)

### 15. `GROUP BY` does not imply `ORDER BY`

**Verdict: CONFIRMED.**

"`SELECT .. GROUP BY expr` does not imply `GROUP BY expr ORDER BY expr` as it does in MySQL 5.7."

- https://docs.pingcap.com/tidb/stable/mysql-compatibility/#sql-syntax-and-behavior-differences (v8.5)

### 16. Vector search: `VECTOR(D)`, distance functions, HNSW, TiFlash, `ORDER BY ... LIMIT`

**Verdict: CONFIRMED** (with status and function-scope detail added).

"For TiDB Self-Managed, the TiDB version must be v8.4.0 or later (v8.5.0 or later is recommended)." Status: **experimental** in v8.4.0 and still labelled experimental / "public preview" in v8.5.0 docs and release notes. Types: `VECTOR` (any dimension) and `VECTOR(D)` (fixed); up to 16383 dimensions; an index needs a fixed `D`. Functions: `VEC_L2_DISTANCE`, `VEC_COSINE_DISTANCE`, `VEC_NEGATIVE_INNER_PRODUCT`, `VEC_L1_DISTANCE`, plus `VEC_DIMS`, `VEC_FROM_TEXT`, etc. Index: HNSW only; syntax `VECTOR INDEX idx ((VEC_COSINE_DISTANCE(embedding)))` in `CREATE TABLE`, or `CREATE VECTOR INDEX ... ON t ((VEC_L2_DISTANCE(col)))` / `ALTER TABLE ... ADD VECTOR INDEX ...` (`USING HNSW` optional). "TiFlash nodes must be deployed in your cluster in advance"; "The vector search index feature relies on TiFlash replicas for tables" (auto-created if the index is in `CREATE TABLE`, otherwise `SET TIFLASH REPLICA 1` first). Only `VEC_COSINE_DISTANCE()` and `VEC_L2_DISTANCE()` are indexable. Usage: "make sure that the `ORDER BY ... LIMIT` clause uses the same distance function as the one specified when creating the vector index"; a `WHERE` pre-filter defeats the index. Ascending-only is not stated in docs but is enforced in the planner: `// Currently vector index only accept ascending order. if lt.ByItems[0].Desc { return ret }`, alongside single `ORDER BY` item, TopN directly above the DataSource, and no pushed-down filters.

- https://docs.pingcap.com/tidb/stable/vector-search-overview/ (redirects to /ai/concepts/)
- https://docs.pingcap.com/tidb/stable/vector-search-index/ (Restrictions; "Use the vector index")
- https://docs.pingcap.com/tidb/stable/vector-search-data-types/ ; https://docs.pingcap.com/tidb/stable/vector-search-functions-and-operators/ ; https://docs.pingcap.com/tidb/stable/vector-search-limitations/
- https://docs.pingcap.com/tidb/stable/release-8.4.0/ (experimental) ; https://docs.pingcap.com/tidb/stable/release-8.5.0/ ("experimental, introduced in v8.4.0")
- https://github.com/pingcap/tidb/blob/release-8.5/pkg/planner/core/exhaust_physical_plans.go (~line 2400, TopN -> ANN property)

### Unsettled

- **TTL with TiFlash replicas (claim 2).** Looked in `time-to-live.md` (stable and master), `tiflash/tiflash-compatibility.md`, `tiflash/tiflash-overview.md`, and a repo-wide search of `pingcap/docs` for TTL+TiFlash. No page states a restriction or a guarantee. Treat as undocumented rather than confirmed.
- **TTL column type list (claim 2).** Correct per source (error 8148 expects `DATETIME`, `DATE` or `TIMESTAMP`), but the docs page never lists the allowed types; cite source if this must be authoritative.
- **Quantified throughput cost of `AUTO_ID_CACHE 1` (claim 1).** Docs describe the mechanism and a ">20,000 insert TPS" expectation from v6.5.0 but give no benchmark against the default cache mode.
- **Vector index ascending-only rule (claim 16).** Enforced in planner source; the docs only say "`ORDER BY ... LIMIT`" with the matching distance function and do not mention `DESC`.

## Part 2: Transactions, isolation, recovery, tuning


Method: every citation below is the official TiDB docs (`docs.pingcap.com/tidb/stable/...`, which currently renders the `release-8.5` branch of `pingcap/docs`), an older docs branch where a version change had to be located, a release note, or `pingcap/tidb` source on GitHub. No blog or forum content was used as a citation. "Version" = the TiDB version the docs page describes unless stated.

### 1. Pessimistic mode is the default since v3.0.8 for new clusters

**Verdict: CONFIRMED.**

- Docs: "Since TiDB 3.0.8, the pessimistic transaction mode is enabled by default. If you upgrade TiDB from v3.0.7 or earlier versions to v3.0.8 or later versions, the default transaction mode does not change. Only the newly created clusters use the pessimistic transaction mode by default." Default value of `tidb_txn_mode` is `pessimistic`; possible values `pessimistic`, `optimistic` (`""` also means optimistic).
- Source: https://docs.pingcap.com/tidb/stable/system-variables/#tidb_txn_mode ; https://docs.pingcap.com/tidb/stable/pessimistic-transaction/
- Version: v3.0.8+; docs page describes v8.5.

### 2. Snapshot isolation reported as REPEATABLE READ; READ COMMITTED in pessimistic mode only; SERIALIZABLE / READ UNCOMMITTED unsupported

**Verdict: CORRECTED (mostly right; the "what happens" part is: error 8048 unless `tidb_skip_isolation_level_check=1`).**

Accurate statement:
- TiDB implements Snapshot Isolation and "advertises `REPEATABLE-READ` for compatibility with MySQL, but the actual isolation level is Snapshot Isolation." `transaction_isolation` default `REPEATABLE-READ`.
- "Starting from TiDB v4.0.0-beta, TiDB supports the Read Committed isolation level." It "only takes effect in the pessimistic transaction mode"; in optimistic mode setting it "does not take effect and transactions still use the Repeatable Read isolation level."
- Setting an unsupported level returns `ERROR 8048 (HY000): The isolation level 'serializable' is not supported. Set tidb_skip_isolation_level_check=1 to skip this error`. With `tidb_skip_isolation_level_check=1` (default `OFF`), the SET succeeds with one warning and "no error is reported. This helps improve compatibility with applications that set (but do not depend on) a different isolation level." The isolation actually used does not change.
- Sources: https://docs.pingcap.com/tidb/stable/transaction-isolation-levels/ ; https://docs.pingcap.com/tidb/stable/system-variables/#tidb_skip_isolation_level_check ; https://docs.pingcap.com/tidb/stable/system-variables/#transaction_isolation ; https://docs.pingcap.com/tidb/stable/error-codes/ (Error 8048); source message: https://github.com/pingcap/tidb/blob/master/pkg/errno/errname.go (`ErrUnsupportedIsolationLevel` = 8048).
- Version: RC since v4.0.0-beta; page describes v8.5.

### 3. `txn-total-size-limit` default 100 MiB, configurable maximum

**Verdict: CORRECTED (default right; maximum is 1 TB in current docs; history below).**

Accurate statement:
- `txn-total-size-limit`: "The size limit of a single transaction in TiDB. Default value: `104857600` (in bytes)... The maximum value of this parameter is `1099511627776` (1 TB)."
- History from the docs branches: v4.0 through v5.2 docs state the maximum is `10737418240` (10 GB); v5.3 docs onward state `1099511627776` (1 TB). (No release-note line announcing the 10 GB → 1 TB change was found; the evidence is the per-branch config docs.)
- Not removed, but de-emphasised: "In TiDB v6.5.0 and later versions, this configuration is no longer recommended. The memory size of a transaction will be accumulated into the memory usage of the session, and the `tidb_mem_quota_query` variable will take effect when the session memory threshold is exceeded." If it is left at the default after an upgrade, `tidb_mem_quota_query` governs; if set to a non-default value, the old per-transaction size limit still applies.
- In `tidb_dml_type = "bulk"` mode (v8.0.0+) "transaction size is not limited by the TiDB configuration item `txn-total-size-limit`."
- Sources: https://docs.pingcap.com/tidb/stable/tidb-configuration-file/#txn-total-size-limit ; https://docs.pingcap.com/tidb/v5.2/tidb-configuration-file/#txn-total-size-limit (10 GB) vs https://docs.pingcap.com/tidb/v5.3/tidb-configuration-file/#txn-total-size-limit (1 TB); https://docs.pingcap.com/tidb/stable/release-6.5.0/ (memory-tracking change).
- Version: v8.5 docs; change points v5.3 (max) and v6.5.0 (semantics).

### 4. `tidb_gc_life_time` default 10m; long transactions can fail with a GC error

**Verdict: CONFIRMED (error is 9006 "GC life time is shorter than transaction duration").**

- `tidb_gc_life_time` (New in v5.0): default `10m0s`, range `[10m0s, 8760h0m0s]` for self-managed / Dedicated. Note in docs: a transaction that has run longer than `tidb_gc_life_time` has its data since `start_ts` retained during GC — but only up to `tidb_gc_max_wait_time` (New in v6.1.0, default `86400` s), after which "the GC safe point is forwarded forcefully."
- Error: `ERROR 9006 (HY000): GC life time is shorter than transaction duration`. "The interval of `GC Life Time` is too short. The data that should have been read by long transactions might be deleted. You can adjust `tidb_gc_life_time`." Source name `ErrTxnAbortedByGC` = 9006.
- Related: pessimistic transactions are additionally capped by `max-txn-ttl` (default 1 hour): "Open transactions in TiDB do not block garbage collection (GC). By default, this limits the maximum execution time of pessimistic transactions to 1 hour."
- Sources: https://docs.pingcap.com/tidb/stable/system-variables/#tidb_gc_life_time-new-in-v50 ; https://docs.pingcap.com/tidb/stable/system-variables/#tidb_gc_max_wait_time-new-in-v610 ; https://docs.pingcap.com/tidb/stable/error-codes/ (9006); https://docs.pingcap.com/tidb/stable/pessimistic-transaction/ ; https://github.com/pingcap/tidb/blob/master/pkg/errno/errcode.go
- Version: v8.5 docs.

### 5. Optimistic write conflicts surface at COMMIT; app-level retry; error codes

**Verdict: CONFIRMED (codes: 8005 and 9007; note the v8.0.0 auto-retry removal).**

- "With optimistic transactions, conflicting changes are detected as part of a transaction commit." Conflict detection happens in TiKV "mainly in the prewrite phase."
- Retry guidance: "Starting from v8.0.0, the `tidb_disable_txn_auto_retry` system variable is deprecated, and TiDB no longer supports automatic retries of optimistic transactions. It is recommended to use the Pessimistic transaction mode. If you encounter optimistic transaction conflicts, you can capture the error and retry transactions in your application." (Before v8.0.0 auto-retry existed but was off by default since v3.0.0 because it can break RR isolation.)
- Error codes: `ERROR 8005 (HY000): Write Conflict, txnStartTS is stale` ("Transactions in TiDB encounter write conflicts. Check your application logic and retry the write operation.") and `ERROR 9007 (HY000): Write conflict` (TiKV-side; full message `Write conflict, txnStartTS=..., conflictStartTS=..., conflictCommitTS=..., key=..., reason=...`). Source names: `ErrWriteConflictInTiDB` = 8005, `ErrWriteConflict` = 9007. Also 8022 "The transaction commit fails and has been rolled back. The application can safely retry the whole transaction."
- Sources: https://docs.pingcap.com/tidb/stable/optimistic-transaction/ ; https://docs.pingcap.com/tidb/stable/error-codes/ ; https://github.com/pingcap/tidb/blob/master/pkg/errno/errname.go
- Version: v8.5 docs; auto-retry removed v8.0.0.

### 6. Error 1213 deadlock; 8028 schema changed and retryable; `innodb_lock_wait_timeout` default 50s

**Verdict: CONFIRMED, with a precision on 8028's message and retryability.**

- 1213: "a deadlock will occur. This is automatically detected, and one of the transactions will randomly be terminated with a MySQL-compatible error code `1213` returned." (Source: `ErrLockDeadlock` = 1213, "Deadlock found when trying to get lock; try restarting transaction".) Note: the error-codes doc page does not list 1213; the pessimistic-transaction page does.
- 8028: source message is "Information schema is changed during the execution of the statement(for example, table definition may be updated by other DDL ran in parallel). If you see this error often, try increasing `tidb_max_delta_schema_count`". Docs: when the metadata lock is disabled and the schema changed during the transaction, "the transaction commit fails with this error. At this time, the application can safely retry the whole transaction." With metadata lock enabled (GA and default since v6.5.0), the error is largely avoided; it can still occur on a lossy column type change, where "the query fails while the transaction will not roll back automatically."
- `innodb_lock_wait_timeout`: default `50`, range `[1, 3600]`, seconds, "The lock wait timeout for pessimistic transactions (default)." On timeout "a MySQL-compatible error code `1205` is returned."
- Sources: https://docs.pingcap.com/tidb/stable/pessimistic-transaction/ ; https://docs.pingcap.com/tidb/stable/error-codes/ (8028); https://docs.pingcap.com/tidb/stable/system-variables/#innodb_lock_wait_timeout ; https://github.com/pingcap/tidb/blob/master/pkg/errno/errname.go
- Version: v8.5 docs; metadata lock GA v6.5.0.

### 7. `SELECT ... FOR UPDATE`: locks in pessimistic mode; in optimistic mode records rows for commit-time conflict check

**Verdict: CONFIRMED.**

- Pessimistic: "For `SELECT FOR UPDATE` statements, a pessimistic lock is applied on the latest version of the committed data, instead of on the modified rows."
- Optimistic: "When TiDB uses the Optimistic Transaction Mode, the transaction conflicts are not detected in the statement execution phase. Therefore, the current transaction does not block other transactions from executing `UPDATE`, `DELETE` or `SELECT FOR UPDATE` like other databases such as PostgreSQL. In the committing phase, the rows read by `SELECT FOR UPDATE` are committed in two phases, which means they can also join the conflict detection. If write conflicts occur, the commit fails for all transactions that include the `SELECT FOR UPDATE` clause."
- Sources: https://docs.pingcap.com/tidb/stable/sql-statement-select/ (FOR UPDATE row of the parameter table); https://docs.pingcap.com/tidb/stable/pessimistic-transaction/
- Version: v8.5 docs.

### 8. FLASHBACK TABLE / DATABASE / CLUSTER; `AS OF TIMESTAMP`

**Verdict: CORRECTED (TiDB Cloud exclusion list also includes Premium; AS OF TIMESTAMP is v5.1.0).**

Accurate statement:
- `FLASHBACK TABLE`: "introduced since TiDB 4.0"; restores tables dropped by `DROP`/`TRUNCATE` within GC lifetime; cannot restore the same dropped table twice.
- `FLASHBACK DATABASE`: "TiDB v6.4.0 introduces the `FLASHBACK DATABASE` syntax."
- `FLASHBACK CLUSTER TO TIMESTAMP`: introduced v6.4.0 (experimental in that release); `TO TSO` added in v6.5.6, v7.1.3, v7.5.1, v7.6.0. "Only a user with the `SUPER` privilege can execute." Target time "must be within the Garbage Collection (GC) lifetime." "not applicable to TiDB Cloud Starter, Essential, and Premium instances" (the docs no longer say "Serverless"). "cannot be canceled after being executed. TiDB will keep retrying until it succeeds." Metadata rollbacks "will **not** be replicated by TiCDC" — pause the changefeed, reconcile schemas, recreate it. Also: v7.1.0 has a known Region-stuck bug (#44292); BR restore/log backup constraints apply.
- `SELECT ... AS OF TIMESTAMP` (Stale Read): introduced in v5.1.0 as experimental ("Introduce a new SQL syntax `AS OF TIMESTAMP` to perform Stale Read"). Forms: `SELECT ... AS OF TIMESTAMP`, `START TRANSACTION READ ONLY AS OF TIMESTAMP`, `SET TRANSACTION READ ONLY AS OF TIMESTAMP`. Timestamp must not be earlier than the GC safe point.
- Sources: https://docs.pingcap.com/tidb/stable/sql-statement-flashback-table/ ; https://docs.pingcap.com/tidb/stable/sql-statement-flashback-database/ ; https://docs.pingcap.com/tidb/stable/sql-statement-flashback-cluster/ ; https://docs.pingcap.com/tidb/stable/release-6.4.0/ ; https://docs.pingcap.com/tidb/stable/release-5.1.0/ ; https://docs.pingcap.com/tidb/stable/as-of-timestamp/
- Version: as listed; pages describe v8.5.

### 9. Statistics variables

**Verdict: CORRECTED (two version/default errors).**

| Item | Verdict | Accurate statement |
|---|---|---|
| `SHOW STATS_HEALTHY` 0-100 | CONFIRMED | "The healthy percentage between 0 and 100". Formula: health = 0 when `modify_count` >= `row_count`, else `(1 - modify_count/row_count) * 100`. |
| `tidb_auto_analyze_ratio` default 0.5 | CONFIRMED | Default `0.5`, range `(0, 1]` (v8.0.0 and earlier: `[0, 18446744073709551615]`). |
| `tidb_analyze_column_options` default PREDICATE | CORRECTED | New in v8.3.0. Documented default value is `ALL`. `PREDICATE` was the default only for newly deployed clusters from v8.3.0 to v8.5.4; upgraded clusters get `ALL`; new clusters from v8.5.5 (and v9.0.0) get `ALL`. Only works with `tidb_analyze_version = 2`. |
| `tidb_auto_analyze_concurrency` introduced v8.5.0 | CORRECTED | New in v8.4.0 (before that, concurrency fixed at 1). Default `3`; "Starting from v8.5.7 [and v9.0.0], the default value changes from `1` to `3`." |
| `tidb_enable_pseudo_for_outdated_stats` default OFF | CONFIRMED | New in v5.3.0, default `OFF`. |
| `tidb_stats_load_sync_wait` default 100 ms | CONFIRMED | New in v5.4.0, default `100`, unit milliseconds, range `[0, 2147483647]`; `0` disables sync load. |

- Sources: https://docs.pingcap.com/tidb/stable/sql-statement-show-stats-healthy/ ; https://docs.pingcap.com/tidb/stable/statistics/#health-state-of-tables ; https://docs.pingcap.com/tidb/stable/system-variables/ (anchors `#tidb_auto_analyze_ratio`, `#tidb_analyze_column_options-new-in-v830`, `#tidb_auto_analyze_concurrency-new-in-v840`, `#tidb_enable_pseudo_for_outdated_stats-new-in-v530`, `#tidb_stats_load_sync_wait-new-in-v540`); dev cross-check https://docs.pingcap.com/tidb/dev/system-variables/
- Version: v8.5 docs.

### 10. Global bindings syntax; `@@last_plan_from_binding`; `mysql.bind_info`

**Verdict: CORRECTED (syntax right; the "advise against deleting from bind_info" sentence is not in the docs as such).**

Accurate statement:
- `CREATE [GLOBAL | SESSION] BINDING FOR BindableStmt USING BindableStmt;`, `DROP [GLOBAL | SESSION] BINDING FOR BindableStmt;` (also `... FOR SQL DIGEST ...`), `SHOW [GLOBAL | SESSION] BINDINGS [ShowLikeOrWhere]`. `last_plan_from_binding` (New in v4.0, SESSION) "is used to show whether the execution plan used in the previous statement was influenced by a plan binding"; docs use `SELECT @@last_plan_from_binding;`.
- On `mysql.bind_info`: the docs do not contain an explicit "do not delete from `mysql.bind_info`" warning. What they say is that `DROP GLOBAL BINDING` "does not directly delete the records in the system table, because other tidb-server instances need to read the 'deleted' status to drop the corresponding binding in their cache," and a background thread reclaims 'deleted' rows after 100 × `bind-info-lease` (300 s). That is the documented reason to manage bindings through SQL statements rather than by editing the table.
- Sources: https://docs.pingcap.com/tidb/stable/sql-plan-management/ ; https://docs.pingcap.com/tidb/stable/system-variables/#last_plan_from_binding-new-in-v40
- Version: v8.5 docs.

### 11. EXPLAIN formats; FORMAT=JSON/TREE unsupported; EXPLAIN ANALYZE executes DML; EXPLAIN FOR CONNECTION privilege

**Verdict: CORRECTED (privilege is SUPER only; PROCESS is MySQL's rule).**

Accurate statement:
- Supported formats: `row` (default), `brief`, `dot`, `tidb_json`, `verbose`, `plan_cache`, `cost_trace`. "TiDB does not support the `FORMAT=JSON` or `FORMAT=TREE` options." `FORMAT=tidb_json` "format and fields are different from the `FORMAT=JSON` output in MySQL."
- `EXPLAIN ANALYZE`: "When you use `EXPLAIN ANALYZE` to execute DML statements, modification to data is normally executed. Currently, the execution plan for DML statements **cannot** be shown yet."
- `EXPLAIN FOR CONNECTION`: "MySQL requires the login user to be the same as the connection being queried, or the login user has the **`PROCESS`** privilege; while TiDB requires the login user to be the same as the connection being queried, or the login user has the **`SUPER`** privilege."
- Sources: https://docs.pingcap.com/tidb/stable/sql-statement-explain/ ; https://docs.pingcap.com/tidb/stable/sql-statement-explain-analyze/
- Version: v8.5 docs.

### 12. `PLAN REPLAYER DUMP EXPLAIN ANALYZE` exports a ZIP downloadable at `/plan_replayer/dump/{token}`

**Verdict: CONFIRMED.**

- `PLAN REPLAYER` introduced in v5.3.0. Syntax `PLAN REPLAYER DUMP EXPLAIN [ANALYZE] sql-statement;` and `PLAN REPLAYER DUMP WITH STATS AS OF TIMESTAMP expression EXPLAIN [ANALYZE] sql-statement;`. "packages the table information above into a `ZIP` file and returns the file identifier"; download via `http://${tidb-server-ip}:${tidb-server-status-port}/plan_replayer/dump/${file_token}`. File kept for at most one hour. `@@tidb_last_plan_replayer_token` (v6.3.0) returns the last token.
- Source: https://docs.pingcap.com/tidb/stable/sql-plan-replayer/
- Version: v5.3.0+; page describes v8.5.

### 13. `NO_DECORRELATE()` and `LIMIT 1`; `tidb_opt_enable_no_decorrelate_in_select`; `SEMI_JOIN_REWRITE()` scope; both hints cancel

**Verdict: CORRECTED (LIMIT 1 injection and mutual cancellation are source-level facts, not documented; SEMI_JOIN_REWRITE scope is "EXISTS subqueries").**

Accurate statement:
- Docs: `NO_DECORRELATE()` "tells the optimizer not to try to perform decorrelation for the correlated subquery in the specified query block... applicable to the `EXISTS`, `IN`, `ANY`, `ALL`, `SOME` subqueries and scalar subqueries that contain correlated columns"; the plan then uses the Apply operator. The docs say nothing about `LIMIT 1`.
- Source (master): in `handleExistSubquery`, "Add LIMIT 1 when noDecorrelate is true for EXISTS subqueries to enable early exit" and "Only add LIMIT 1 if the query doesn't already contain a LIMIT clause." Version in which this landed: not established from a primary source (see Unsettled).
- `tidb_opt_enable_no_decorrelate_in_select`: New in v8.5.4 (dev docs: "New in v8.5.4 and v9.0.0"), default `OFF`; "controls whether the optimizer applies the `NO_DECORRELATE()` hint for all queries that contain a subquery in the `SELECT` list." Source restricts this to scalar and EXISTS subqueries in the select list.
- `SEMI_JOIN_REWRITE()`: docs say "Currently, this hint only works for `EXISTS` subqueries" (rewrites the semi-join to an ordinary join) — not "SemiJoin" in general.
- Both hints on one EXISTS subquery: source emits the warning "NO_DECORRELATE() and SEMI_JOIN_REWRITE() are in conflict. Both will be ineffective." and sets both flags false. Not documented on the hints page.
- Sources: https://docs.pingcap.com/tidb/stable/optimizer-hints/#no_decorrelate ; https://docs.pingcap.com/tidb/stable/optimizer-hints/#semi_join_rewrite ; https://docs.pingcap.com/tidb/stable/system-variables/#tidb_opt_enable_no_decorrelate_in_select-new-in-v854 ; https://github.com/pingcap/tidb/blob/master/pkg/planner/core/expression_rewriter.go (`handleExistSubquery`, `isNoDecorrelate`)
- Version: v8.5.4 for the variable; source as of master (Sept 2026).

### 14. `tidb_hot_regions`, `slow_query`, `statements_summary` columns

**Verdict: CONFIRMED.**

- `INFORMATION_SCHEMA.TIDB_HOT_REGIONS` columns include `FLOW_BYTES` ("The number of bytes written and read in the Region") and `MAX_HOT_DEGREE` ("The maximum hot degree of the Region"), plus TABLE_ID, INDEX_ID, DB_NAME, TABLE_NAME, INDEX_NAME, REGION_ID, TYPE, REGION_COUNT.
- `INFORMATION_SCHEMA.SLOW_QUERY` has `Query_time`, `Process_time`, `Wait_time`, `Mem_max`, `Plan_digest` (column names are Title_case in the docs).
- `INFORMATION_SCHEMA.STATEMENTS_SUMMARY` has `PLAN_DIGEST`, `SUM_LATENCY`, `AVG_PROCESSED_KEYS` (and `AVG_MEM`/`MAX_MEM`, `AVG_PROCESS_TIME`, `AVG_WAIT_TIME`).
- Sources: https://docs.pingcap.com/tidb/stable/information-schema-tidb-hot-regions/ ; https://docs.pingcap.com/tidb/stable/information-schema-slow-query/ ; https://docs.pingcap.com/tidb/stable/statement-summary-tables/
- Version: v8.5 docs.

### 15. `ADMIN SHOW DDL JOBS`, `tidb_ddl_reorg_worker_cnt`, `tidb_ddl_reorg_batch_size`

**Verdict: CONFIRMED.**

- `ADMIN SHOW DDL JOBS [Int64Num] [WHERE ...]` exists. `tidb_ddl_reorg_worker_cnt`: default `4`, range `[1, 256]`, "the concurrency of the DDL operation in the `re-organize` phase." `tidb_ddl_reorg_batch_size`: default `256`, range `[32, 10240]`, batch size in the re-organize phase (index backfill). Both are SESSION-scoped since v8.3.0 and, from v8.5.0, can be changed on a running job with `ADMIN ALTER DDL JOBS <job_id> THREAD = ... | BATCH_SIZE = ...` (limitation for `ADD INDEX` with `tidb_enable_dist_task` before v8.5.5).
- Sources: https://docs.pingcap.com/tidb/stable/sql-statement-admin-show-ddl/ ; https://docs.pingcap.com/tidb/stable/system-variables/#tidb_ddl_reorg_worker_cnt ; https://docs.pingcap.com/tidb/stable/system-variables/#tidb_ddl_reorg_batch_size
- Version: v8.5 docs.

### 16. `CREATE SEQUENCE`; per-node cache; unique but not gapless

**Verdict: CORRECTED (exists and caches; the "per node, unique, not gapless" wording is not stated in the docs).**

Accurate statement:
- `CREATE SEQUENCE` is a TiDB extension "modeled on sequences available in MariaDB," introduced in v4.0.0-beta.1 ("Support the `Sequence` function"). `CACHE` default `1000`: "Specifies the local cache size of a sequence in TiDB"; `NOCACHE` available. Values follow the sequence's arithmetic progression; `SETVAL` cannot change the progression.
- The docs do not say "cached per TiDB node" or "unique but not gapless" in those words. The source shows cache batches are allocated per allocator (`AllocSeqCache` "allocs sequence batch value cached in table level"), which is what makes unused cached values skippable; treat the gap statement as an inference from the source, not a documented guarantee.
- Sources: https://docs.pingcap.com/tidb/stable/sql-statement-create-sequence/ ; https://docs.pingcap.com/tidb/stable/release-4.0.0-beta.1/ ; https://github.com/pingcap/tidb/blob/master/pkg/meta/autoid/autoid.go
- Version: v4.0.0-beta.1+; page describes v8.5.

### Unsettled

- **Claim 3, pre-v4.0 history:** could not find a release note announcing the maximum moving from 10 GB to 1 TB (docs branches show the change between v5.2 and v5.3), nor a primary statement of the pre-v4.0 maximum (the v3.0 config doc does not carry this item under the same heading).
- **Claim 13, version of `LIMIT 1` injection:** the behaviour is in `pkg/planner/core/expression_rewriter.go` on master, but no docs page or release note names the version that introduced it. Same for the "both hints ineffective" warning — source only.
- **Claim 16, gap semantics:** no docs sentence states that sequence values are unique but not gapless, or that cache is per tidb-server instance; only the source's batch-allocation design supports it.
- **Claim 10, `mysql.bind_info` warning:** no explicit "do not modify directly" sentence exists in the SPM doc; the closest primary text is the 'deleted'-status explanation quoted above.

## Part 3: TiDB Cloud, drivers, AI features


Verified 2026-09-09 against primary sources only (docs.pingcap.com, pingcap/docs and tidbcloud GitHub repos, npm registry, zero.tidbcloud.com, prisma.io docs). Where the live docs page rendered empty, the markdown source in `pingcap/docs@master` was read instead; the last-commit date of that source file is given as the doc date.

### 1. Prisma driver adapter package

**Verdict: CONFIRMED (`@tidbcloud/prisma-adapter`), with status detail.**

- Package: `@tidbcloud/prisma-adapter`. `@prisma/adapter-tidbcloud` does not exist on npm (registry returns "not found").
- Latest version 6.17.0, published 2025-10-28; not deprecated; peer dependency `@tidbcloud/serverless >= 0.1.0`. Version rule: "If you are using Prisma vx.y.z, you can choose the latest adapter version in vx.y."
- Preview flag: TiDB Cloud docs still instruct `previewFeatures = ["driverAdapters"]` ("To use the Prisma adapter, you need to enable the `driverAdapters` feature in the `schema.prisma` file"). Prisma's own reference lists `driverAdapters` as "Released into Preview 5.4.0" and "Released into General Availability 6.16.0", so on Prisma >= 6.16.0 the flag is no longer required; the TiDB docs and adapter README have not been updated to say so.
- Status: Prisma lists it under "community-maintained driver adapters" ("TiDB Cloud Serverless Driver", linking github.com/tidbcloud/prisma-adapter). The adapter "only supports Prisma Client. Prisma migration and introspection still go through the traditional TCP way."
- Instantiation for adapter >= v6.6.0: `new PrismaTiDBCloud({ url: connectionString })`.

Sources:
- https://registry.npmjs.org/@tidbcloud/prisma-adapter (dist-tags latest 6.17.0, 2025-10-28)
- https://github.com/tidbcloud/prisma-adapter (README)
- https://docs.pingcap.com/tidbcloud/serverless-driver-prisma-example/ (source `develop/serverless-driver-prisma-example.md`)
- https://www.prisma.io/docs/orm/reference/preview-features/client-preview-features
- https://www.prisma.io/docs/orm/overview/databases/database-drivers

### 2. Prisma connection strings (`sslaccept=strict` / `sslcert`)

**Verdict: CONFIRMED.**

- Starter/Essential tab: `DATABASE_URL='{connection_string}'` (copied from the console dialog), with the note "For TiDB Cloud Starter, you **MUST** enable TLS connection by setting `sslaccept=strict` when using public endpoint." The serverless-driver Prisma tutorial shows the concrete shape `mysql://[username]:[password]@[host]:4000/[database]?sslaccept=strict`.
- Dedicated tab: `DATABASE_URL='mysql://{user}:{password}@{host}:4000/test?sslaccept=strict&sslcert={downloaded_ssl_ca_path}'`, with "When you set up `sslaccept=strict` to enable TLS connection, you **MUST** specify the file path of the CA certificate downloaded from connection dialog via `sslcert=/path/to/ca.pem`." (The note is mislabeled "For TiDB Cloud Starter" in the Dedicated tab — a docs typo.)

Sources:
- https://docs.pingcap.com/tidbcloud/dev-guide-sample-application-nodejs-prisma/ (source `develop/dev-guide-sample-application-nodejs-prisma.md`, last commit 2026-04-24)
- https://docs.pingcap.com/tidbcloud/serverless-driver-prisma-example/

### 3. Starter free quota and exhaustion behavior

**Verdict: CONFIRMED.**

- "For the first five TiDB Cloud Starter instances in your organization, TiDB Cloud provides a free usage quota for each of them as follows: Row-based storage: 5 GiB; Columnar storage: 5 GiB; Request Units (RUs): 50 million RUs per month."
- "Once a TiDB Cloud Starter instance reaches its usage quota, it immediately denies any new connection attempts until you increase the quota or the usage is reset upon the start of a new month. Existing connections established before reaching the quota will remain active but will experience throttling."
- Note the docs now say "instances" (terminology change 2026-04-14: "TiDB Cloud Starter and Essential clusters are renamed to ... instances across the console").

Sources:
- https://docs.pingcap.com/tidbcloud/serverless-limitations/ (source last commit 2026-04-21)
- https://docs.pingcap.com/tidbcloud/serverless-faqs/ (source last commit 2026-04-21)
- https://docs.pingcap.com/tidbcloud/select-cluster-tier/#usage-quota (source last commit 2026-04-21)

### 4. Starter/Essential public endpoint TLS, username prefix, port, idle timeout

**Verdict: CORRECTED (pool figure).**

Confirmed parts:
- Publicly trusted CA, no download: "TiDB Cloud uses certificates from Let's Encrypt as a Certificate Authority (CA)"; "You can easily connect to your TiDB Cloud Starter or Essential instance without downloading a server-side digital certificate."
- TLS required and `VERIFY_IDENTITY` shown: example `mysql -u '3pTAoNNegb47Uc8.root' -h <host> -P 4000 -D test --ssl-mode=VERIFY_IDENTITY --ssl-ca=<CA_root_path> -p`; "TiDB Cloud Starter and Essential require TLS connection." TLS 1.2/1.3 only.
- Username prefix `<prefix>.<user>` (e.g. `3pTAoNNegb47Uc8.root`, `CREATE USER '3pTAoNNegb47Uc8.jeffrey'`). Port 4000.
- Dedicated public endpoint requires the downloaded CA (Prisma guide: `sslcert={downloaded_ssl_ca_path}`; separate page "TLS Connections to TiDB Cloud Dedicated").

Corrected part:
- The docs do not state a "300 s pool idle timeout" rule. The figure they give is: "Due to a limitation of AWS Global Accelerator, the idle timeout for a Public Endpoint connection on AWS is 340 seconds. For the same reason, you cannot use TCP keep-alive packets to keep the connection open." Separately: "Your database client connections might be terminated unexpectedly if they remain open for more than 30 minutes... configure a maximum connection lifetime. It is recommended to start with 5 minutes and increase it gradually." Accurate statement: keep pool idle time under 340 s on AWS public endpoints, and set a max connection lifetime starting around 5 minutes.

Sources:
- https://docs.pingcap.com/tidbcloud/serverless-limitations/#connection (idle timeout 340 s; 30-minute lifetime guidance)
- https://docs.pingcap.com/tidbcloud/select-cluster-tier/#user-name-prefix (VERIFY_IDENTITY, port 4000, prefix)
- https://docs.pingcap.com/tidbcloud/secure-connections-to-serverless-clusters/ (Let's Encrypt, no download, TLS versions)

### 5. `@tidbcloud/serverless` driver

**Verdict: CONFIRMED (and the driver as a whole is labeled Beta).**

- Page title "TiDB Cloud Serverless Driver (Beta)": "The serverless driver is in beta and only applicable to TiDB Cloud Starter or Essential instances."
- Limitations: "Up to 10,000 rows can be fetched in a single query."; "You can execute only a single SQL statement at a time. Multiple SQL statements in one query are not supported yet."; "Connection with private endpoints is not supported yet."; also CORS blocks browser use ("you can use the serverless driver only from backend services").
- Type mapping table: `BIGINT -> string`, `UNSIGNED BIGINT -> string`, `DECIMAL -> string` ("By default, TiDB Cloud serverless driver returns the BIGINT type as text value").
- Transactions: section heading "Transaction (experimental)", `const tx = await conn.begin()`; `isolation` option `READ COMMITTED` or `REPEATABLE READ`. The GitHub README also marks transactions "(experimental)" and notes "Transactions idle for 10 minutes will be rolled back automatically".
- Latest release: serverless-js v0.3.0 (2026-03-17).

Sources:
- https://docs.pingcap.com/tidbcloud/serverless-driver/ (source `develop/serverless-driver.md`, last commit 2026-04-22)
- https://github.com/tidbcloud/serverless-js (README; releases)

### 6. `@tidbcloud/kysely` dialect export name

**Verdict: CORRECTED.** The export is `TiDBServerlessDialect`, not `TiDBCloudServerlessDialect`.

- `import { TiDBServerlessDialect } from '@tidbcloud/kysely'` ... `dialect: new TiDBServerlessDialect({ url: process.env.DATABASE_URL })`. Docs pin `"@tidbcloud/kysely": "^0.0.4"`.

Sources:
- https://docs.pingcap.com/tidbcloud/serverless-driver-kysely-example/ (source `develop/serverless-driver-kysely-example.md`)
- https://github.com/tidbcloud/kysely (README)

### 7. TiDB Cloud Zero API

**Verdict: CONFIRMED (first-party page is zero.tidbcloud.com; not in docs.pingcap.com).**

- `POST https://zero.tidbapi.com/v1beta1/instances` (example body `{"tag":"cli-quickstart"}`). Response is wrapped in a top-level `instance` object containing `id`, `connection{host,port:4000,username,password}`, `connectionString`, `claimInfo.claimUrl`, `expiresAt`.
- "Each TiDB Cloud Zero database lasts up to 30 days unless you claim it first."
- "v1alpha1 is deprecated and will be removed on 2026-04-06. Please migrate to v1beta1."
- The page links quota info to https://docs.pingcap.com/tidbcloud/serverless-limitations/?plan=starter. No docs.pingcap.com page documents Zero itself; the 2026 release notes contain no Zero entry.

Source: https://zero.tidbcloud.com/ (fetched 2026-09-09)

### 8. `ticloud` CLI

**Verdict: CORRECTED (one flag name).**

- Install: `curl https://raw.githubusercontent.com/tidbcloud/tidbcloud-cli/main/install.sh | sh` — confirmed (README and Get Started page). Latest release v1.0.0-beta.11 (2025-12-23).
- `ticloud serverless create --display-name <display-name> --region <region>`; `-p, --project-id` is an optional flag ("The default value is `default project`") — confirmed.
- `ticloud serverless branch create --cluster-id <cluster-id> --display-name <branch-name>` — the branch name flag is `-n, --display-name`, not `--name`. CORRECTED.
- `ticloud serverless sql-user create --user <user-name> --password <password> --role <role> --cluster-id <cluster-id>` — confirmed; the docs page does not enumerate role values, but the CLI source defines the built-in roles as `"role_admin"`, `"role_readwrite"`, `"role_readonly"` (docs console names: Database Admin / Database Read-Write / Database Read-Only). `--role` is a string slice (repeatable).
- `ticloud serverless import start` — confirmed (alias `import create`; `--source-type` one of `LOCAL`, `S3`, `GCS`, `AZURE_BLOB`).
- `ticloud serverless export create --target-type LOCAL` — confirmed (`--target-type` one of `LOCAL`, `S3`, `GCS`, `AZURE_BLOB`, `OSS`; default `LOCAL`).

Sources:
- https://github.com/tidbcloud/tidbcloud-cli (README; `internal/util/constant.go`; `internal/cli/serverless/sqluser/create.go`)
- https://docs.pingcap.com/tidbcloud/get-started-with-cli/
- https://docs.pingcap.com/tidbcloud/ticloud-cluster-create/ (page title "ticloud serverless create")
- https://docs.pingcap.com/tidbcloud/ticloud-branch-create/
- https://docs.pingcap.com/tidbcloud/ticloud-serverless-sql-user-create/
- https://docs.pingcap.com/tidbcloud/ticloud-import-start/
- https://docs.pingcap.com/tidbcloud/ticloud-serverless-export-create/
- https://docs.pingcap.com/tidbcloud/configure-sql-users/

### 9. Full-text search

**Verdict: CORRECTED (availability).**

Confirmed syntax:
- `FULLTEXT INDEX (title) WITH PARSER MULTILINGUAL` in CREATE TABLE; `ALTER TABLE stock_items ADD FULLTEXT INDEX (title) WITH PARSER MULTILINGUAL ADD_COLUMNAR_REPLICA_ON_DEMAND;`
- Parsers: "`STANDARD`: fast, works for English content, splitting words by spaces and punctuation." "`MULTILINGUAL`: supports multiple languages, including English, Chinese, Japanese, and Korean."
- Query: "To perform a full-text search, you can use the `FTS_MATCH_WORD()` function." Signature in examples: `fts_match_word("query", column)` (query first, column second) — matches the claim.

Corrected availability:
- Live page: "Full-text search is still in the early stages, and we are continuously rolling it out to more customers. Currently, full-text search is only available on TiDB Cloud Starter in the following regions: AWS: `Oregon (us-west-2)`, `N. Virginia (us-east-1)`, `Tokyo (ap-northeast-1)`, `Frankfurt (eu-central-1)`, and `Singapore (ap-southeast-1)`". Release notes: Tokyo and Oregon added 2026-05-26; N. Virginia added 2026-06-09. (The `master` source still reads "Starter and Essential ... Frankfurt and Singapore"; the live page is the newer text. Essential is therefore inconsistent across pages; the CREATE INDEX page says "only TiDB Cloud Starter and Essential instances in certain AWS regions".)
- Self-managed: not supported. "TiDB Self-Managed and TiDB Cloud Dedicated support parsing the `FULLTEXT` syntax but do not support using the `FULLTEXT`, `HASH`, and `SPATIAL` indexes." No self-managed version is given.

Sources:
- https://docs.pingcap.com/ai/vector-search-full-text-search-sql/ (source `ai/guides/vector-search-full-text-search-sql.md`, last commit 2026-04-22)
- https://docs.pingcap.com/tidb/stable/sql-statement-create-index/
- https://docs.pingcap.com/tidbcloud/tidb-cloud-release-notes/ (2026-05-26, 2026-06-09 entries)

### 10. Auto embedding

**Verdict: CONFIRMED (with the availability wording tightened).**

- `EMBED_TEXT("model_name", text_content[, additional_json_options])`; free model `tidbcloud_free/amazon/titan-embed-text-v2`, "Dimensions: 1024 (default), 512, 256", "Price: Free", "No API key is required."
- Generated column: `content_vector VECTOR(1024) GENERATED ALWAYS AS (EMBED_TEXT("tidbcloud_free/amazon/titan-embed-text-v2", content)) STORED`.
- Query: `VEC_EMBED_COSINE_DISTANCE(vector_column, "query_text")` (also `VEC_EMBED_L2_DISTANCE()`).
- BYOK for OpenAI: `SET @@GLOBAL.TIDB_EXP_EMBED_OPENAI_API_KEY = "{your-openai-api-key}";` (plus optional `TIDB_EXP_EMBED_OPENAI_API_BASE` for Azure OpenAI).
- Availability: "Auto Embedding is only available on TiDB Cloud Starter instances hosted on AWS." No region list is given — the restriction is cloud-level (AWS), not per region.

Sources:
- https://docs.pingcap.com/ai/vector-search-auto-embedding-overview/ (source last commit 2026-04-22)
- https://docs.pingcap.com/tidbcloud/vector-search-auto-embedding-amazon-titan/
- https://docs.pingcap.com/ai/vector-search-auto-embedding-openai/

### 11. `information_schema.tiflash_replica` columns

**Verdict: CORRECTED (column list incomplete).** The table has seven columns: `TABLE_SCHEMA`, `TABLE_NAME`, `TABLE_ID`, `REPLICA_COUNT`, `LOCATION_LABELS`, `AVAILABLE`, `PROGRESS`. The four named in the claim exist; `TABLE_ID`, `LOCATION_LABELS`, and `PROGRESS` (0-1, two decimals) were omitted.

Source: https://docs.pingcap.com/tidb/stable/information-schema-tiflash-replica/

### 12. `IMPORT INTO ... FROM 's3://...'`

**Verdict: CONFIRMED, with tier and version detail.**

- Version: "Introduce a new SQL statement `IMPORT INTO` ... (experimental)" in v7.2.0; "In v7.5.0, the `IMPORT INTO` SQL statement becomes generally available (GA)."
- Tiers: "For TiDB Self-Managed, `IMPORT INTO ... FROM FILE` supports importing data from files stored in Amazon S3, GCS, and the TiDB local storage. For TiDB Cloud Dedicated, ... Amazon S3 and GCS. For TiDB Cloud Starter and TiDB Cloud Essential, ... Amazon S3 and Alibaba Cloud OSS." Global Sort is not available on Starter/Essential.
- Lightning: `IMPORT INTO` itself "lets you import data to TiDB via the Physical Import Mode of TiDB Lightning." For the console: the Dedicated CSV import page says "the current data import feature uses the physical import mode" (linking TiDB Lightning physical import mode). The Starter/Essential import pages do not state this.

Sources:
- https://docs.pingcap.com/tidb/stable/sql-statement-import-into/
- https://docs.pingcap.com/tidb/stable/release-7.2.0/ ; https://docs.pingcap.com/tidb/stable/release-7.5.0/
- https://docs.pingcap.com/tidbcloud/import-csv-files/ (Dedicated; physical import mode note)

### 13. Current naming: "TiDB X" vs "TiDB Cloud Starter"

**Verdict: CORRECTED.** TiDB Cloud Serverless was renamed **TiDB Cloud Starter**, not "TiDB X". "TiDB X" is the name of the storage-compute architecture/kernel that Starter, Essential, and Premium run on.

- "TiDB Cloud Starter is the new name for TiDB Cloud Serverless, effective August 12, 2025." Release note 2025-08-12: "Rename 'TiDB Cloud Serverless' to 'TiDB Cloud Starter'. ... Your connection strings, endpoints, and data will remain unchanged."
- "TiDB X is a new distributed SQL architecture that makes cloud-native object storage the backbone of TiDB. Currently available in TiDB Cloud Starter, Essential, and Premium".
- Current plan names on the Select a Plan page: TiDB Cloud Starter, TiDB Cloud Essential, TiDB Cloud Premium (public preview since 2026-04-28, AWS and Alibaba Cloud), TiDB Cloud Dedicated, TiDB Cloud Lake. Since 2026-04-14 Starter/Essential deployments are called "instances", not "clusters".

Sources:
- https://docs.pingcap.com/tidbcloud/serverless-faqs/
- https://docs.pingcap.com/tidbcloud/tidb-cloud-release-notes/ (2026-04-14, 2026-04-28) and the 2025 notes (2025-08-12)
- https://docs.pingcap.com/tidbcloud/tidb-x-architecture/
- https://docs.pingcap.com/tidbcloud/select-cluster-tier/

### 14. `FLASHBACK CLUSTER` on Starter/Essential

**Verdict: CONFIRMED.** Cited from the SQL limitations page, not the general limitations page (which does not mention it).

- Limited SQL Features table: `FLASHBACK CLUSTER` — TiDB Cloud Dedicated: Supported; Starter and Essential: "Not supported" (footnote: use console Backup and Restore instead).
- Statement page: "The `FLASHBACK CLUSTER TO [TIMESTAMP|TSO]` syntax is not applicable to TiDB Cloud Starter, TiDB Cloud Essential, and TiDB Cloud Premium instances. To avoid unexpected results, do not execute this statement on TiDB Cloud Starter, Essential, and Premium instances."

Sources:
- https://docs.pingcap.com/tidbcloud/limited-sql-features/ (source last commit 2026-02-11)
- https://docs.pingcap.com/tidb/stable/sql-statement-flashback-cluster/

### 15. mysql2 recommended settings

**Verdict: CORRECTED.**

- The official Node.js (mysql2) guide's ssl block is `ssl: { minVersion: 'TLSv1.2', ca: process.env.TIDB_CA_PATH ? fs.readFileSync(process.env.TIDB_CA_PATH) : undefined }`. It does not set `rejectUnauthorized: true` (mysql2/Node default behavior applies). For Starter/Essential: "you **don't** have to specify an SSL CA certificate via `TIDB_CA_PATH`, because Node.js uses the built-in Mozilla CA certificate by default, which is trusted by TiDB Cloud Starter."
- Big numbers: "It is recommended to enable the `supportBigNumbers: true` option when dealing with big numbers (`BIGINT` and `DECIMAL` columns) in the database." `bigNumberStrings` is not mentioned. The guide also recommends `enableKeepAlive: true`.

Source: https://docs.pingcap.com/tidbcloud/dev-guide-sample-application-nodejs-mysql2/ (source last commit 2026-04-24)

### 16. RU definition: scans and hot spots

**Verdict: UNSETTLED (the specific "scans and hot spots consume more RUs" wording is not in the docs).**

What the docs say: "A Request Unit (RU) is a unit of measure used to represent the amount of resources consumed by a single request to the database. The amount of RUs consumed by a request depends on various factors, such as the operation type or the amount of data being retrieved or modified." RU components are read, write, SQL CPU, and network egress; the docs point to the PingCAP pricing page for rates, which says "the RU is calculated by converting the usage of the above resource types into RUs proportionally and then summing them". The FAQ's optimization advice is to tune SQL and return fewer rows/columns to reduce egress. Neither page mentions hot spots. A defensible paraphrase is "RUs scale with the operation type and the amount of data read, written, and returned, so full scans and wide result sets cost more"; do not attribute a hot-spot statement to the docs.

Sources:
- https://docs.pingcap.com/tidbcloud/tidb-cloud-glossary/#request-unit-ru
- https://docs.pingcap.com/tidbcloud/serverless-faqs/ ("How can I optimize my workload to minimize the number of RUs consumed?")
- https://www.pingcap.com/tidb-cloud-starter-pricing-details/ (first-party pricing page, linked from the docs)

### Unsettled

- Claim 16: no primary source states that scans or hot spots consume more RUs; only the general "operation type and amount of data" definition exists.
- Claim 9 (Essential): the live full-text page says Starter only; the `master` source and the CREATE INDEX page say Starter and Essential. Treat Essential support as unconfirmed.
- Claim 12 (console import uses Lightning): stated only on the Dedicated CSV import page ("physical import mode"); not stated on the Starter/Essential import pages.
- Claim 1 (flag): Prisma says `driverAdapters` went GA in 6.16.0, but TiDB's docs and the adapter README still show `previewFeatures = ["driverAdapters"]`; no TiDB source confirms it can be dropped.
- Claim 8 (role values): `role_readwrite` comes from CLI source constants, not from a docs page.
