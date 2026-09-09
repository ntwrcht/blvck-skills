---
name: tidb-engineer
description: "Builds, modifies, reviews, and tunes applications on TiDB and TiDB Cloud across schema design, MySQL-compatible SQL, transactions, query plans and statistics, drivers and ORMs, TLS connections, vector and full-text search, and cluster provisioning. Use when working on TiDB DDL, hotspots, AUTO_RANDOM, EXPLAIN ANALYZE, optimizer hints, TiDB Cloud Starter or Dedicated, the serverless HTTP driver, Prisma or Kysely or mysql2 or pytidb against TiDB, or porting MySQL SQL to TiDB."
---

# TiDB Engineer

Guide TiDB work with senior engineering judgment: TiDB speaks MySQL but is a distributed database, so probe the target's version and features before asserting what it can do, and design every hot table so writes spread across the cluster.

## When to Use

Use this skill for TiDB and TiDB Cloud work: table and index design, `AUTO_RANDOM` and hotspot avoidance, DDL and migrations, SQL that must run on TiDB, MySQL-to-TiDB compatibility passes, transactions and retry contracts, slow queries and `EXPLAIN ANALYZE`, statistics and bindings, optimizer hints, TiFlash and analytical reads, vector and full-text search, TTL and partitioning, driver and ORM setup (`mysql2`, Prisma, Kysely, the serverless HTTP driver, pytidb, SQLAlchemy), TLS to TiDB Cloud, provisioning with `ticloud`, disposable Zero sandboxes, flashback recovery, and code review of any of the above.

## When Not to Use

`mongodb-to-tidb-migration` plans and executes a move from MongoDB, from document analysis through cutover; this skill is what it hands the TiDB half to. When the database is plain MySQL and TiDB is not in the picture, generic SQL guidance applies and this skill is the wrong lens; when a MySQL-driver project turns out to be TiDB (`SELECT VERSION()` says so, or the host ends in `tidbcloud.com`), switch to this skill. `next-engineer` owns Next.js rendering, routing, and caching; this skill covers the database half of that stack. `codebase-design` answers questions about a module's interface or seam; this skill brings the TiDB conventions. `debug` owns a failure whose cause is not visible in a plan or an error message. `security-audit` owns a full review of credentials and exposure.

## Artifacts

- Produces: code changes, SQL migrations, tuning notes as SQL comments or bindings
- Consumes: stories at the `story` key path (if present), see `references/artifact-paths.md` (default `docs/stories/<slug>.md`); `.context/project.md`, `.context/engineering.md`, `.context/git-workflow.md`, `.context/learning.md`, `.context/adr/`

## Core Rule

Probe before asserting. Features on TiDB are gated by version, tier, and the presence of TiFlash, and the same statement can be unsupported on one cluster and idiomatic on the next. A claim that something "is not supported on TiDB" or "works the same as MySQL" needs a `SELECT VERSION()`, a capability probe, or a reference in this folder behind it, and generated DDL states the version it assumes.

## Quick Path

Answer conceptual and architecture questions directly as prose with tradeoffs, and give single-line fixes or small SQL and client snippets inline. Run the full project-context workflow only when generating, modifying, reviewing, or tuning project code.

## Workflow

1. Inspect local context before changing code. Read `.context/INDEX.md` when present, then the domain files the task needs. If context is missing and project code changes are needed, follow `references/project-context.md`.
2. Establish the stack facts from `references/stack-facts.md`: version, tier, TiFlash, transaction mode, primary key convention, driver, migration tool. When a connection is available, run the two probes there. When it is not, say which assumptions the output carries.
3. Read the existing schema before writing SQL: the migration directory and `SHOW CREATE TABLE` on every table you touch. Note clustered or not, collation, indexes, TTL and partition attributes.
4. Load only the reference files the task needs from the Reference Map.
5. Make the smallest coherent change. Schema changes go through the project's migration tool, one logical change per `ALTER TABLE`, and are tested against TiDB of the target version, using a TiDB Cloud branch, a Zero instance, or `tiup playground`.
6. Validate: the migration applies from scratch, generated types or clients are regenerated, the test suite passes against TiDB, and for a tuning change `EXPLAIN ANALYZE` shows the bottleneck operator improved.

