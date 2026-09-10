# MongoDB-to-TiDB migration: fact check

Checked 2026-09-10 against primary sources only: docs.pingcap.com (TiDB v8.5 stable unless noted, TiDB Cloud), pingcap/tidb source (release-8.5 unless noted), and mongodb.com/docs (current manual, mongosh, database tools, Atlas). Where the docs are silent, the verdict rests on source code and says so.

## Summary

| # | Claim (short) | Verdict |
|---|---|---|
| 1 | `IMPORT INTO` GA v7.5.0; CSV/SQL/Parquet; S3/GCS/Azure Blob; empty table; Dedicated has console import and `IMPORT INTO` | Corrected |
| 2 | `LOAD DATA` single transaction from v7.0.0, earlier 20,000-row commits; bounded by `txn-total-size-limit` | Corrected |
| 3 | Defaults 6 MiB / 100 MiB; whether TiDB Cloud lets users change them | Confirmed (defaults) / Unsettled (Cloud) |
| 4 | Recursive CTEs since v5.1 | Confirmed |
| 5 | `CHECK` from v7.2.0, off by default | Confirmed |
| 6 | `TABLESAMPLE REGIONS()` supported | Confirmed |
| 7 | Multi-valued index in composite; serves MEMBER OF / JSON_CONTAINS / JSON_OVERLAPS; versions | Confirmed (v6.6.0 experimental, v7.1.0 GA) |
| 8 | `JSON_ARRAYAGG(DISTINCT)` unsupported; `GROUP_CONCAT(DISTINCT)` supported | Confirmed (from parser grammar) |
| 9 | `BIN_TO_UUID` / `UUID_TO_BIN` available; version | Confirmed (first in v5.2.0, from source) |
| 10 | Appending an ENUM value via `MODIFY COLUMN` does not rewrite rows | Confirmed (from DDL source; docs silent) |
| 11 | `information_schema.TIDB_INDEX_USAGE` exists | Confirmed (v8.0.0) |
| 12 | TiDB Cloud DM: MySQL-compatible sources only; no MongoDB | Confirmed |
| 13 | TiCDC sinks: MySQL-compatible, Kafka, Pulsar, cloud storage | Confirmed (Pulsar since v7.4.0) |
| 14 | 1017 columns, 64 indexes per table by default | Confirmed |
| 15 | `tidb_gc_life_time` default 10m bounds `AS OF TIMESTAMP` | Confirmed |
| 16 | Sequential PK hotspot not relieved by Load Base Split; fixes `AUTO_RANDOM` / `SHARD_ROW_ID_BITS`; index hotspot on sequential column | Corrected (mechanism confirmed; Load Base Split not named by docs) |
| 17 | TTL: NULL never expires; TTL table cannot be FK parent; no cascade | Corrected (NULL from source; "no cascade" imprecise) |
| 18 | Default `utf8mb4_bin`; `_general_ci`, `_unicode_ci`, `_0900_ai_ci` available; versions | Confirmed (v4.0 framework; `_0900_*` since v7.4.0) |
| 19 | `REGEXP` supported; which `REGEXP_*` and since when | Confirmed (four functions, v6.3.0) |
| 20 | JSON function list supported; `JSON_TABLE` not | Confirmed |
| 21 | Indexes on virtual generated columns | Confirmed |
| 22 | INSERT variants, `FOR UPDATE`, `NOWAIT`; `SKIP LOCKED`? | Confirmed (`SKIP LOCKED` unsupported) |
| 23 | Window functions incl. `FIRST_VALUE`, `ROW_NUMBER` | Confirmed |
| 24 | `LIKE 'prefix%'` uses index; `REGEXP` does not | Confirmed (REGEXP part from ranger source) |
| 25 | `DATETIME` no TZ conversion; `TIMESTAMP` converts, ends 2038 | Confirmed |
| 26 | Change streams: replica set/sharded; `startAtOperationTime` 4.0; `updateLookup` = current doc; pre-images 6.0 + collection option | Confirmed |
| 27 | `$push` -> `updatedFields` dotted index; `$pull`/`$slice` -> `truncatedArrays` | Corrected |
| 28 | `$queryStats`: Atlas M10+, MongoDB 7.0+, parameter; records find/aggregate/distinct only | Corrected |
| 29 | `$bsonSize` 4.4+; `$collStats` storageStats fields | Confirmed |
| 30 | `mongoexport --jsonFormat=canonical` = Extended JSON v2 canonical | Confirmed |
| 31 | `db.hello()` `operationTime` on replica sets; `rs.printReplicationInfo()` oplog window; Atlas minimum oplog window | Confirmed |
| 32 | mongosh: `process.env`, `quit()`, BSON globals, number handling | Confirmed / Unsettled (`Binary` global; deserialization wording) |
| 33 | 16 MB BSON limit; ObjectId 12 bytes, 4-byte seconds timestamp | Confirmed |

