# Migration Plan Template

The artifact this skill produces, written to the `migration-plan` key path (default `docs/migrations/<slug>.md`). Every section is filled or explicitly marked open; a reader should be able to run the move from this file and `tidb-engineer`.

```markdown
# <System> — MongoDB to TiDB migration plan

## Summary

<Conclusion first: the movement shape, the table count, the downtime, the cutover date, the top risk.>

## Source facts

| Collection | Documents | Avg / max size | Arrays (p95 / max) | Versions | Notes |
|---|---|---|---|---|---|

Cluster: <MongoDB version, replica set or sharded, oplog window, tier>. Write rate at peak: <per collection>. Collected on <date> with `scripts/infer-schema.js`.

## Target facts

TiDB <version>, <tier>, TiFlash <yes/no>, transaction mode <pessimistic/optimistic>, driver <name>. Probed on <date>.

## Access paths

| # | Name | Source shape | Rate | Latency target | Filters / sorts / joins | Served by |
|---|---|---|---|---|---|---|

Write paths listed separately with operator, fields, rate, and whether they append to an array.

## Target schema

<DDL per table. Under each table: the collection and pattern it replaces, the primary key decision with the number that justified it, the landing shape of each notable field.>

## Field map

| Collection.field | Table.column | Type | Transform | Versions affected |
|---|---|---|---|---|

Unmapped fields land in `extra JSON`.

## Query translation

<Per access path: the MongoDB form, the SQL, the index it uses, the `EXPLAIN ANALYZE` verdict once measured.>

## Data movement

Shape: <offline / snapshot plus catch-up / dual-write>. Export: <tool, source read preference, T0>. Transform: <where the shared mapping lives>. Load: <IMPORT INTO / batched INSERT, expected duration>. Applier: <resume token store, sharding, lag metric>.

## Validation

| Check | Pass criterion | Observed | Date |
|---|---|---|---|

## Cutover runbook

<Numbered steps with owner, expected elapsed time, and the rollback boundary. The go/no-go gate named.>

## Deferred and risks

| Deferred | Risk left | Owner | Revisit when |
|---|---|---|---|

## Open questions

<Numbered, each with the recommended answer and the evidence, in the house asking style.>

## Decision log

| Date | Decision | Alternatives | Why |
|---|---|---|---|
```
