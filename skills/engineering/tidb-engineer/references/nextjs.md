# Next.js

Database code in a Next.js App Router project runs in Route Handlers, Server Components, and Server Actions, on the Node.js runtime. The Edge runtime has no TCP, so a TCP driver there fails at import time. `next-engineer` owns routing, caching, and rendering; this file covers the TiDB half.

## Decisions

1. ORM or builder first: Prisma (`references/prisma.md`) or Kysely (`references/kysely.md`). Raw `mysql2` for minimal demos.
2. Node runtime for anything using a TCP driver: `export const runtime = 'nodejs'` in the route file.
3. Edge runtime only with the HTTP driver: `references/serverless-driver.md`.
4. Fresh data from the database means a dynamic route: `export const dynamic = 'force-dynamic'`, or `revalidate` where staleness is acceptable.

## Pool helper

```ts
// lib/tidb.ts
import 'server-only'
import fs from 'node:fs'
import { createPool, type Pool } from 'mysql2/promise'

type G = typeof globalThis & { __tidbPool?: Pool }

export function getPool(): Pool {
  const g = globalThis as G
  g.__tidbPool ??= createPool({
    uri: process.env.DATABASE_URL,
    ssl: { minVersion: 'TLSv1.2', rejectUnauthorized: true,
           ca: process.env.TIDB_CA_PATH ? fs.readFileSync(process.env.TIDB_CA_PATH) : undefined },
    connectionLimit: Number(process.env.TIDB_CONNECTION_LIMIT ?? 1),
    maxIdle: 1,
    idleTimeout: 300_000,
    enableKeepAlive: true,
    supportBigNumbers: true,
    bigNumberStrings: true,
  })
  return g.__tidbPool
}
```

`server-only` makes an accidental import from a Client Component a build error. Caching on `globalThis` survives dev hot reload and reuses the pool across warm serverless invocations; `connectionLimit: 1` per instance is enough on Vercel.

## Route Handler

```ts
// app/api/players/route.ts
import { NextResponse } from 'next/server'
import { getPool } from '@/lib/tidb'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

export async function GET() {
  const [rows] = await getPool().query('SELECT id, name, coins FROM players ORDER BY id LIMIT 50')
  return NextResponse.json(rows)
}
```

## Prisma singleton

```ts
// lib/prisma.ts
import 'server-only'
import { PrismaClient } from '@prisma/client'
type G = typeof globalThis & { __prisma?: PrismaClient }
export const prisma = (globalThis as G).__prisma ?? new PrismaClient()
if (process.env.NODE_ENV !== 'production') (globalThis as G).__prisma = prisma
```

## Environment

`DATABASE_URL`, `TIDB_CA_PATH` (Dedicated only). Never under a `NEXT_PUBLIC_` prefix. Set them in the hosting provider's environment, not only in `.env.local`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Module not found: Can't resolve 'net'` or `tls` | TCP driver imported on Edge | `runtime = 'nodejs'`, or the HTTP driver |
| Route returns stale rows | Static rendering cached the response | `dynamic = 'force-dynamic'` or a `revalidate` value |
| `Too many connections` on Starter | A pool per invocation | Cache on `globalThis`, `connectionLimit: 1` |
| Credentials visible in the browser bundle | `NEXT_PUBLIC_` prefix or a Client Component import | Rename the variable; add `server-only` |
| `BigInt` serialisation error in `NextResponse.json` | Raw `BigInt` from Prisma | `.toString()` or a JSON replacer |