## Corrections

| # | Corrected statement |
|---|---|
| 1 | `IMPORT INTO` is GA from v7.5.0, reads CSV, SQL, and Parquet, and requires an existing empty table. Storage: TiDB Self-Managed reads from Amazon S3, GCS, and TiDB local storage; TiDB Cloud Dedicated reads from Amazon S3 and GCS; Starter/Essential read from S3 and Alibaba Cloud OSS. **Azure Blob Storage is not a documented `IMPORT INTO` source in v8.5 or dev docs.** The Dedicated console Import task does accept S3, GCS, and Azure Blob, and also requires empty tables. |
| 2 | Before v4.0.0 `LOAD DATA` committed every 20,000 rows. From v4.0.0 to v6.6.0 it committed all rows in one transaction by default (`tidb_dml_batch_size` could split it). From v7.0.0 `tidb_dml_batch_size` no longer applies and all rows commit in one transaction. From v7.6.0 `LOAD DATA` runs inside the current transaction like any other DML and can be rolled back. The single-transaction path is bounded by `txn-total-size-limit`; the docs' remedy is to raise it. |
| 3 (Cloud) | Docs give no self-service switch for `txn-total-size-limit` on TiDB Cloud. The Cloud transaction-restraints page describes the row limit as adjustable via `txn-entry-size-limit` and, from v7.6.0, the GLOBAL system variable `tidb_txn_entry_size_limit` (range 0-120 MiB), and links "Submit a support ticket for TiDB Cloud". Starter/Essential docs state only a 30-minute transaction duration cap. Treat "user can change these on Cloud" as unverified. |
| 16 | Docs: with an incrementing RowID "the inserted line can only be appended to the end. The Region will split after it reaches a certain size, and then it still can only be appended to the end". The docs attribute this to Region splitting generally; the Load Base Split page describes a read-hotspot feature and never mentions sequential writes. Documented fixes: `SHARD_ROW_ID_BITS` for non-clustered or PK-less tables, `AUTO_RANDOM` in place of `AUTO_INCREMENT`. Index hotspots: "Common index hotspots appear in fields that are monotonously increasing in time order" — the docs state this generally, not the specific `SHARD_ROW_ID_BITS` + unique-index case. |
| 17 | NULL handling is not documented; the TTL job's scan and delete SQL use `WHERE <ttl_col> < FROM_UNIXTIME(<expire>)`, which a NULL never satisfies, so NULL rows are never deleted (source-backed). Documented FK limitation: "A table with the TTL attribute does not support being referenced by other tables as the primary table in a foreign key constraint." Nothing is said about cascading; since a TTL table cannot be a parent, there is no child to cascade to. Drop the standalone "TTL does not cascade" sentence. TTL: v6.5.0 experimental, v7.0.0 GA. |
| 27 | `$push` onto a non-empty array appears in `updateDescription.updatedFields` under a dotted key with the index (`scores.1`); a `$push` onto an empty array shows the whole array replaced. `$pull` "produces a change event that shows the new array" in `updatedFields`. `truncatedArrays` is populated only by pipeline updates (`$addFields`, `$set`, `$replaceRoot`, `$replaceWith`) that shrink an array. `$slice` is not addressed on the page; it is an update-operator modifier like `$pull`, so do not claim it reports through `truncatedArrays`. |
| 28 | `$queryStats` "is enabled on deployments hosted on MongoDB Atlas with a cluster tier of at least M10". Release notes: "Starting in MongoDB 7.1, the `$queryStats` stage returns statistics" — not 7.0. Current docs say it "creates query stats entries for `aggregate`, `find`, `distinct`, and `count` commands" (version in which `count` was added is not stated). The enabling parameter is not in the public parameter reference; the server source README documents `internalQueryStatsRateLimit` (default 0 disables collection, -1 removes the limit). The stage is marked unsupported / output may change. |
| 32 (partial) | mongosh documents `Decimal128()`, `Long()`, `Int32()`, `Double()`, `Timestamp()`, `ObjectId()` on its Data Types page, `BSONRegExp()` and `BinData()` as mongosh methods, and `quit()` (with `exit()` as alias). A global named `Binary` is not documented; use `BinData()` in text aimed at mongosh users. |

