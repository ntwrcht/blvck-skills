# Schema Design

TiDB stores every table as key ranges split into Regions and spread across TiKV nodes. Schema decisions that are cosmetic on MySQL, such as the primary key type, decide whether writes spread across the cluster or pile onto one Region. Design for distribution first, then for the queries.

## Primary keys

Every table gets an explicit primary key. Without one TiDB adds a hidden `_tidb_rowid`, which is sequential and therefore a hotspot, and which interacts badly with `AUTO_INCREMENT`.

| Need | Choose | Why |
|---|---|---|
| Surrogate key, write-heavy | `BIGINT PRIMARY KEY AUTO_RANDOM` | Random high bits scatter inserts across Regions |
| Surrogate key, MySQL-compatible ordering required | `BIGINT AUTO_INCREMENT` with `AUTO_ID_CACHE 1` | Centralised allocation (GA v6.5.0) gives strictly increasing IDs with minimal gaps; still a write hotspot |
| Natural key, e.g. `(tenant_id, order_no)` | Clustered composite primary key | Rows co-locate by tenant; range scans within a tenant are cheap |
| UUID from the application | `BINARY(16)` or `CHAR(36)` clustered | Random by nature, no hotspot; bigger secondary indexes |
| Time-ordered writes with range reads | `AUTO_RANDOM` plus a secondary index on `(user_id, created_at)` | Never lead the primary key with a timestamp |

`AUTO_RANDOM` rules: `BIGINT`, part of the primary key (usually the first column), cannot combine with `AUTO_INCREMENT` or `DEFAULT`, and cannot be added or removed by `ALTER TABLE` except for the one documented conversion of a `BIGINT AUTO_INCREMENT` primary key via `MODIFY COLUMN ... AUTO_RANDOM(5)`. Explicit inserts of the column need `@@allow_auto_random_explicit_insert = 1`; after explicit inserts, `ALTER TABLE t AUTO_RANDOM_BASE = 0` avoids collisions. `AUTO_RANDOM(S)` sets the shard bits; the default of 5 suits most tables.

```sql
CREATE TABLE events (
  id         BIGINT PRIMARY KEY AUTO_RANDOM,
  user_id    BIGINT NOT NULL,
  event_type VARCHAR(64) NOT NULL,
  payload    JSON,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_user_created (user_id, created_at)
);
```

## Clustered and non-clustered tables

A primary key on `BIGINT` or a composite key is clustered by default (`CLUSTERED`): the row lives at the key. A non-clustered table (`NONCLUSTERED`, or older defaults for some key types) stores rows by `_tidb_rowid` and the primary key becomes a unique index. Prefer clustered. Check with `SHOW CREATE TABLE`, and add `SHARD_ROW_ID_BITS = 4` to a non-clustered table to scatter its hidden row IDs.

## Hotspots

A hotspot is one Region absorbing most writes or reads. Causes and cures:

| Cause | Cure |
|---|---|
| Sequential primary key | `AUTO_RANDOM`, or a composite key with a scattering prefix |
| Secondary index on a monotonic column, such as `created_at` alone | Lead the index with a low-cardinality but well-distributed column, or accept and pre-split |
| A brand-new table taking bulk writes | `SPLIT TABLE t BETWEEN (...) AND (...) REGIONS n` before the load |
| One tenant or one key dominating | Application-level sharding of the hot key, or a resource group to cap it |

`information_schema.tidb_hot_regions` and the Key Visualizer confirm a hotspot before you redesign for one.

## Data types

- `utf8mb4` everywhere. The default collation is `utf8mb4_bin`, so set `utf8mb4_general_ci` or `utf8mb4_0900_ai_ci` explicitly on columns compared with `=` when the application expects MySQL's case-insensitive default.
- `DATETIME(3)` or `TIMESTAMP(3)` for event time; TiDB stores fractional seconds when asked.
- `DECIMAL` for money. `FLOAT(M,D)` precision specifiers are deprecated.
- `JSON` for genuinely semi-structured data. Index a JSON path through a generated column; multi-valued indexes on JSON arrays exist from v6.6.0 (GA v7.1.0).
- `VECTOR(D)` for embeddings; see `references/vector-search.md`.
- No `GEOMETRY`. Store latitude and longitude as `DECIMAL(9,6)` and filter with a bounding box.

