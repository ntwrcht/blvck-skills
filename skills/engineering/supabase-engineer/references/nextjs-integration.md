# Next.js Integration

The pieces: a browser client, a per-request server client, and a proxy that refreshes the session cookie. Without the third, Server Components see expired sessions.

For Next.js concerns themselves — routing, caching, rendering — see the `next-engineer` skill. This file covers only the Supabase seam.

---

## File Layout

```
lib/supabase/
  client.ts      createBrowserClient
  server.ts      createServerClient, per request
  proxy.ts       session refresh helper
  admin.ts       secret key, server-only
proxy.ts         Next 16+  (middleware.ts in Next 15 and earlier)
```

See `references/client-setup.md` for `client.ts`, `server.ts`, and `admin.ts`.

---

## Session Refresh

Server Components cannot write cookies, so the refreshed token has to be written somewhere that can. That is the proxy's job.

```ts
// lib/supabase/proxy.ts
import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          response = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  // Refreshes the token. Do not remove — Server Components depend on it.
  const { data } = await supabase.auth.getClaims()

  if (!data?.claims && !request.nextUrl.pathname.startsWith('/login')) {
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    return NextResponse.redirect(url)
  }

  return response
}
```

```ts
// proxy.ts  (Next 16+; middleware.ts with `export function middleware` before that)
import { type NextRequest } from 'next/server'
import { updateSession } from '@/lib/supabase/proxy'

export async function proxy(request: NextRequest) {
  return await updateSession(request)
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|webp)$).*)'],
}
```

Two details that break this if changed:

- **`setAll` must rebuild the response.** Returning a `NextResponse` created before the cookies were set drops them, and the session silently fails to persist.
- **The `getClaims()` call is the refresh.** Removing it as "unused" is the single most common way this setup breaks — sessions work for an hour, then log users out.

The redirect here is an optimistic check. It improves UX; it is not the security boundary. RLS is.

---

## Server Components

```tsx
// app/dashboard/page.tsx
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function Dashboard() {
  const supabase = await createClient()

  const { data: claims } = await supabase.auth.getClaims()
  if (!claims?.claims) redirect('/login')

  const { data: posts, error } = await supabase
    .from('posts')
    .select('id, title, created_at')
    .order('created_at', { ascending: false })

  if (error) throw error

  return <PostList posts={posts} />
}
```

The client is created per request. A module-level one shares a session across users.

---

## Server Actions

```ts
'use server'
import { createClient } from '@/lib/supabase/server'
import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'

export async function createPost(prevState: State, formData: FormData): Promise<State> {
  const supabase = await createClient()

  const { data: claims } = await supabase.auth.getClaims()
  if (!claims?.claims) return { message: 'You must be signed in.' }

  const parsed = PostSchema.safeParse(Object.fromEntries(formData))
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors }

  const { data: post, error } = await supabase
    .from('posts')
    .insert({ ...parsed.data, author_id: claims.claims.sub })
    .select('id')
    .single()

  if (error) {
    console.error('createPost', error)
    return { message: 'Could not create the post.' }
  }

  revalidatePath('/posts')
  redirect(`/posts/${post.id}`)      // outside the try — redirect() throws internally
}
```

A Server Action is a public endpoint. Verify the session in its body even though the proxy already redirected — the proxy does not run for direct action invocations.

Setting `author_id` from the verified claim rather than the form is what stops a user from posting as someone else. RLS `with check` is the backstop.

---

## Caching

Supabase queries in Server Components are uncached by default in Next 15+, which is usually right for user-scoped data.

```ts
// Per-user data — never cache across users
const { data } = await supabase.from('orders').select()

// Shared, non-user-scoped data — safe to cache
export async function getPublicPosts() {
  'use cache'                        // Next 16 Cache Components
  cacheLife('hours')
  cacheTag('posts')
  const supabase = await createClient()
  return supabase.from('posts').select().eq('published', true)
}
```

**Never cache a query whose result depends on the session.** RLS scopes rows to the caller, so a cached result is one user's rows served to the next. If the query goes through the user's client, it is user-scoped by definition.

For cacheable public data, query with a client built from the publishable key and no cookies, so there is no session to leak.

Invalidate after mutations with `revalidateTag` / `updateTag`.

---

## Route Handlers

```ts
// app/api/posts/route.ts
import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function GET() {
  const supabase = await createClient()
  const { data: claims } = await supabase.auth.getClaims()
  if (!claims?.claims) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { data, error } = await supabase.from('posts').select()
  if (error) return NextResponse.json({ error: 'Query failed' }, { status: 500 })

  return NextResponse.json(data)
}
```

Reach for a route handler when the caller is not your React tree — webhooks, mobile clients, OAuth callbacks. For your own UI, a Server Component read or a Server Action write is fewer moving parts.

---

## Realtime in Client Components

```tsx
'use client'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'

export function LivePosts({ initial }: { initial: Post[] }) {
  const [posts, setPosts] = useState(initial)      // seeded from the server

  useEffect(() => {
    const supabase = createClient()
    const channel = supabase
      .channel('posts-changes')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'posts' },
        payload => setPosts(prev => [payload.new as Post, ...prev]))
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [])

  return <PostList posts={posts} />
}
```

Seed from a Server Component so the first paint has data, then subscribe for updates. Always remove the channel on unmount — leaked subscriptions accumulate across navigations and hit the connection limit.

---

## Environment Variables

```bash
NEXT_PUBLIC_SUPABASE_URL=https://xyz.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_…
SUPABASE_SECRET_KEY=sb_secret_…          # no NEXT_PUBLIC_, ever
```

`NEXT_PUBLIC_` values are inlined at build time and permanently public.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Users logged out after ~1 hour | `getClaims()` removed from the proxy |
| Session lost on navigation | `setAll` not rebuilding the response object |
| `Auth session missing` in a Server Component | No proxy, or the matcher excludes the route |
| Users see each other's data | Module-level server client, or a cached user-scoped query |
| Cookie errors in a Server Component | Expected — `setAll` catch is correct when a proxy handles the write |
| Server Action bypasses auth | Session only checked in the proxy |
| Realtime stops after a few navigations | Channels not removed on unmount |
| Secret key in the bundle | `NEXT_PUBLIC_` prefix, or missing `server-only` |
| Stale data after a mutation | No `revalidatePath` / `revalidateTag` |