## Unsettled

| # | What is unsettled | What I looked for |
|---|---|---|
| 3 | Whether TiDB Cloud Dedicated or Starter users can change `txn-total-size-limit` / `txn-entry-size-limit` themselves | tidbcloud limitations-and-quotas, serverless-limitations, limited-sql-features, tidb-limitations, dev-guide-transaction-restraints, system-variables Cloud block. Only a support-ticket link and the v7.6.0 system variable were found; no console setting is documented. |
| 28 | Version in which `count` joined the recorded commands; official doc for `internalQueryStatsRateLimit` | `$queryStats` page, parameters reference (no hit), 7.0/8.0 release notes. Only the mongodb/mongo source README names the parameter. |
| 32 | (a) `Binary` as a mongosh global; (b) an explicit doc sentence that int32/double values *deserialize* to JS numbers while Long/Decimal128 stay wrapper objects | mongosh Data Types, Compatibility, Methods pages, Node driver BSON page. Docs only state how mongosh *stores* numbers (Int32 or Double) and that `Long()`/`Decimal128()` constructors are needed for those types. |

## Per-claim detail

### TiDB

**1. `IMPORT INTO`** — Corrected.
- GA: release notes 7.5.0: "the `IMPORT INTO` SQL statement becomes generally available (GA)". https://docs.pingcap.com/tidb/stable/release-7.5.0/
- Formats and empty table: "IMPORT INTO only supports importing data into existing empty tables"; formats CSV, SQL, PARQUET. https://docs.pingcap.com/tidb/stable/sql-statement-import-into/
- Storage (v8.5 and dev): "For TiDB Self-Managed, `IMPORT INTO ... FROM FILE` supports importing data from files stored in Amazon S3, GCS, and the TiDB local storage. For TiDB Cloud Dedicated ... Amazon S3 and GCS. For Starter and Essential ... Amazon S3 and Alibaba Cloud OSS." No Azure mention. Same page; dev copy at https://raw.githubusercontent.com/pingcap/docs/master/sql-statements/sql-statement-import-into.md
- Cloud statement page (Dedicated/Starter/Essential coverage): https://docs.pingcap.com/tidbcloud/sql-statement-import-into/
- Dedicated console import: "Import CSV Files from Cloud Storage into TiDB Cloud Dedicated" — S3, GCS, Azure Blob; "TiDB Cloud allows importing CSV files into empty tables only." https://docs.pingcap.com/tidbcloud/import-csv-files/

**2. `LOAD DATA` transactions** — Corrected. Verbatim: "For versions earlier than TiDB v4.0.0, `LOAD DATA` commits every 20000 rows, which cannot be configured." "For versions from TiDB v4.0.0 to v6.6.0, TiDB commits all rows in one transaction by default." "Starting from TiDB v7.0.0, `tidb_dml_batch_size` no longer takes effect on `LOAD DATA`, and TiDB commits all rows in one transaction." "Starting from v7.6.0, TiDB processes `LOAD DATA` in transactions in the same way as other DML statements." Remedy for size errors: "increase the `txn-total-size-limit` value in your `tidb.toml`". https://docs.pingcap.com/tidb/stable/sql-statement-load-data/

