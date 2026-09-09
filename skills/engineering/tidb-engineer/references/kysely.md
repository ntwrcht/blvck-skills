# Kysely

Kysely is a typed SQL builder with no migration opinion, so it fits TiDB with the standard `MysqlDialect` over a `mysql2` pool. Only serverless and edge runtimes need the HTTP dialect.

## Node server (default)

```bash
npm install kysely mysql2
```

```ts
import { Kysely, MysqlDialect } from 'kysely'
import { createPool } from 'mysql2'

interface Database {
  players: { id: string; name: string; coins: number; created_at: Date }
}

const pool = createPool({
  uri: process.env.DATABASE_URL,
  ssl: { minVersion: 'TLSv1.2', rejectUnauthorized: true },
  connectionLimit: 10,
  idleTimeout: 300_000,
  supportBigNumbers: true,
  bigNumberStrings: true,
})

export const db = new Kysely<Database>({ dialect: new MysqlDialect({ pool }) })

const players = await db.selectFrom('players').selectAll().where('coins', '>', 100).execute()
await db.destroy()
```

Type `BIGINT` primary keys as `string` in the `Database` interface when `bigNumberStrings` is on; `AUTO_RANDOM` IDs exceed the safe integer range.

## Serverless and edge

```bash
npm install kysely @tidbcloud/kysely @tidbcloud/serverless
```

```ts
import { Kysely } from 'kysely'
import { TiDBServerlessDialect } from '@tidbcloud/kysely'

export const db = new Kysely<Database>({
  dialect: new TiDBServerlessDialect({ url: process.env.DATABASE_URL }),
})
```

Starter and Essential only, backend only, 10 000 rows per query. See `references/serverless-driver.md`.

## TiDB notes

- `insertId` from `executeTakeFirst()` on an insert is a `bigint`; convert deliberately.
- Kysely's `sql` template tag is parameterised; use it for TiDB-only syntax such as hints: `` sql`/*+ USE_INDEX(p, idx_name) */` ``.
- Migrations through `kysely`'s `Migrator` run plain SQL; keep one change per `ALTER TABLE` and see `references/schema-design.md` for DDL rules.
- `DATABASE_URL` needs percent-encoded passwords.
