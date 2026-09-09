# Node.js Drivers

Two packages are easy to confuse. `mysql2` (`npm i mysql2`) has a promise API, prepared statements, and is the one to use. `mysql` (mysqljs, `npm i mysql`) is callback-based and legacy; keep it only where it already exists. For application code prefer an ORM or query builder on top of `mysql2`: `references/prisma.md`, `references/kysely.md`. For serverless and edge runtimes that cannot hold TCP, use `references/serverless-driver.md`.

## Rules

- Credentials from `DATABASE_URL` or `TIDB_*` environment variables, never in code.
- `mysql2/promise` with `?` placeholders through `execute()`; string-built SQL is a defect.
- A pool for any long-lived process; `await pool.end()` on shutdown.
- Against TiDB Cloud: TLS on, `idleTimeout` at or below 300 000 ms, keepalive on, small `connectionLimit` in serverless.
- `multipleStatements: true` only when the user needs it and understands the injection surface.
- Port is 4000, not 3306.

## Connect

```js
import { createPool } from 'mysql2/promise'
import fs from 'node:fs'

export const pool = createPool({
  uri: process.env.DATABASE_URL,             // mysql://PREFIX.USER:PASS@HOST:4000/DB
  ssl: { minVersion: 'TLSv1.2', rejectUnauthorized: true,
         ca: process.env.TIDB_CA_PATH ? fs.readFileSync(process.env.TIDB_CA_PATH) : undefined },
  connectionLimit: Number(process.env.TIDB_CONNECTION_LIMIT ?? 10),
  maxIdle: Number(process.env.TIDB_MAX_IDLE ?? 2),
  idleTimeout: 300_000,
  enableKeepAlive: true,
})

const [[row]] = await pool.query('SELECT VERSION() AS v')
console.log(row.v)            // contains "TiDB"
```

Option-style config (`host`, `port`, `user`, `password`, `database`) works the same; URL form is easier to deploy.

## Query, insert, transact

```js
const [rows] = await pool.execute('SELECT id, coins FROM players WHERE id = ?', [id])

const [result] = await pool.execute('INSERT INTO players (coins, goods) VALUES (?, ?)', [100, 100])
result.insertId                // works with AUTO_RANDOM and AUTO_INCREMENT alike

const conn = await pool.getConnection()
try {
  await conn.beginTransaction()
  await conn.execute('UPDATE players SET coins = coins - ? WHERE id = ?', [50, from])
  await conn.execute('UPDATE players SET coins = coins + ? WHERE id = ?', [50, to])
  await conn.commit()
} catch (e) {
  await conn.rollback()
  throw e
} finally {
  conn.release()
}
```

## TiDB specifics

- `BIGINT` values above 2^53 lose precision as JavaScript numbers. `AUTO_RANDOM` IDs are `BIGINT` with high bits set, so pass `supportBigNumbers: true` (the official guide's recommendation) plus `bigNumberStrings: true` and treat IDs as strings.
- `insertId` on a batch `INSERT` is the first generated ID only, and with `AUTO_RANDOM` the rest are not consecutive. Read them back with a `SELECT` when you need them.
- Optimistic transactions surface conflicts at `commit()`. Wrap the whole transaction in a retry loop when `tidb_txn_mode` is optimistic; see `references/transactions.md`.
- Retry on error 1213 (deadlock) and on 8028 (schema changed during transaction), both of which are transient.

## mysqljs (`mysql`) legacy

Callback API; wrap with `util.promisify` or a small Promise helper. TLS config is the same `ssl` object. Migrate to `mysql2` when touching the file for any other reason; the APIs are close enough that a rename plus `await` is most of the work.

## Smoke test

```bash
node -e "import('mysql2/promise').then(async m=>{const c=await m.createConnection({uri:process.env.DATABASE_URL,ssl:{rejectUnauthorized:true}});console.log((await c.query('SELECT VERSION() v'))[0][0].v);await c.end()})"
```