**3. Transaction size limits** — Defaults confirmed; Cloud unsettled.
- `txn-entry-size-limit`: default `6291456` bytes, max `125829120`, "New in v4.0.10 and v5.0.0"; `txn-total-size-limit`: default `104857600`, max `1099511627776`; "In TiDB v6.5.0 and later versions, this configuration is no longer recommended". https://docs.pingcap.com/tidb/stable/tidb-configuration-file/
- `tidb_txn_entry_size_limit` "New in v7.6.0", scope SESSION | GLOBAL, default 0, range [0, 125829120]. https://docs.pingcap.com/tidb/stable/system-variables/#tidb_txn_entry_size_limit-new-in-v760
- Cloud: transaction restraints page lists the adjustment path and "Submit a support ticket for TiDB Cloud". https://docs.pingcap.com/tidbcloud/dev-guide-transaction-restraints/ ; Starter/Essential: "Transaction can not last longer than 30 minutes." https://docs.pingcap.com/tidbcloud/serverless-limitations/

**4. Recursive CTE** — Confirmed, v5.1. Release notes 5.1: "Support the Common Table Expression (CTE) feature of MySQL 8.0"; adds `cte_max_recursion_depth`. https://docs.pingcap.com/tidb/stable/release-5.1.0/ ; syntax `WITH RECURSIVE` at https://docs.pingcap.com/tidb/stable/sql-statement-with/

**5. `CHECK` constraints** — Confirmed. "disabled by default"; `tidb_enable_check_constraint` "New in v7.2.0", default `OFF`. https://docs.pingcap.com/tidb/stable/constraints/ ; https://docs.pingcap.com/tidb/stable/system-variables/#tidb_enable_check_constraint-new-in-v720

**6. `TABLESAMPLE REGIONS()`** — Confirmed; documented as a TiDB extension "not supported by MySQL". https://docs.pingcap.com/tidb/stable/sql-statement-select/

**7. Multi-valued indexes** — Confirmed with versions. "When a multi-valued index is defined as a composite index, the multi-valued part can appear in any position, but only once." Example `INDEX zips(name, (CAST(custinfo->'$.zipcode' AS UNSIGNED ARRAY)))`; index-selection page example `idx(a, (CAST(j->'$.path' AS SIGNED ARRAY)), b)` and functions `json_member_of`, `json_contains`, `json_overlaps`; accessed only via IndexMerge. v6.6.0: "Support MySQL-compatible multi-valued indexes (experimental)"; v7.1.0: "MySQL-compatible multi-valued indexes become generally available (GA)". https://docs.pingcap.com/tidb/stable/sql-statement-create-index/ ; https://docs.pingcap.com/tidb/stable/choose-index/ ; https://docs.pingcap.com/tidb/stable/release-6.6.0/ ; https://docs.pingcap.com/tidb/stable/release-7.1.0/

**8. `JSON_ARRAYAGG(DISTINCT)` / `GROUP_CONCAT(DISTINCT)`** — Confirmed from grammar; docs silent on DISTINCT for JSON_ARRAYAGG. `pkg/parser/parser.y` (release-8.5) has only `"JSON_ARRAYAGG" '(' Expression ')'` and `"JSON_ARRAYAGG" '(' "ALL" Expression ')'` (lines 8638, 8646) — no DISTINCT alternative, so the statement fails to parse. `GROUP_CONCAT` production: `builtinGroupConcat '(' BuggyDefaultFalseDistinctOpt ExpressionList OrderByOptional OptGConcatSeparator ')'` with `Distinct: $3` (line 8568). https://github.com/pingcap/tidb/blob/release-8.5/pkg/parser/parser.y ; docs list at https://docs.pingcap.com/tidb/stable/aggregate-group-by-functions/

**9. UUID functions** — Confirmed; first release v5.2.0. Docs list `BIN_TO_UUID()`, `UUID_TO_BIN()`, `IS_UUID()`, `UUID()` (no version mark). https://docs.pingcap.com/tidb/stable/miscellaneous-functions/ . Source: commit 6063386a "expressions: Support `bin-to-uuid` and `uuid-to-bin` (#20140)", 2021-06-30; `expression/builtin_miscellaneous.go` contains the functions on branch release-5.2 and not on release-5.1. https://github.com/pingcap/tidb/pull/20140

