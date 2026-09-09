# Prisma

Prisma treats TiDB as MySQL. That works for models, migrations, and the client, with a handful of TiDB-specific adjustments around IDs, TLS, and DDL that the MySQL provider generates.

## Datasource

```prisma
generator client { provider = "prisma-client-js" }
datasource db {
  provider = "mysql"
  url      = env("DATABASE_URL")
}
```

`DATABASE_URL` for TiDB Cloud:

```bash
DATABASE_URL='mysql://PREFIX.USER:PASSWORD@HOST:4000/DB?sslaccept=strict'                                # Starter, Essential
DATABASE_URL='mysql://PREFIX.USER:PASSWORD@HOST:4000/DB?sslaccept=strict&sslcert=/absolute/path/ca.pem'  # Dedicated
```

Add `&connection_limit=1` in serverless functions, and `&pool_timeout=` if cold starts queue.

## Install and migrate

```bash
npm i @prisma/client && npm i -D prisma
npx prisma init
npx prisma migrate dev --name init      # generates and applies SQL, regenerates the client
npx prisma generate
```

## Models on TiDB

```prisma
model Player {
  id        BigInt   @id @default(autoincrement()) @db.BigInt
  name      String   @unique(map: "uk_player_on_name") @db.VarChar(50)
  coins     Decimal  @default(0)
  createdAt DateTime @default(now()) @map("created_at")
  profile   Profile?
  @@map("players")
}
```

Prisma cannot express `AUTO_RANDOM`. For a write-heavy table either edit the generated migration SQL to `BIGINT PRIMARY KEY AUTO_RANDOM` before applying (Prisma tolerates the attribute on later diffs when the column stays `BigInt @id`), or generate IDs in the application with `@default(dbgenerated())` and a UUID or Snowflake. Record the choice in the migration file's comment.

Relations: Prisma emits `FOREIGN KEY` constraints by default. On TiDB below v6.6.0 they are parsed and ignored; on v6.6.0+ they are enforced and cost a lookup per write. Set `relationMode = "prisma"` in the datasource to keep integrity in the client and skip database constraints on hot tables.

## Generated DDL to review

`prisma migrate dev` produces MySQL DDL. Before applying against TiDB check for:

- Multi-change `ALTER TABLE` statements; split them.
- `ALGORITHM=` or `LOCK=` clauses; remove.
- `@db.Text` with a `@unique`; TiDB needs a prefix length, so use `@db.VarChar(n)`.
- Type changes that TiDB cannot do in place; write an expand-and-contract migration.

`prisma migrate diff --from-migrations --to-schema-datamodel --script` shows the SQL without applying it.

## Client

```ts
import { PrismaClient } from '@prisma/client'
const prisma = new PrismaClient()
const rows = await prisma.$queryRaw`SELECT VERSION() AS version`   // tagged template is parameterised
```

Singleton for hot-reloading frameworks: cache the client on `globalThis` in development; see `references/nextjs.md`. `$queryRawUnsafe` only with SQL you fully control.

`BigInt` columns come back as JavaScript `BigInt`; serialise with `.toString()` before `JSON.stringify`.

## Serverless and edge

`@tidbcloud/prisma-adapter` (community-maintained by TiDB Cloud; match its major.minor to your Prisma version) runs Prisma Client over the HTTP driver on Starter and Essential. TiDB's docs still show `previewFeatures = ["driverAdapters"]`, which Prisma made GA in 6.16.0. Migrations and introspection still go over TCP. Elsewhere keep Prisma in a Node runtime.

## Troubleshooting

| Symptom | Fix |
|---|---|
| TLS handshake error on a public endpoint | `sslaccept=strict` missing, or `sslcert` path unreadable |
| `Access denied` | Username lacks the cluster prefix |
| `Cannot find module '@prisma/client'` or stale types | `npx prisma generate` |
| Migration fails with "Unsupported modify column" | Split into add, backfill, swap, drop |
| Timeout from a serverless function | `connection_limit=1`, reuse the client across invocations |
