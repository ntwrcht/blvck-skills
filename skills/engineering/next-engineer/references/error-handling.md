# Error Handling

Two categories, handled differently:

- **Expected errors** — validation failures, not-found, permission denied. Model these as return values or dedicated UI. They are data, not exceptions.
- **Unexpected errors** — bugs, network failures, downstream outages. These reach an error boundary.

Throwing for an expected failure is the most common mistake — it turns a form validation message into a full-page error screen.

---

## File Conventions

| File | Catches | Notes |
|---|---|---|
| `error.tsx` | Errors in the segment's `page` and children | Must be a Client Component. Does **not** catch errors in its own `layout`. |
| `global-error.tsx` | Errors in the root layout | Replaces the root layout, so it renders its own `<html>` and `<body>`. Production only. |
| `not-found.tsx` | `notFound()` and unmatched URLs | Server Component. |
| `forbidden.tsx` / `unauthorized.tsx` | `forbidden()` / `unauthorized()` | Experimental (`authInterrupts`). |

Because `error.tsx` cannot catch its own layout's errors, an error in `app/dashboard/layout.tsx` is handled by `app/error.tsx` one level up. Place boundaries with that in mind.

---

## `error.tsx`

```tsx
'use client'

import { useEffect } from 'react'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    reportError(error, { digest: error.digest })
  }, [error])

  return (
    <div role="alert">
      <h2>Something went wrong</h2>
      <p>We could not load this section. Try again, or come back shortly.</p>
      {error.digest && <p>Reference: {error.digest}</p>}
      <button onClick={reset}>Try again</button>
    </div>
  )
}
```

In production, `error.message` is redacted to a generic string and `error.digest` holds a hash correlating to the server log. Do not render `error.message` — in dev it is useful, in production it is empty or generic, and there is a real risk of leaking internals if the redaction is bypassed.

Showing the digest gives support a lookup key.

`reset()` re-renders the boundary's contents. It works when the cause was transient; if the underlying data is still broken, it fails again — pair it with a link out.

---

## `global-error.tsx`

```tsx
'use client'

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <html lang="en">
      <body>
        <h2>Something went wrong</h2>
        <button onClick={() => reset()}>Try again</button>
      </body>
    </html>
  )
}
```

Only active in production. Keep it dependency-free — it renders when the root layout has already failed, so anything it imports may fail too.

---

## `not-found.tsx`

```tsx
// app/products/[slug]/not-found.tsx
import Link from 'next/link'

export default function NotFound() {
  return (
    <div>
      <h2>Product not found</h2>
      <p>This product may have been removed.</p>
      <Link href="/products">Browse all products</Link>
    </div>
  )
}
```

```tsx
export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const product = await getProduct(slug)
  if (!product) notFound()          // throws; renders the nearest not-found.tsx with a 404
  return <ProductDetail product={product} />
}
```

`notFound()` throws. Call it outside a `try` whose `catch` would swallow it.

---

## Granular Boundaries

One root `error.tsx` turns any failure into a blank page. Put boundaries where a failure should be contained:

```tsx
export default function Dashboard() {
  return (
    <div className="grid gap-6">
      <ErrorBoundary fallback={<WidgetError name="Revenue" />}>
        <Suspense fallback={<WidgetSkeleton />}>
          <RevenueWidget />
        </Suspense>
      </ErrorBoundary>

      <ErrorBoundary fallback={<WidgetError name="Traffic" />}>
        <Suspense fallback={<WidgetSkeleton />}>
          <TrafficWidget />
        </Suspense>
      </ErrorBoundary>
    </div>
  )
}
```

A failing analytics widget should not take the revenue widget with it. `react-error-boundary` provides the component; segment-level `error.tsx` is the coarser tool.

---

## Expected Errors in Server Actions