**10. ENUM append without rewrite** — Confirmed from source. `pkg/ddl/modify_column.go` `noReorgDataStrict` ("If it returns true, it means we don't need the reorg"): for same-type `mysql.TypeEnum, mysql.TypeSet` it returns `!IsElemsChangedToModifyColumn(oldElems, newElems)`, and that helper returns true only if the new list is shorter or any existing element at the same position differs. Appending at the end is therefore a metadata-only change. Docs only say some ENUM type *conversions* are unsupported. https://github.com/pingcap/tidb/blob/release-8.5/pkg/ddl/modify_column.go ; https://docs.pingcap.com/tidb/stable/sql-statement-modify-column/

**11. `TIDB_INDEX_USAGE`** — Confirmed: "Starting from v8.0.0, TiDB provides the `TIDB_INDEX_USAGE` table." https://docs.pingcap.com/tidb/stable/information-schema-tidb-index-usage/

**12. TiDB Cloud Data Migration** — Confirmed. Sources: self-managed MySQL, Aurora MySQL, RDS MySQL, Azure Database for MySQL Flexible Server, Cloud SQL for MySQL, Alibaba RDS MySQL; "the Data Migration feature is not available for TiDB Cloud Starter"; no MongoDB. (MariaDB is not named either.) https://docs.pingcap.com/tidbcloud/migrate-from-mysql-using-data-migration/

**13. TiCDC sinks** — Confirmed. Overview lists TiDB/MySQL-compatible, Kafka, storage (S3, GCS, Azure Blob, NFS). Pulsar: "Starting from v7.4.0, TiCDC supports replicating change data to Pulsar in `canal-json` format". https://docs.pingcap.com/tidb/stable/ticdc-overview/ ; https://docs.pingcap.com/tidb/stable/release-7.4.0/ ; https://docs.pingcap.com/tidb/stable/ticdc-sink-to-pulsar/

**14. Column and index limits** — Confirmed: columns "Defaults to 1017 and can be adjusted up to 4096" (`table-column-count-limit`); indexes "Defaults to 64 and can be adjusted up to 512" (`index-limit`). https://docs.pingcap.com/tidb/stable/tidb-limitations/

**15. `tidb_gc_life_time`** — Confirmed: "New in v5.0", default `10m0s`, range `[10m0s, 8760h0m0s]` (Self-Managed, Dedicated) and `[10m0s, 168h0m0s]` (Starter, Essential); "the current time minus this value is the safe point". Stale read page: timestamp must not be "later than the GC safe point timestamp". https://docs.pingcap.com/tidb/stable/system-variables/#tidb_gc_life_time-new-in-v50 ; https://docs.pingcap.com/tidb/stable/as-of-timestamp/

**16. Hotspots** — Corrected (see table). https://docs.pingcap.com/tidb/stable/troubleshoot-hot-spot-issues/ ; https://docs.pingcap.com/tidb/stable/configure-load-base-split/ ("especially common with workloads that are mostly read requests"); https://docs.pingcap.com/tidb/stable/shard-row-id-bits/ ("For tables with a non-clustered primary key or no primary key ... written into a single Region, causing a write hot spot"); https://docs.pingcap.com/tidb/stable/auto-random/

**17. TTL** — Corrected (see table). Source: `pkg/ttl/sqlbuilder/sql.go` `WriteExpireCondition` writes `<col> < FROM_UNIXTIME(<unix>)`. https://github.com/pingcap/tidb/blob/release-8.5/pkg/ttl/sqlbuilder/sql.go ; docs https://docs.pingcap.com/tidb/stable/time-to-live/ ; v6.5.0 "(experimental)" https://docs.pingcap.com/tidb/stable/release-6.5.0/ ; v7.0.0 "Time to live (TTL) is generally available" https://docs.pingcap.com/tidb/stable/release-7.0.0/

