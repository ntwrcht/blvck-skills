# TiDB Stack Facts

The TiDB-specific facts a task must establish before generating code. The shared skeleton for reading, repairing, or skipping `.context/` is `references/project-context.md`; this file is what it points at.

## Recorded In Context

`.context/engineering.md` holds the TiDB version, deployment tier, transaction mode, primary key convention, driver or ORM, migration tool, and whether TiFlash exists, when the project records them. Ask before generating DDL when the tier or version is blank and the task depends on a gated feature.

## Facts That Change Generated Code

| Fact | Where to find it | Why it matters |
|---|---|---|
| TiDB version | `SELECT VERSION();`, `.context/engineering.md` | Gates foreign keys (6.6), multi-valued indexes (6.6), vectors (8.4), global indexes (8.3), auto embedding |
| Deployment tier | Host name, `ticloud serverless list`, `.context/project.md` | Starter and Essential: public CA, HTTP driver, no `FLASHBACK CLUSTER`; Dedicated: CA file; self-managed: probe everything |
| TiFlash present | `SELECT table_schema, table_name, replica_count, available, progress FROM information_schema.tiflash_replica` | Vector indexes, full-text indexes, MPP joins, analytical reads |
| Transaction mode | `SELECT @@tidb_txn_mode;` | Optimistic requires a retry contract in application code |
| Primary key convention | `SHOW CREATE TABLE` on a hot table | `AUTO_RANDOM`, `AUTO_INCREMENT` with `AUTO_ID_CACHE 1`, or natural composite keys |
| Driver or ORM | `package.json`, `requirements.txt`, `pyproject.toml`, `go.mod` | `mysql2` vs `mysql`, Prisma vs Kysely, pytidb vs SQLAlchemy, HTTP vs TCP |
| Migration tool | `prisma/migrations/`, `alembic/`, `migrations/*.sql`, `db/migrate/` | Where DDL is reviewed before it reaches TiDB |
| Foreign key stance | Migration files, `relationMode` in Prisma | Enforced in the database, or in the application |

## Read Before Writing Code

| Source | Tells you |
|---|---|
| The migration directory | Real schema history, primary key style, whether anyone has used `AUTO_RANDOM` or TTL |
| `SHOW CREATE TABLE` on the tables you touch | Clustered or not, collation, existing indexes, TTL and partition attributes |
| `.env.example` | Whether the project connects by URL or by `TIDB_*` parts, and whether a CA path exists |
| `SHOW GLOBAL BINDINGS;` | Plans someone already pinned; a tuning task starts here |

Two probes worth running before any DDL:

```sql
SELECT VERSION(), @@tidb_txn_mode, @@tidb_analyze_column_options;
SELECT table_schema, table_name FROM information_schema.tiflash_replica;
```

## Stale When

Offer to update the relevant `.context/` domain file when the user mentions or the repo shows:

- A TiDB version upgrade
- A tier change: Zero to Starter, Starter to Dedicated, cloud to self-managed
- TiFlash added or removed
- A switch of transaction mode
- Adoption of vectors, full-text search, TTL, partitioning, or resource groups
- A driver or ORM change, or a move to the HTTP serverless driver
- A change in who enforces foreign keys

## Ask For

The bundled detector (`scripts/detect-project.sh`) inspects manifests, migration directories, environment files, and git history. If it cannot run, ask for:

- TiDB version and deployment tier
- Whether TiFlash replicas exist
- Transaction mode
- Primary key convention on write-heavy tables
- Driver or ORM and version, and the runtime it runs in
- Migration tool
- Test database strategy: a TiDB Cloud branch, a Zero instance, `tiup playground`, or MySQL as a stand-in
- Main branch name, and ticket prefix if commit or PR output is needed

## Read Anyway

Still run `SELECT VERSION()` when a connection is available and read the migration directory. Those two reads cost nothing and prevent the largest category of wrong-version DDL.

Tests that run against MySQL instead of TiDB pass DDL that TiDB rejects. That is not a convention question; say so when you see it.