```ts
'use server'
export async function createPost(prev: State, formData: FormData): Promise<State> {
  const session = await verifySession()

  const parsed = PostSchema.safeParse(Object.fromEntries(formData))
  if (!parsed.success) {
    return { errors: parsed.error.flatten().fieldErrors }        // expected → return
  }

  let post
  try {
    post = await db.post.create({ data: { ...parsed.data, authorId: session.userId } })
  } catch (error) {
    console.error('createPost failed', { error, userId: session.userId })
    return { message: 'Could not create the post. Please try again.' }   // expected → return
  }

  revalidateTag('posts')
  redirect(`/posts/${post.id}`)                                  // outside the try
}
```

The `catch` returns state rather than rethrowing, so the user stays on the form with their input intact and sees an inline message.

```tsx
'use client'
const [state, formAction, pending] = useActionState(createPost, {})

{state.message && <p role="alert">{state.message}</p>}
{state.errors?.title && <p role="alert">{state.errors.title[0]}</p>}
```

---

## Data-Fetch Failures

```tsx
async function Widget() {
  try {
    const data = await fetchExternalMetrics()
    return <Chart data={data} />
  } catch {
    return <WidgetUnavailable />      // degrade rather than fail the page
  }
}
```

For a non-critical third-party section, catching locally and degrading beats letting the error bubble to a boundary that blanks the region.

For critical data, let it throw and let the boundary handle it — a silently empty page is worse than an error message.

`Promise.allSettled` when independent fetches should not sink each other:

```tsx
const [user, posts, recs] = await Promise.allSettled([getUser(id), getPosts(id), getRecs(id)])

return (
  <>
    {user.status === 'fulfilled' ? <Profile user={user.value} /> : <ProfileError />}
    {posts.status === 'fulfilled' && <PostList posts={posts.value} />}
    {recs.status === 'fulfilled' && <Recs items={recs.value} />}
  </>
)
```

---

## Route Handlers

```ts
export async function POST(request: NextRequest) {
  try {
    const session = await verifySession()
    if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

    const parsed = Schema.safeParse(await request.json())
    if (!parsed.success) {
      return NextResponse.json(
        { error: 'Invalid request', details: parsed.error.flatten() },
        { status: 400 }
      )
    }

    return NextResponse.json(await createResource(parsed.data), { status: 201 })
  } catch (error) {
    console.error('POST /api/resources failed', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
```

Validation details are safe to return — they describe the caller's own input. Internal errors are not.

---

## Logging

```ts
// lib/logger.ts
import 'server-only'

export function logError(error: unknown, context: Record<string, unknown> = {}) {
  const payload = {
    message: error instanceof Error ? error.message : String(error),
    stack: error instanceof Error ? error.stack : undefined,
    ...context,
    timestamp: new Date().toISOString(),
  }
  if (process.env.NODE_ENV === 'production') {
    // Sentry.captureException(error, { extra: context })
  } else {
    console.error(payload)
  }
}
```

Log with context — user id, route, request id, and the `digest` when available. A stack trace with no context is a needle in a haystack.

Never log secrets, tokens, passwords, or full request bodies containing PII.

Use `after()` to ship logs without adding to response time:

```tsx
import { after } from 'next/server'
after(async () => { await shipLogs(entries) })
```

---

## Monitoring

```ts
// instrumentation.ts
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    await import('./instrumentation.node')
  }
}

export function onRequestError(err: unknown, request: Request, context: unknown) {
  // Reports server-side errors including those inside RSC rendering
}
```

`onRequestError` catches errors that never reach a client boundary — RSC render failures, Server Action throws.

Sentry's Next.js SDK wires client, server, and edge with source maps in one setup and is the usual choice.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Error page instead of an inline validation message | Threw for an expected error — return state instead |
| `error.tsx` not catching | Error originated in the same segment's `layout.tsx` |
| `error.message` empty in production | Redacted by design — use `digest` |
| Redirect silently ignored | `redirect()` inside a `try/catch` |
| Whole dashboard blanks on one widget failure | Only a root-level boundary; add granular ones |
| `global-error.tsx` never fires in dev | Production-only by design |
| Errors invisible in monitoring | No `onRequestError`, or logging without context |
| Sensitive data in logs | Whole request body or `process.env` logged |
