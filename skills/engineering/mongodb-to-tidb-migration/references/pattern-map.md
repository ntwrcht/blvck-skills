# Pattern Map

Each MongoDB schema pattern encodes a decision that was right for a document store. Some decisions still hold on TiDB, some invert because joins and multi-row transactions are cheap, and some dissolve because the constraint they worked around (one document, 16 MB, single-document atomicity) is gone. Read the source collection through this map before writing DDL.

The pattern names follow MongoDB's own catalogue, as vendored from `mongodb/agent-skills` (see `NOTICE.md`).

## The Three Landing Shapes

Every field in a document lands in one of three places. Decide per field from the access paths, never per collection.

| Landing shape | Use when | TiDB form |
|---|---|---|
| **Column** | The field is filtered, sorted, joined, aggregated, or updated on its own | Typed column, indexed where a query shape needs it |
| **JSON column** | The field or subdocument is read and written whole and never filtered on the server; or its keys vary per tenant | `JSON` column; promote a hot key later with a generated column plus index |
| **Child table** | An array whose elements are filtered, counted, joined, paged, or appended independently, or whose length is unbounded | Table with clustered primary key `(parent_id, seq)` or `(parent_id, ts, id)` |

A `JSON` column is a legitimate landing zone during migration, not a failure of modelling: land the document, then peel columns out as the translated queries stabilise. What decides is whether the query touches the field on the server.

## Fundamentals

| MongoDB rule | What it produced | TiDB counterpart |
|---|---|---|
| Embed 1:1 data always read together | Subdocument (`shippingAddress`) | Columns on the same row, or one `JSON` column when the object is opaque to every query |
| Embed 1:few bounded arrays (addresses 1–5, line items 1–50) | Bounded array | `JSON` when read whole; child table when any query filters, joins, or updates one element |
| Reference 1:many and unbounded arrays (comments, events) | Separate collection with parent id, or an array that grew anyway | Child table, clustered on `(parent_id, seq)`; the Mongo array position becomes `seq` so a change-stream applier stays idempotent |
| Many-to-many: embed ids in the primary direction | `categoryIds: [...]` on the product | Junction table `(a_id, b_id)` with a second index `(b_id, a_id)`; the SQL default |
| Trees: parent refs, ancestors array, materialised path | Depends on the query | Adjacency list plus `WITH RECURSIVE` (supported); materialised path column with an index and `LIKE 'prefix%'`; ancestors array becomes a closure table |
| 16 MB document limit | Subset pattern, overflow documents | TiDB's default per-row limit is 6 MiB (`txn-entry-size-limit`); a document above it cannot land whole in a `JSON` column, so its arrays go to child tables |
| `$jsonSchema` validation | `required`, `bsonType`, `enum`, `maxItems` | `NOT NULL`, column types, `ENUM` or a `VARCHAR` plus application check, `UNIQUE`; `CHECK` exists from v7.2.0 behind `tidb_enable_check_constraint`, off by default |
| Data accessed together is stored together | Denormalised documents | Still true for the row; across rows a clustered-key range scan or a primary-key join is one round trip, so the co-location argument for duplication is weaker |

## Design Patterns