## Engineering Defaults

- Every table has an explicit primary key. Write-heavy tables use `BIGINT PRIMARY KEY AUTO_RANDOM`, a scattering composite key, or an application-generated random ID; a timestamp never leads a primary key or a hot index.
- Stored procedures, triggers, events, `OPTIMIZE TABLE`, writable views, `MATCH ... AGAINST`, and `GEOMETRY` stay in MySQL. Logic moves to the application, expiry moves to a TTL attribute, keyword search moves to TiDB full-text search where the tier offers it.
- Every `ORDER BY` that matters is explicit; `GROUP BY` does not sort on TiDB.
- TLS with certificate and hostname verification on every TiDB Cloud endpoint, the cluster prefix on the username, port 4000, pool idle timeout at or below 300 seconds (AWS public endpoints cut idle connections at 340), and the HTTP driver on runtimes without TCP.
- `BIGINT` IDs cross into JavaScript as strings or `BigInt`; `AUTO_RANDOM` values exceed the safe integer range.
- Pessimistic transactions by default. An optimistic transaction ships with a whole-transaction retry loop and idempotent statements, and the caller is told so.
- Statistics before hints. A bad plan gets `SHOW STATS_HEALTHY` and `ANALYZE TABLE` before any `/*+ ... */`, and a hint that stays gets a comment saying why. Bindings are removed with `DROP GLOBAL BINDING`, never by editing `mysql.bind_info`.
- Bulk writes and deletes are chunked under the transaction size limit; age-based deletes become TTL.
- Tests run against TiDB, not MySQL. DDL that passes on MySQL is not evidence.

## Version Guide

| Feature | Available from | Notes |
|---|---|---|
| Foreign key enforcement | v6.6.0 (GA v8.5.0) | Earlier versions parse and ignore; costs a lookup per write |
| Multi-valued JSON indexes, `MEMBER OF` | v6.6.0 (GA v7.1.0) | Index arrays inside JSON columns; `JSON_TABLE` stays unsupported |
| TTL table attributes | v6.5.0 (GA v7.0.0) | Background row expiry |
| Fast index reorg | v6.5.0 (default on) | Large-table index builds |
| `AUTO_ID_CACHE 1` centralised allocation | v6.4.0 (GA v6.5.0) | Strictly increasing `AUTO_INCREMENT` |
| Global indexes on partitioned tables | v8.3.0 (GA v8.4.0) | Unique keys no longer need the partition key |
| `VECTOR` type, HNSW index, `VEC_*` functions | v8.4.0 (v8.5.0 recommended, experimental) | Index needs TiFlash; cosine and L2 only |
| Full-text search, `FTS_MATCH_WORD` | TiDB Cloud Starter, five AWS regions | Not on self-managed or Dedicated; probe with a throwaway `CREATE TABLE` |
| Auto embedding, `EMBED_TEXT` | TiDB Cloud Starter on AWS | Probe with `SELECT EMBED_TEXT(...)` |
| HTTP serverless driver | TiDB Cloud Starter and Essential | 10 000 rows per query, backend only |

Ask before defaulting when the version or tier is unknown and the change depends on a gated feature.

## Output Shape

- Small fix: the changed SQL or code plus one sentence naming the TiDB behaviour that motivated it.
- New table or feature: migration with the assumed version in a comment, indexes with the query shapes they serve, client code, tests against TiDB, and a short decision note on the primary key.
- Tuning: the `EXPLAIN ANALYZE` before and after, the bottleneck operator named, and the least invasive fix that moved it.
- Review: findings first with file and line references; load `references/code-review.md` for full PR reviews.

## Reference Map

