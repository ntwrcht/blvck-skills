---
name: mongodb-to-tidb-migration
description: "Plans and executes a migration from MongoDB to TiDB: infers the source schema and access paths, maps document patterns to columns, JSON columns, and child tables, translates queries and updates to SQL, moves data with a bulk load and change-stream catch-up, and validates before cutover. Use when moving collections off MongoDB or Atlas onto TiDB or TiDB Cloud, converting embedded arrays and ObjectIds to relational tables, rewriting find and aggregate pipelines as SQL, or planning a document-store cutover."
---

# MongoDB to TiDB Migration

Move an application from MongoDB to TiDB as a pipeline with a written plan at its centre: assess the source, model the target, translate the queries, move the data, validate, cut over. The plan is the ledger; every decision in it carries the number that justified it.

## When to Use

Use this skill when collections are moving to TiDB or TiDB Cloud: sizing what a migration involves, inferring a schema from documents that never had one, deciding which arrays become child tables and which fields stay JSON, converting `ObjectId` and BSON types, rewriting `find` filters and aggregation pipelines as SQL, designing the export, bulk load, and change-stream catch-up, writing the validation checks and the cutover runbook, and executing those stages once the plan is approved. Typical asks: "move us off Mongo to TiDB", "what would this collection look like as tables", "translate this pipeline to SQL", "plan the cutover".

## When Not to Use

`tidb-engineer` owns TiDB itself: DDL conventions, hotspots, plans and statistics, drivers, TLS, tiers; this skill decides the shape and hands each TiDB decision there for execution. `codebase-design` owns putting a repository seam into an application whose driver calls are scattered through handlers, which this skill needs before it can swap implementations. `research` settles an open question about what the target can do; this skill assumes the answer is probed or known. `debug` owns a failure whose cause is not visible in the applier log or the diff. A MongoDB-to-MongoDB reshaping with no TiDB in the picture is out of scope.

## Artifacts

- Produces: the migration plan at the `migration-plan` key path, see `references/artifact-paths.md` (default `docs/migrations/<slug>.md`); the transform, applier, and validation code the plan calls for, in the project's language
- Consumes: the application's data-access code, read access to the source cluster, `.context/project.md`, `.context/engineering.md`, `.context/adr/`, an existing plan at the same key path when one exists

## Core Rule

Every landing shape and every key is a decision justified by a measured access path: a query shape with a rate, or an insert rate. A table that mirrors a collection because the collection existed, or a primary key kept because it was the `_id`, is a default, and the plan names each default it keeps beside the number that makes it safe.

## Quick Path

A conceptual question ("how would the bucket pattern map?", "does TiDB have `JSON_TABLE`?") gets a direct answer from the Reference Map, in prose. A single pipeline or filter gets its SQL inline. The full workflow runs when a collection, a service, or a system is moving.

## Workflow

Each stage ends when its section of the plan is filled, not when it feels understood. Ask the user in one numbered round per stage, in the house style (`references/asking-the-user.md`), only for what the environment cannot answer: latency targets, the downtime budget, whether ids must survive in URLs, which reports nobody wrote down.

1. **Assess the source.** Run `scripts/infer-schema.js` per collection, then collect access paths from the data-access code, `$queryStats`, and the slow query log, following `references/schema-inference.md`. Done when every collection has field statistics and every hot read and write path is a plan row with a rate.
2. **Establish the target.** Version, tier, TiFlash, transaction mode, driver, through `tidb-engineer`'s probes. Done when the plan's Target facts carry a date.
3. **Model.** Assign each field a landing shape from the access paths using `references/pattern-map.md` and `references/type-map.md`; choose each key from its insert rate; write the DDL and the field map, including how every `schemaVersion` converges. Done when each table's primary key has a number beside it and each array has a stated shape.
4. **Translate.** Rewrite each access path with `references/query-translation.md`; write paths become transactions; the repository seam is named. Done when every path has SQL and an intended index.
5. **Move.** Choose the movement shape and design export, transform, load, and applier from `references/data-movement.md`. Done when the plan states `T0` handling, the resume-token store, the load method, and its expected duration.
6. **Validate and cut over.** Fill the validation table and the runbook from `references/validation-and-cutover.md`. Done when each check has a pass criterion and the runbook names its go/no-go step and rollback boundary.