| Pattern | What the migration inherits | TiDB counterpart | Watch for |
|---|---|---|---|
| **Approximation** (batched counters, `viewCount` plus `lastSyncedAt`) | An inexact counter and an app-side accumulator | Keep the batching. A counter row updated on every event is a single-row write hotspot on TiDB too | Spread a hot counter across N shard rows summed on read, or keep app-side batching |
| **Archive** (`sales` plus `sales_archive`, `$merge` by cutoff date) | A second collection of self-contained snapshots, a `retentionPolicy` sentinel | One table with `RANGE` partitioning on the date column and `DROP PARTITION` or `TRUNCATE PARTITION` for retirement; a TTL attribute when old rows are deleted rather than kept; a TiFlash replica when the archive exists for analytics | Partition pruning needs the date in `WHERE`; `retentionPolicy: permanent` becomes a `LIST` partition or a column the TTL expression respects |
| **Attribute** (`attributes: [{k, v}]`, one multikey index) | An EAV array with heterogeneous value types | Either a child table `(entity_id, k, v)` indexed `(k, v)` with typed value columns, or a `JSON` object `{k: v}` with generated columns for the few hot keys | Per-tenant key sets stay `JSON`; only keys that queries filter on earn a generated column |
| **Bucket** (`_id: "123_1698349623"`, `count`, bounded `history` array) | A composite string id, a count, a capped array; paging by bucket | Rows are cheap: one row per event, clustered `(entity_id, ts, id)`, keyset pagination. The composite `_id` splits into two columns | If buckets fed analytics, add a TiFlash replica instead of keeping buckets |
| **Computed** (`stats` subdocument, `computedAt`, windowed variants) | Precomputed aggregates, staleness stamps, sometimes a materialised collection | Columns maintained in the same transaction as the write (multi-row atomicity is now free), or a summary table refreshed with `INSERT ... SELECT ... ON DUPLICATE KEY UPDATE`; try the live aggregate on TiFlash before keeping the cache | Keep `computed_at` when the UI shows freshness |
| **Document Versioning** (current doc with `v`, `revisions` with full snapshots) | A monotonic `v`, a revisions collection, optional TTL retention | `entity` table plus `entity_revisions (entity_id, v, snapshot JSON, changed_at)` with clustered key `(entity_id, v)`, written in one transaction; TTL on revisions for retention | `AS OF TIMESTAMP` reads only reach back the GC window (10 minutes by default) and are not a substitute for a revisions table |
| **Extended Reference** (`customer: {_id, name, email}` copied onto the order, `cachedAt`) | Duplicated slowly-changing fields and a fan-out update on change | Decide per field: a **cache** of current data becomes a join, a primary-key lookup per row; a **snapshot** that must record the value at the time (name and tier on an order) stays as columns or `JSON` | Reading the copy as a cache and then joining anyway doubles the work |
| **Outlier** (`hasExtras`, overflow documents in batches) | A capped array, a flag, a denormalised count, an overflow collection | Dissolves: the child table holds every element; drop `has_extras`; keep the count column when the UI shows it | Re-check the largest parents' child counts against the paging plan |
| **Polymorphic** (`type` discriminator, sparse type-specific fields, partial indexes) | One collection of mixed shapes; partial indexes per type; wildcard indexes | Single-table inheritance: shared columns, a `type` column, and `JSON` for type-specific fields, with generated columns for the type-specific fields queries filter on; class-table inheritance (shared table plus one table per type joined on the primary key) when types need conflicting indexes | TiDB has no partial indexes: a generated column that is `NULL` outside its type, or `LIST` partitioning by type, stands in |
| **Schema Versioning** (`schemaVersion`, mixed shapes, lazy migration) | Coexisting document shapes; missing version means v1 | The migration is the moment to converge: the transform step maps every version to the target shape; keep a `schema_version` column only while application code still branches on it | Count documents per version before writing DDL; `scripts/infer-schema.js` reports it |
| **Time Series Collections** (`metaField`, `timeField`, `expireAfterSeconds`) | Engine-managed buckets, a retention TTL, a metadata dimension | Plain table clustered on `(series_id, ts)`, a TTL attribute for retention, `RANGE` partitioning on `ts` when whole ranges are dropped, a TiFlash replica for aggregates | A single dominant series writes to one key range; spread it with a hash bucket column in the key when the series cardinality is low |

## Anti-patterns, Inverted

| MongoDB anti-pattern | On TiDB |
|---|---|
| Excessive `$lookup` | A join on an indexed key is a normal query. Denormalisation added to dodge `$lookup` is a candidate to remove, not to port |
| Unnecessary collections (one per day, per tenant, per category) | One table with the discriminator as a column and an index or partition on it |
| Unnecessary indexes | Port only indexes with non-zero `accesses.ops` in `$indexStats`, then add the ones the translated queries need. Every TiDB index is a write amplification on a distributed store |

## Keys

MongoDB's `_id` is usually an `ObjectId`: 4 bytes of seconds since the epoch, then random and counter bytes. New ids sort after old ones, so a table clustered on `_id` writes every new row to its last region. Decide the primary key of each write-heavy table from its insert rate:

- **Keep `_id` as the clustered primary key** when the table's insert rate is modest and point reads by id dominate. Say so in the plan with the measured rate. Load Base Split is documented for regions hot under read load and shared keys; a sequential key keeps moving the write hotspot to the newest region, and the documented fix for that is a scattered key.
- **`BIGINT AUTO_RANDOM` primary key plus `UNIQUE KEY (mongo_id)`** when inserts are heavy. Point reads by the old id cost an index lookup and a table lookup; the application keeps generating `ObjectId`s so URLs and clients survive.
- **Child tables** cluster on `(parent_id, seq)`. Appends to old parents scatter; appends to new parents follow the parent's key distribution.

A non-clustered table with `SHARD_ROW_ID_BITS` scatters the rows, but a secondary index on a sequential column writes its entries in order too, so the unique index on the old id keeps the hotspot; it is not the fix for an `ObjectId` key.

`tidb-engineer` owns the rest of the key and hotspot discipline; hand the TiDB side there once the shape is chosen.