**18. Collations** — Confirmed with versions. Default collation of `utf8mb4` is `utf8mb4_bin`; supported table lists `utf8mb4_bin`, `utf8mb4_general_ci`, `utf8mb4_unicode_ci`, `utf8mb4_0900_ai_ci`, `utf8mb4_0900_bin`. "Since v4.0, TiDB supports a new framework for collations" that honours case-insensitive semantics (on by default since v6.0); "Before TiDB v7.4.0 ... TiDB does not support the `utf8mb4_0900_ai_ci` collation"; v7.4.0 notes: "Support collation `utf8mb4_0900_ai_ci` and `utf8mb4_0900_bin`". https://docs.pingcap.com/tidb/stable/character-set-and-collation/ ; https://docs.pingcap.com/tidb/stable/release-7.4.0/ ; https://docs.pingcap.com/tidb/stable/release-6.0.0-dmr/

**19. Regular expressions** — Confirmed. `REGEXP`/`RLIKE` plus `REGEXP_INSTR()`, `REGEXP_LIKE()`, `REGEXP_REPLACE()`, `REGEXP_SUBSTR()`; v6.3.0: "adding support for four regular expression functions". TiDB uses RE2, MySQL uses ICU; `match_type` and binary-string behaviour differ. https://docs.pingcap.com/tidb/stable/string-functions/ ; https://docs.pingcap.com/tidb/stable/release-6.3.0/

**20. JSON functions** — Confirmed. All listed functions appear as supported; unsupported list: "JSON_SCHEMA_VALIDATION_REPORT(), JSON_TABLE(), JSON_VALUE()". https://docs.pingcap.com/tidb/stable/json-functions/

**21. Generated-column indexes** — Confirmed: "You can create an index on a generated column whether it is virtual or stored." https://docs.pingcap.com/tidb/stable/generated-columns/

**22. DML variants and locking** — Confirmed. INSERT ("fully compatible with MySQL", grammar has `IGNORE` and `ON DUPLICATE KEY UPDATE`), REPLACE ("fully compatible"). "TiDB supports the `FOR UPDATE NOWAIT` syntax ... error code `3572`". Unsupported features list: "`SKIP LOCKED` syntax #18207". https://docs.pingcap.com/tidb/stable/sql-statement-insert/ ; https://docs.pingcap.com/tidb/stable/sql-statement-replace/ ; https://docs.pingcap.com/tidb/stable/pessimistic-transaction/ ; https://docs.pingcap.com/tidb/stable/mysql-compatibility/

**23. Window functions** — Confirmed: `ROW_NUMBER()`, `FIRST_VALUE()`, `LAST_VALUE()`, `NTH_VALUE()`, `LAG()`, `LEAD()`, ranking functions; only `GROUP_CONCAT()` and `APPROX_PERCENTILE()` cannot be window functions. https://docs.pingcap.com/tidb/stable/window-functions/

**24. `LIKE` vs `REGEXP` and indexes** — Confirmed. Docs: "A query cannot use indexes if the `LIKE` condition starts with wildcard `%`" (prefix patterns are fine). Source: `pkg/util/ranger/checker.go` builds index ranges for `ast.Like` and has no `Regexp` case, so `REGEXP` cannot produce an index range. https://docs.pingcap.com/tidb/stable/dev-guide-index-best-practice/ ; https://github.com/pingcap/tidb/blob/release-8.5/pkg/util/ranger/checker.go

**25. `DATETIME` vs `TIMESTAMP`** — Confirmed. TIMESTAMP range to '2038-01-19 03:14:07.999999', converted "from the current time zone to UTC" on store; "DATETIME is not handled in this way"; the page warns of the "Year 2038 Problem". https://docs.pingcap.com/tidb/stable/data-type-date-and-time/

### MongoDB

**26. Change streams** — Confirmed. "Change streams are available for replica sets and sharded clusters"; `startAtOperationTime` "New in version 4.0"; `updateLookup` returns "the current majority-committed version of the document ... may differ from the changes described in updateDescription if any other majority-committed operations have modified the document"; `fullDocumentBeforeChange` "Starting in MongoDB 6.0", collection "must have `changeStreamPreAndPostImages` enabled". https://www.mongodb.com/docs/manual/changeStreams/ ; https://www.mongodb.com/docs/manual/reference/method/db.collection.watch/ ; https://www.mongodb.com/docs/manual/reference/change-events/update/