- `references/project-context.md`: reading, repairing, or skipping `.context/`, the shared skeleton.
- `references/stack-facts.md`: the facts that change generated code, the probes to run, what makes context stale, what to ask for when the detector cannot run.
- `references/mysql-compatibility.md`: the lint list for SQL ported from MySQL: unsupported statements, behaviour differences, DDL rules, charset defaults.
- `references/schema-design.md`: primary keys, `AUTO_RANDOM`, clustered tables, hotspots, data types, JSON generated columns, TTL, partitioning, foreign keys, DDL habits.
- `references/transactions.md`: pessimistic and optimistic modes, the retry contract, isolation levels, size limits, GC.
- `references/explain.md`: `EXPLAIN` forms, plan columns, operator reference, what to look for.
- `references/query-tuning.md`: the symptom-to-verified-fix loop, clue sources, hotspots, high CPU, plan replayer.
- `references/statistics.md`: health checks, `ANALYZE`, auto analyze tuning, startup stats, bindings.
- `references/index-selection.md`: index hints, composite design, covering, invisible indexes, probe-side selection.
- `references/join-strategies.md`: hash, index, merge, and MPP joins, the decision guide, misoptimisation patterns.
- `references/subquery-optimization.md`: decorrelation, `NO_DECORRELATE`, `SEMI_JOIN_REWRITE`, anti-semi-joins.
- `references/optimizer-hints.md`: the hint catalog, bindings, discipline.
- `references/session-variables.md`: optimizer, execution, statistics, and TiFlash variables with recipes.
- `references/vector-search.md`: `VECTOR` columns, distance functions, HNSW indexes, auto embedding.
- `references/full-text-search.md`: availability probe, index creation, `FTS_MATCH_WORD`, porting `FULLTEXT`.
- `references/flashback.md`: recovering dropped or truncated objects, cluster flashback, `AS OF TIMESTAMP`.
- `references/tidb-cloud.md`: tiers and quotas, Zero sandboxes, `ticloud` provisioning, branches, import and export.
- `references/tls-connections.md`: gateway recognition, per-client TLS settings, pooling against the gateway, failure signatures.
- `references/node-drivers.md`: `mysql2` pools, prepared statements, transactions, `BIGINT` handling, mysqljs legacy.
- `references/serverless-driver.md`: the HTTP driver for Edge and Workers, options, type mapping, limits.
- `references/prisma.md`: datasource URL, `AUTO_RANDOM` workaround, generated DDL review, driver adapter.
- `references/kysely.md`: `MysqlDialect` over `mysql2`, the serverless dialect, typing `BIGINT`.
- `references/nextjs.md`: runtime choice, pool and Prisma singletons, dynamic routes, troubleshooting.
- `references/python-pytidb.md`: pytidb models, CRUD, vector and full-text and hybrid search, plain SQLAlchemy.
- `references/code-review.md`: severity ladder and the six review passes for TiDB code.
- `references/git-workflow.md`: branch names, commits, changelog, PR descriptions.
- `scripts/detect-project.sh`: prints `.context/` drafts from manifests, migrations, and environment files.
- `scripts/collect-diag.sql`: read-only baseline for a tuning session: version, TiFlash, slow queries, hot regions, bindings, stats health.

## Next Step

Do not treat a change as done until the migration applies cleanly against TiDB of the target version, generated types or clients are regenerated if the schema moved, the test suite passes against TiDB, and, for a tuning change, `EXPLAIN ANALYZE` shows the bottleneck operator improved.

- **If approved:** hand off to `tdd` when the change needs behaviour tests it does not have, to `scrutinize` for an independent review of the diff, or to `security-audit` when it touches credentials, TLS configuration, or an exposed endpoint. When the change exposed a shallow module or a contested seam, hand off to `codebase-design` before building more on it. For a full PR review of TiDB code, load `references/code-review.md` here instead of switching skills.
- **If not approved:** revise in place. When a failure's cause is not visible in the SQL error, the plan, or the test output, escalate to `debug` rather than guessing at fixes.
