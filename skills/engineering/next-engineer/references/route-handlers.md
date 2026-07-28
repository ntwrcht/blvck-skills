# Route Handlers

`route.ts` in an `app/` segment defines HTTP handlers using the Web `Request`/`Response` APIs.

A `route.ts` and a `page.tsx` cannot exist at the same path.

---

## Basic Shape

```ts
// app/api/products/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { verifySession } from '@/lib/dal'
import { z } from 'zod'

export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl
  const category = searchParams.get('category')
  const products = await db.product.findMany({
    where: category ? { category } : undefined,
  })
  return NextResponse.json(products)
}

const CreateBody = z.object({ name: z.string().min(1), price: z.number().positive() })

export async function POST(request: NextRequest) {
  const session = await verifySession()
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  if (session.role !== 'admin') return NextResponse.json({ error: 'Forbidden' }, { status: 403 })

  const parsed = CreateBody.safeParse(await request.json())
  if (!parsed.success) {
    return NextResponse.json({ errors: parsed.error.flatten() }, { status: 400 })
  }

  const product = await db.product.create({ data: parsed.data })
  return NextResponse.json(product, { status: 201 })
}
```

Supported exports: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`. Anything else returns 405 automatically.

---

## When to Use One

Server Actions cover most mutations from your own UI. Reach for a route handler when the caller is not your React tree:

| Use case | Why a handler |
|---|---|
| Webhooks (Stripe, GitHub, CMS) | External POST with its own signature scheme |
| Public or mobile API | Needs a stable URL and REST semantics |
| File download / streaming response | Full control over headers and body |
| OAuth callbacks | The provider redirects to a URL |
| Cron / scheduled jobs | Invoked by a scheduler over HTTP |
| Client-side data fetching (SWR, TanStack Query) | Those libraries fetch URLs |
| Image or PDF generation | Returns a binary body |

Building a `POST /api/todos` purely so your own form can call it is a step backwards — use an Action.

---

## Dynamic Segments

```ts
// app/api/products/[id]/route.ts
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params            // async in Next 15+
  const product = await db.product.findUnique({ where: { id } })
  if (!product) return NextResponse.json({ error: 'Not found' }, { status: 404 })
  return NextResponse.json(product)
}
```

---

## Reading the Request

```ts
const body   = await request.json()
const form   = await request.formData()
const text   = await request.text()
const buffer = await request.arrayBuffer()

const q      = request.nextUrl.searchParams.get('q')
const auth   = request.headers.get('authorization')
const token  = request.cookies.get('session')?.value
```

The body can only be consumed once. If you need the raw text for a signature check *and* the parsed object, read the text first and parse it yourself.

---

## Webhooks

```ts
// app/api/webhooks/stripe/route.ts
import Stripe from 'stripe'
import { headers } from 'next/headers'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

export async function POST(request: Request) {
  const body = await request.text()                       // raw text for signature verification
  const signature = (await headers()).get('stripe-signature')

  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(body, signature!, process.env.STRIPE_WEBHOOK_SECRET!)
  } catch (err) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 })
  }

  switch (event.type) {
    case 'checkout.session.completed':
      await fulfillOrder(event.data.object)
      break
  }

  return NextResponse.json({ received: true })
}
```

Rules that matter for webhooks specifically:

- Verify the signature against the **raw** body. Re-serializing parsed JSON changes bytes and breaks the HMAC.
- Return 2xx quickly. Providers retry on timeout, causing duplicate processing.
- Make handlers idempotent — key on the event id and skip ones already processed.
- Exclude webhook paths from proxy auth matchers, or your proxy will 302 the provider.
- Long work goes in a queue, or `after()` if it is short and non-critical.

---

## Streaming

```ts
export async function GET() {
  const encoder = new TextEncoder()
  const stream = new ReadableStream({
    async start(controller) {
      for await (const chunk of generateTokens()) {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(chunk)}\n\n`))
      }
      controller.close()
    },
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
    },
  })
}
```

`no-transform` matters — some proxies buffer streams without it. For LLM responses, the Vercel AI SDK's `toDataStreamResponse()` handles the wiring.

---

## Caching Behavior

GET handlers are **uncached by default** in Next 15+ (they were cached in Next 13/14). Opt in:

```ts
export const revalidate = 3600
export const dynamic = 'force-static'
```

Under Cache Components, GET handlers follow the same prerendering model as pages — use `'use cache'` inside the handler.

Anything reading `request`, `cookies()`, or `headers()` is dynamic regardless.

---

## Runtime

```ts
export const runtime = 'nodejs'    // default — full Node APIs, DB drivers
export const runtime = 'edge'      // Web APIs only, lower latency, no Node built-ins
```

Edge cannot use most database drivers, `fs`, or native modules. Choose it for lightweight, latency-sensitive work: geolocation, feature flags, redirect logic.

---

## CORS

```ts
export async function OPTIONS() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': process.env.ALLOWED_ORIGIN!,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400',
    },
  })
}
```

Reflecting `Access-Control-Allow-Origin: *` alongside `Allow-Credentials: true` is invalid and browsers reject it. Use an allowlist.

---

## Non-JSON Responses

```ts
// Redirect
return NextResponse.redirect(new URL('/login', request.url))

// File download
return new Response(fileBuffer, {
  headers: {
    'Content-Type': 'application/pdf',
    'Content-Disposition': 'attachment; filename="invoice.pdf"',
  },
})

// Set a cookie on the response
const response = NextResponse.json({ ok: true })
response.cookies.set('theme', 'dark', { httpOnly: true, secure: true, sameSite: 'lax', path: '/' })
return response
```

---

## Security Checklist

- Authenticate and authorize in the handler body — the URL is public.
- Validate the parsed body with a schema before touching the database.
- Rate-limit unauthenticated endpoints.
- Verify webhook signatures against the raw body.
- Never echo internal errors; log server-side and return a generic message.
- Scope queries to the session's user id rather than a client-supplied one.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| 405 on a valid request | Method not exported from `route.ts` |
| `params` is a Promise | Next 15+ — needs `await` |
| Handler and page conflict | `route.ts` and `page.tsx` at the same path |
| Webhook signature always fails | Body parsed as JSON before verification, or a proxy modified it |
| Response cached when it should not be | Next 13/14 cached GET by default — add `dynamic = 'force-dynamic'` |
| `Module not found: fs` | `runtime = 'edge'` with a Node-only dependency |
| Stream arrives all at once | Missing `no-transform`, or an intermediate proxy buffering |
| Duplicate webhook side effects | Provider retried; handler is not idempotent |