**27. Array updates in change events** — Corrected (see table). Example output `updatedFields: { 'scores.1': 0.94 }`; "Removal of array items with the `$pull` operator produces a change event that shows the new array"; `truncatedArrays` = "array truncations performed with pipeline-based updates" (`$addFields`, `$set`, `$replaceRoot`, `$replaceWith`). https://www.mongodb.com/docs/manual/reference/change-events/update/

**28. `$queryStats`** — Corrected (see table). https://www.mongodb.com/docs/manual/reference/operator/aggregation/queryStats/ ; "Starting in MongoDB 7.1" at https://www.mongodb.com/docs/manual/release-notes/8.0/ ; parameter in https://github.com/mongodb/mongo/blob/master/src/mongo/db/query/query_stats/README.md (source README, not a docs page)

**29. `$bsonSize` and `$collStats`** — Confirmed. The current `$bsonSize` page carries no "New in" note (4.4 is EOL); the v4.4 docs tree has its own `$bsonSize` page while the v4.2 URL redirects to the current manual, consistent with 4.4 introduction. `collStats` output fields: `count`, `avgObjSize`, `size`, `storageSize`, `totalIndexSize`, `nindexes` (also `freeStorageSize`, `totalSize`); the `collStats` command is "Deprecated since version 6.2 ... use the `$collStats` aggregation stage". https://www.mongodb.com/docs/v4.4/reference/operator/aggregation/bsonSize/ ; https://www.mongodb.com/docs/manual/reference/operator/aggregation/collStats/ ; https://www.mongodb.com/docs/manual/reference/command/collStats/

**30. `mongoexport --jsonFormat`** — Confirmed. Default `relaxed`; "Modifies the output to use either canonical or relaxed mode of the MongoDB Extended JSON (v2) format." Canonical forms: `{"$oid": ...}`, `{"$date": {"$numberLong": "<millis>"}}`, `{"$numberLong": "50"}`, `{"$numberDecimal": "10.99"}`. https://www.mongodb.com/docs/database-tools/mongoexport/ ; https://www.mongodb.com/docs/manual/reference/mongodb-extended-json/

**31. Oplog window and `operationTime`** — Confirmed. Command response `operationTime`: "Only for replica sets and sharded clusters" (documented under Command Response, which `hello` links to). `rs.printReplicationInfo()` prints "configured oplog size", "log length start to end", first/last event time. Atlas "Set Minimum Oplog Window" (M10+): "corresponds to modifying the `storage.oplogMinRetentionHours`"; default retention 24 hours. https://www.mongodb.com/docs/manual/reference/method/db.runCommand/ ; https://www.mongodb.com/docs/manual/reference/command/hello/ ; https://www.mongodb.com/docs/manual/reference/method/rs.printReplicationInfo/ ; https://www.mongodb.com/docs/atlas/cluster-additional-settings/

**32. mongosh runtime** — Confirmed / partly unsettled. `process.env`: "The script uses the `process.env` object to access your connection string environment variable." `quit()`: "Exits the current shell session." (`exit()` alias). Data types page: "If field's value is a number that can be converted to a 32-bit integer, `mongosh` will store it as `Int32`. If not ... `Double`"; `Long()` and `Decimal128()` constructors for those types; `NumberLong()` accepts strings only. `BSONRegExp()` and `BinData()` documented as mongosh methods. https://www.mongodb.com/docs/mongodb-shell/write-scripts/env-variables/ ; https://www.mongodb.com/docs/mongodb-shell/reference/methods/ ; https://www.mongodb.com/docs/mongodb-shell/reference/data-types/ ; https://www.mongodb.com/docs/mongodb-shell/reference/compatibility/ ; https://www.mongodb.com/docs/manual/reference/method/BSONRegExp/ ; https://www.mongodb.com/docs/manual/reference/method/BinData/

**33. BSON limits and ObjectId** — Confirmed. "The maximum BSON document size is 16 mebibytes." ObjectId: 12 bytes; "A 4-byte timestamp, representing the ObjectId's creation, measured in seconds since the Unix epoch"; 5-byte random value; 3-byte counter. https://www.mongodb.com/docs/manual/reference/limits/ ; https://www.mongodb.com/docs/manual/reference/bson-types/