## JSON columns

Extract, index, and constrain through generated columns:

```sql
ALTER TABLE events
  ADD COLUMN country CHAR(2) GENERATED ALWAYS AS (payload->>'$.geo.country') VIRTUAL,
  ADD INDEX idx_country (country);

ALTER TABLE events ADD INDEX idx_tags ((CAST(payload->'$.tags' AS CHAR(64) ARRAY)));   -- multi-valued, v6.6+
SELECT * FROM events WHERE 'vip' MEMBER OF (payload->'$.tags');
```

`JSON_EXTRACT`, `->`, `->>`, `JSON_CONTAINS`, `JSON_OVERLAPS`, and `MEMBER OF` behave as in MySQL 8. `JSON_TABLE` is unsupported; unnest arrays in the application or through a multi-valued index plus `MEMBER OF`. A JSON column is a fine landing zone for document data during a migration; promote hot paths to real columns as queries stabilise.

## Time-to-live

Row expiry is a table attribute, not a job:

```sql
CREATE TABLE sessions (...) TTL = expires_at + INTERVAL 0 DAY TTL_ENABLE = 'ON' TTL_JOB_INTERVAL = '1h';
ALTER TABLE events TTL = created_at + INTERVAL 90 DAY;
SELECT * FROM mysql.tidb_ttl_job_history ORDER BY create_time DESC LIMIT 5;
```

TiDB deletes expired rows in distributed background batches (experimental v6.5.0, GA v7.0.0), so TTL never competes with insert traffic the way a nightly `DELETE` does. The TTL column must be `DATE`, `DATETIME`, or `TIMESTAMP`. A TTL table cannot be the parent of a foreign key. Behaviour alongside TiFlash replicas is undocumented; test it.

## Partitioning

`RANGE`, `RANGE COLUMNS`, `LIST`, `HASH`, and `KEY` partitioning are supported; `SUBPARTITION` is not. Partition when a query always carries the partition key, when you drop whole time ranges, or to isolate hotspots. Partition pruning needs the key in the `WHERE` clause; a query without it scans every partition. Global indexes (`UNIQUE KEY ... GLOBAL`) arrive in v8.3.0 (GA v8.4.0); on older versions every unique key must include the partition key.

## Foreign keys

Enforced and default-on from v6.6.0 (GA v8.5.0); before v6.6.0 the syntax parses but the constraint is inert, and stays inert after an upgrade. They cost a lookup per write. On a high-write table, many teams enforce in the application and keep the column plus an index for joins. Whatever the choice, record it in the project's engineering context.

## Sequences and generated values

`CREATE SEQUENCE` exists (v4.0+) with a local cache of 1000 values by default, so values are unique and increasing but gaps appear after restarts or failovers. `DEFAULT (UUID())`, `RAND()`, and `NEXTVAL()` defaults have long worked; a wider but still fixed list of expression defaults arrived in v8.0.0 (GA v8.1.0).

## DDL habits

- One change per `ALTER TABLE`. Split multi-change statements.
- Adding an index on a large table is online and asynchronous; `ADMIN SHOW DDL JOBS` shows progress, and `tidb_ddl_reorg_worker_cnt` and `tidb_ddl_reorg_batch_size` throttle it. Fast reorg (`tidb_ddl_enable_fast_reorg`) is on by default from v6.5.0.
- Column type changes that shrink or re-encode a column need a backfill migration, not an `ALTER`.
- Primary key changes on a clustered table are a new table plus backfill plus swap.
- Test every DDL against a cluster on the target version. `ALGORITHM=INSTANT` is an assertion, and TiDB rejects the statement rather than silently doing a copy.
