# Data Movement

How rows get from MongoDB to TiDB, how writes are handled while both stores exist, and what keeps the copy honest. Pick the movement shape from the downtime budget and the write rate, then fill in the tools.

TiDB Cloud's Data Migration service reads MySQL-compatible sources only. A MongoDB source needs a bring-your-own pipeline: export, transform, bulk load, and, when writes continue during the move, a change-stream applier.

## Movement Shapes

| Shape | Downtime | Fits when | Cost |
|---|---|---|---|
| **Offline snapshot** | Whole copy duration | Small data, a maintenance window, or a read-only source | One export, one load, one validation |
| **Snapshot plus catch-up** | Minutes: drain the applier, flip | The usual case: production writes continue, a short write freeze is acceptable | Export, load, a change-stream applier that runs until cutover |
| **Dual-write** | None at the database | Application-level flag, both stores written by the app, reads switched later | Application code in both directions, reconciliation, the longest tail of risk |

Snapshot plus catch-up is the default. Dual-write is chosen when the application already has a write-abstraction layer and zero write downtime is a stated requirement, and it still needs the snapshot to seed TiDB.

## Export

Read from a secondary (`readPreference=secondaryPreferred`) so the export does not contend with production. Three sources, in order of preference:

1. **A driver scan in `_id` ranges**, run by the same transform code that will handle change events, so bulk and catch-up share one mapping. Batch by `_id` with `{_id: {$gt: last}}` and `.sort({_id: 1})`, never `skip`.
2. **`mongoexport --type=json`** (Extended JSON v2, canonical mode) when a transform in another language will read files. Canonical mode keeps `$oid`, `$date`, `$numberLong`, and `$numberDecimal` so types survive.
3. **`mongodump`** when a BSON archive is wanted for rollback or audit; it is not a transform input.

Record the cluster time `T0` before the export starts: `db.hello().operationTime` or the `clusterTime` of the first read. The applier starts from `T0` so nothing written during the export is lost.

## Transform

One document fans out to one parent row plus zero or more child rows per array. The transform is deterministic, version-aware, and shared between bulk and catch-up:

- Map each `schemaVersion` (missing means v1) to the target shape. The plan's field map is the specification.
- Fields the map does not mention land in an `extra JSON` column rather than being dropped; the validation step reports how many rows have non-null `extra`.
- Array elements carry their position as `seq`, so a later `$push` event at `comments.17` applies as `seq = 17`.
- Convert `ObjectId` to the chosen form, `Date` to UTC `DATETIME(3)`, `Decimal128` without narrowing. `references/type-map.md` has the table.
- Emit CSV per table when the load is `IMPORT INTO`; emit rows when the load is batched `INSERT`.

## Bulk Load

| Method | Use when | Notes |
|---|---|---|
| `IMPORT INTO table FROM 's3://...'` | Tens of millions of rows and up | GA in v7.5.0. CSV, SQL, or Parquet from S3 or GCS (local files on self-managed only); the TiDB Cloud console Import task wraps the same engine and also reads Azure Blob. The target table must be empty, so the load precedes any applier writes. Sorted input by primary key loads fastest |
| Batched multi-row `INSERT` | Up to a few million rows, or when the transform streams rows directly | A few thousand rows per statement, each statement its own transaction, well under the 100 MiB transaction limit. Parallel writers by `_id` range |
| `LOAD DATA LOCAL INFILE` | Small tables, ad hoc | Runs as a single transaction (the default since v4.0, the only mode from v7.0, and part of the surrounding transaction from v7.6), so a large file hits the 100 MiB transaction limit; chunk the files or use `IMPORT INTO` |

After the load: `ANALYZE TABLE` every table, then add TiFlash replicas (`ALTER TABLE ... SET TIFLASH REPLICA 1`) so the replica builds from settled data. Build secondary indexes after the load when the tool allows it; `IMPORT INTO` handles indexes itself.

Rows above 6 MiB (`txn-entry-size-limit`, the default per-entry cap; treat it as fixed on TiDB Cloud) fail to load. The inference script reports the largest documents; a document that large has an array that belongs in a child table.

## Change-Stream Applier

A small, long-running process that turns MongoDB change events into idempotent SQL:

- Open `collection.watch(pipeline, {fullDocument: 'updateLookup', startAtOperationTime: T0})` on each collection. Change streams need a replica set or sharded cluster.
- Persist the resume token after every applied batch; restart from it. Set the source's minimum oplog window (Atlas exposes it as a cluster setting) to cover the longest outage the applier might have.
- Apply events per `_id` in order. Shard the applier by `_id` hash when one process cannot keep up; never reorder events for one document.
- `insert` and `replace`: upsert the parent (`INSERT ... ON DUPLICATE KEY UPDATE`), then reconcile children (delete and reinsert, or upsert by `seq`).
- `update`: `updateDescription.updatedFields` names dotted paths. A path like `comments.17` is a `$push` at position 17; a `$pull` or `$slice` shows up as the whole new array under `updatedFields`, and only pipeline-style updates report `truncatedArrays`. When the diff is hard to map, fall back to `fullDocument` and reconcile the whole row and its children.
- `delete`: delete the parent and its children in one transaction.
- `fullDocument: 'updateLookup'` returns the document as it is now, not as it was at the event, which is fine for convergence and wrong for history; pre-images (`fullDocumentBeforeChange`, MongoDB 6.0 and later, enabled per collection) exist when the difference matters.
- Overlap with the export is harmless because every apply is an upsert: replaying an older event onto newer data converges.

Expose applier lag (`clusterTime` of the last applied event against the source's current time) as a metric; cutover waits on it.

## Landing Zone First

When the schema is still moving, land each collection as `(id, doc JSON, extra JSON, updated_at)` plus child tables for the arrays already known to need them, run the translated queries against generated columns, and peel columns with `ALTER TABLE ... ADD COLUMN ... GENERATED ALWAYS AS (doc->>'$.x') VIRTUAL` followed by an index. Promote a generated column to a real column with a backfill once its query shape is settled. The applier keeps writing `doc`, so nothing is lost while the shape evolves.

## Rollback

Until the first write lands in TiDB, rollback is turning the flag back: MongoDB never stopped being complete. After that, rollback needs a reverse applier (reassemble documents from parent and child rows, upsert into MongoDB), which is written and rehearsed on a sample before cutover or explicitly declared out of scope in the plan.
