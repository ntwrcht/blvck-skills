# Schema Inference

What to collect from the source before designing a target, and where each fact comes from. The output of this step is the **Source facts** and **Access paths** sections of the migration plan; DDL waits for both.

## Field Statistics

Run `scripts/infer-schema.js` once per collection. It samples documents and prints JSON with:

- collection stats: count, average and maximum document size, storage and index size
- per field path: percentage of documents carrying it, BSON types seen, maximum string length, array length p50, p95, and max
- distinct top-level key sets and their counts (drift), and counts per `schemaVersion`
- indexes with their `accesses.ops` from `$indexStats`
- hints: arrays that want a child table, mixed-type fields, documents above TiDB's 6 MiB row entry limit

```bash
COLL=tickets SAMPLE=5000 mongosh "$MONGODB_URI" --quiet scripts/infer-schema.js > tickets.json
```

Optional environment: `DB` (defaults to the URI's database), `VERSION_FIELD` (default `schemaVersion`), `MAX_DEPTH` (default 6). The script only reads: `$sample`, `$collStats`, `getIndexes`, `$indexStats`. Raise `SAMPLE` for collections with rare shapes; a 5,000-document sample misses a shape held by fewer than one document in a thousand.

## Access Paths

A schema is designed from the queries, so the queries are collected before the schema. Four sources, combined:

| Source | Gives | Misses | How |
|---|---|---|---|
| **Application code** | Every query shape the app can issue, including writes | Frequency | Grep the data layer for driver calls: `find(`, `findOne(`, `aggregate(`, `updateOne(`, `updateMany(`, `bulkWrite(`, `$push`, `$lookup`, `$unwind`, `$text`, `watch(`. Read each call site for filter, sort, projection, and the array operators it uses |
| **`$queryStats`** (Atlas M10 and up, or MongoDB 7.1 and later) | Shapes of `find`, `aggregate`, `distinct`, and `count` with execution counts and latency | Writes | See the snippet below |
| **Slow query logs / Performance Advisor** (Atlas M10 and up) | Slow reads and writes with `planSummary`, `keysExamined`, `docsExamined` | Fast queries | Atlas console or the Performance Advisor API; the MongoDB MCP server exposes `atlas-get-performance-advisor` |
| **The people who run it** | Latency budgets, the endpoints that matter, the reports nobody wrote down | Precision | One question round, in the house style |

Top read shapes by frequency, adapted from `mongodb/agent-skills`:

```javascript
db.getSiblingDB("admin").aggregate([
  { $queryStats: {} },
  { $sort: { "metrics.execCount": -1 } },
  { $limit: 25 },
  { $project: {
      command: "$key.queryShape.command",
      ns: "$key.queryShape.cmdNs",
      shape: "$key.queryShape",
      execCount: "$metrics.execCount",
      avgMs: { $divide: [ { $divide: ["$metrics.totalExecMicros.sum", 1000] }, "$metrics.execCount" ] }
  } }
])
```

Add `{ $match: { "key.queryShape.pipeline.$lookup": { $exists: true } } }` after `$queryStats` to list the pipelines that join, which are the ones whose denormalisation is up for review.

Each access path goes into the plan as a row: name, source shape, frequency, latency target, and the fields it filters, sorts, joins, and returns. That row is what decides each field's landing shape.

## Write Paths

`$queryStats` does not record writes, so writes come from code and slow logs. For each write path record: the operator (`$set`, `$push`, `$inc`, positional update, upsert), the fields touched, the rate at peak, and whether it appends to an array. Append rate on an array is what decides whether the array becomes a child table and how its key is chosen.

## Source Facts for the Move

| Fact | How | Why |
|---|---|---|
| Replica set or sharded, MongoDB version | `db.hello()`, `db.version()` | Change streams need a replica set; pre-images need 6.0 |
| Oplog window | `rs.printReplicationInfo()`, or the Atlas minimum oplog window setting | Must exceed the longest applier outage plus the export duration |
| Secondary available for export reads | `rs.status()` | Export runs with `readPreference=secondaryPreferred` |
| Total data and index size per collection | `$collStats` | Sizes the load and the target tier |
| Write rate per collection | `db.serverStatus().opcounters` sampled over a minute, or Atlas metrics | Sizes the applier and the hotspot decision |
| Largest documents | Script output | Anything near 6 MiB needs a child table before it can land |

## Target Facts

The target's version, tier, TiFlash presence, and transaction mode gate what the plan may rely on. `tidb-engineer` owns the probes; record the results in the plan under **Target facts** with the date they were run.
