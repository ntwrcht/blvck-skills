# Serverless Driver

`@tidbcloud/serverless` talks to TiDB Cloud Starter and Essential over HTTP, so it runs where TCP sockets do not: Vercel Edge, Cloudflare Workers, Netlify Edge, Deno, Bun, and short-lived serverless functions. Use it only in those runtimes; a Node server with TCP should use `mysql2`.

## Gate

- Starter or Essential cluster. Dedicated and self-managed do not expose the HTTP endpoint.
- Connection string from the console **Connect** dialog with **Serverless Driver** selected.
- Backend code only. Browser origins are blocked by CORS.

## Use

```bash
npm install @tidbcloud/serverless
```

```ts
import { connect } from '@tidbcloud/serverless'

const conn = connect({ url: process.env.DATABASE_URL })          // mysql://user:pass@host/db
const rows = await conn.execute('SELECT * FROM test WHERE id = ?', [1])

const tx = await conn.begin()                                     // transactions are experimental
try {
  await tx.execute('INSERT INTO test VALUES (1)')
  await tx.commit()
} catch (err) {
  await tx.rollback()
  throw err
}
```

Runtime entry points:

```ts
// Next.js route on the Edge runtime
export const runtime = 'edge'
export async function GET() {
  const conn = connect({ url: process.env.DATABASE_URL })
  return Response.json(await conn.execute('SHOW TABLES'))
}

// Cloudflare Worker
export default { async fetch(req: Request, env: { DATABASE_URL: string }) {
  const conn = connect({ url: env.DATABASE_URL })
  return Response.json(await conn.execute('SHOW TABLES'))
} }
```

Deno imports from `npm:@tidbcloud/serverless`; Netlify Edge from `https://esm.sh/@tidbcloud/serverless`.

## Options

Connection level: `url`, `fetch` (custom fetch, e.g. `undici`), `arrayMode`, `fullResult`, `decoders`. Statement level overrides the same, plus `isolation: 'READ COMMITTED' | 'REPEATABLE READ'` on `begin()`.

## Type mapping

| TiDB type | JavaScript |
|---|---|
| `INT`, `FLOAT`, `DOUBLE` | `number` |
| `BIGINT`, `DECIMAL` | `string` |
| `JSON` | `object` |
| `DATETIME`, `TIMESTAMP`, `DATE`, `TIME` | `string` |
| Binary, blob, bit | `Uint8Array` |

`BIGINT` arriving as a string is the right default for `AUTO_RANDOM` IDs.

## Limits

- 10 000 rows per query. Paginate with keyset conditions.
- One statement per `execute`.
- No private endpoints.
- Percent-encode special characters in the URL password.
- Each call is an HTTP round trip and costs Request Units; batch reads where possible.

## With Kysely, Prisma, Drizzle

`@tidbcloud/kysely` provides `TiDBServerlessDialect`; `@tidbcloud/prisma-adapter` and the Drizzle `tidb-serverless` driver wrap the same HTTP connection. See `references/kysely.md` and `references/prisma.md`.
