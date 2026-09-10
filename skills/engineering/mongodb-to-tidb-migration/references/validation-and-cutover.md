# Validation and Cutover

A migration is validated when the counts, the content, the plans, and the latencies all agree, and cut over when the applier lag is zero and the runbook's go/no-go gate passes. Every check below has a pass criterion; write the observed value next to it in the plan.

## Count Checks

| Check | MongoDB side | TiDB side | Pass |
|---|---|---|---|
| Parent rows | `countDocuments({})` | `SELECT COUNT(*)` | Equal at the freeze point |
| Child rows per array | `aggregate([{$group: {_id: null, n: {$sum: {$size: {$ifNull: ["$comments", []]}}}}}])` | `SELECT COUNT(*) FROM ticket_comments` | Equal |
| Per-day buckets | `$group` by `$dateTrunc` on `createdAt` | `GROUP BY DATE(created_at)` | Equal per day; a drift localises to a day |
| Version convergence | `$group` by `schemaVersion` | Not applicable | Every version's count is accounted for in the transform log |
| Unmapped fields | | `SELECT COUNT(*) WHERE extra IS NOT NULL` | Reported, and each distinct key in `extra` is a named decision |
| Largest parents | `$bsonSize` top 20 | `COUNT(*)` of children for the same ids | Equal |

## Content Checks

- **Fingerprints.** For every parent, hash a canonical projection (scalar fields sorted by name, child counts, last child timestamp) on both sides with the same code and compare per day bucket. Disagreement is a list of ids to diff, not a percentage.
- **Deep diff on a sample.** Take a random sample (a few thousand ids, plus the 100 largest and the 100 most recently updated) and reconstruct each document from TiDB through the new repository code; diff against the MongoDB document after applying the same field map. Zero unexplained diffs.
- **Type fidelity.** Spot-check `Decimal128` precision, millisecond timestamps, and any `BIGINT` that crosses into JavaScript.
- **Null semantics.** Where the application distinguished missing from `null`, confirm the chosen landing shape preserved it.

## Query Checks

- `EXPLAIN ANALYZE` every translated access path on production-sized data. No `TableFullScan` on a hot path; the index named in the plan is the index used; no `Sort` operator on a keyset-paged query.
- Compare results, not just plans: run the old and new form of each access path against both stores at the freeze point and diff the result sets.
- Load-test the top paths at one and a half times peak against the real tier; set p99 targets from the current MongoDB numbers.
- Shadow reads: behind a flag, serve a percentage of production reads from both stores and log differences for a day or two before cutover.

## Cutover Runbook

Snapshot-plus-catch-up shape; adapt for dual-write.

| Step | Action | Rollback boundary |
|---|---|---|
| 1 | Freeze writes: mutating endpoints return a retryable error, or the write role is revoked on the source | |
| 2 | Wait for applier lag to reach zero and stay there for a minute | |
| 3 | Run the count checks at the freeze point; run the fingerprint comparison for the last day | |
| 4 | Stop the applier; `ANALYZE TABLE` on every table | Everything above is reversible by unfreezing writes on the source |
| 5 | Flip the data-layer flag to TiDB; rolling restart | |
| 6 | Smoke test: every hot read path and one representative write, on a test tenant | **Go/no-go.** A failure here flips the flag back and unfreezes the source with no data loss |
| 7 | Unfreeze writes | From here, rollback needs the reverse applier |
| 8 | Watch: Key Visualizer for write hotspots, slow query log for plans without the intended index, applier is off, error rates | |

Keep the source read-only for an agreed number of days, take a final `mongodump` for audit, then decommission.

## Go/No-Go Gate

All of these are written in the plan with their observed values before step 1:

- Count checks pass on the last full comparison.
- Fingerprint disagreement is zero, or every disagreeing id is explained.
- Every hot path's `EXPLAIN ANALYZE` uses its intended index.
- Load test met the p99 targets on the real tier.
- Applier lag has been under the freeze budget for the last day.
- The reverse applier is rehearsed, or its absence is an accepted risk signed off by the owner.