Present the plan at the end of stage 6 for approval, then execute it section by section, writing observed values back into the validation table as they are measured. TiDB DDL, tuning, and driver work go through `tidb-engineer`; the transform and applier are application code and get tests like any other.

## Landing Shapes

Three places a field can land; decide per field, from the query that touches it.

| Shape | When | TiDB form |
|---|---|---|
| Column | Filtered, sorted, joined, aggregated, or updated on its own | Typed column, indexed for the query shape |
| JSON column | Read and written whole; never filtered on the server; or keys vary per tenant | `JSON`, with generated columns for hot keys later |
| Child table | Elements filtered, counted, joined, paged, or appended independently; or unbounded | Clustered on `(parent_id, seq)` |

Two TiDB facts shape the rest: there is no `JSON_TABLE`, so arrays are unnested through child tables, multi-valued indexes with `MEMBER OF`, or application code; and a row entry is capped at 6 MiB by default, so a document near MongoDB's 16 MB limit cannot land whole.

## Keys

MongoDB's `ObjectId` is time-prefixed, so a table clustered on it writes every new row to its last region. The decision is the table's insert rate at peak, written in the plan:

| Heard in the baseline | What holds |
|---|---|
| "Read-heavy, so the write hotspot doesn't matter" | The hotspot is a function of inserts per second on that table, not of the read-to-write ratio |
| "Load Base Split handles it" | Load Base Split is documented for read-hot regions and shared keys; a sequential key moves the write hotspot to whichever region is newest, and the documented fix is a scattered key |
| "Switch to `NONCLUSTERED` with `SHARD_ROW_ID_BITS` if it becomes a problem" | A secondary index on a sequential column writes in order too, so the unique index on the old id keeps the hotspot, and changing a primary key later is a table rewrite. Decide now: keep `_id` clustered with the rate that makes it safe, or `BIGINT AUTO_RANDOM` plus `UNIQUE KEY (mongo_id)` |

`references/pattern-map.md`, Keys, has the full decision; `tidb-engineer` owns the rest of the hotspot discipline.

## Output Shape

- Plan: `references/migration-plan-template.md`, conclusion first, every table with the pattern it replaces and the number behind its key, every check with a criterion.
- Single translation: the MongoDB form, the SQL, the index it expects, one sentence on any semantic difference (`$ne` and missing fields, `GROUP BY` ordering, `OFFSET` versus keyset).
- Execution updates: the changed plan section and the observed value, in the plan file, with the date.

## Reference Map

- `references/schema-inference.md`: what to collect from the source and where it comes from; the `$queryStats` snippet; write-path discovery; source facts for the move.
- `references/pattern-map.md`: the three landing shapes; each MongoDB pattern, fundamental, and anti-pattern mapped to its TiDB counterpart; the key decision.
- `references/type-map.md`: BSON types to TiDB columns, enumerations, field names, row width.
- `references/query-translation.md`: query operators, aggregation stages, and write operators to SQL; keyset pagination; the repository seam.
- `references/data-movement.md`: movement shapes, export, transform, bulk load, the change-stream applier, landing zone first, rollback.
- `references/validation-and-cutover.md`: count, content, and query checks; the cutover runbook; the go/no-go gate.
- `references/migration-plan-template.md`: the plan's sections.
- `references/asking-the-user.md`: the house style for question rounds.
- `references/artifact-paths.md`: where the plan is written.
- `scripts/infer-schema.js`: mongosh script; samples a collection and prints field statistics, array cardinality, drift, indexes with usage, and hints.

## Next Step

The plan is approved when the user has read it and confirmed the access-path table and each primary key decision, in that order; execution starts after that, not before.

- **If approved:** hand each table's DDL, index, and tuning work to `tidb-engineer` for execution against the target version; hand the transform and applier code to `tdd` for behaviour tests before they touch production data; hand the plan to `scrutinize` when the migration is large enough that an independent review of the runbook is worth a pass; hand the applier's credentials and the source-side read user to `security-audit` when they cross a network boundary.
- **If not approved:** revise the plan in place. When the application has no repository seam to swap behind, escalate to `codebase-design` first. When a target capability the plan leans on is unsettled for the target version or tier, escalate to `research` with that one question. When the disagreement is about downtime budget, id survival, or a latency target, pause on that question in the house style rather than redesigning around a guess.
