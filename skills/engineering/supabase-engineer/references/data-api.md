# Data API

`supabase-js` wraps PostgREST. Every call becomes an HTTP request against a table or view, filtered further by RLS.

---

## Select

```ts
const { data, error } = await supabase
  .from('posts')
  .select('id, title, created_at')      // name the columns; '*' over-fetches
  .eq('published', true)
  .order('created_at', { ascending: false })
  .limit(20)
```

Errors are **returned, not thrown**. A call without an `error` check silently produces `null` data:

```ts
const { data, error } = await supabase.from('posts').select()
if (error) throw error      // or handle — see references/error-handling.md
```

### Single rows

```ts
.single()        // exactly one row; errors (PGRST116) on 0 or 2+
.maybeSingle()   // 0 or 1 row; returns null rather than erroring on 0
```

Use `maybeSingle()` for lookups that may legitimately miss. `single()` turning a normal miss into an error is a common source of noisy logs.

---

## Filters

```ts
.eq('status', 'active')
.neq('status', 'archived')
.gt('score', 10)          .gte('score', 10)
.lt('score', 100)         .lte('score', 100)
.like('title', '%draft%')  .ilike('title', '%draft%')   // ilike = case-insensitive
.is('deleted_at', null)                                  // null needs .is, not .eq
.in('status', ['active', 'pending'])
.contains('tags', ['postgres'])        // array/jsonb containment
.containedBy('tags', ['a', 'b'])
.overlaps('tags', ['a', 'b'])
.rangeGt('period', '[2026-01-01,2026-02-01)')
.textSearch('body', 'postgres & database')
.not('status', 'eq', 'archived')
.or('status.eq.active,priority.gte.5')
```

`.eq('col', null)` does not work — SQL `= null` is never true. Use `.is('col', null)`.

Never build `.or()` or `.filter()` strings from user input; they take raw PostgREST syntax. Use typed filters instead.

---

## Embedded Resources

Foreign keys let you nest related rows in one round trip:

```ts
const { data } = await supabase
  .from('posts')
  .select(`
    id, title,
    author:profiles ( id, username, avatar_url ),
    comments ( id, body, created_at )
  `)
```

```ts
// Filter on the embedded table, and drop parents with no match
.select('*, comments!inner(*)')
.eq('comments.approved', true)

// Aggregate instead of fetching rows
.select('id, title, comments(count)')

// Disambiguate when two FKs point at the same table
.select('*, author:profiles!posts_author_id_fkey(*)')
```

Embedding is the fix for the N+1 pattern of fetching posts then looping to fetch each author. RLS applies to embedded tables too — a nested resource with no read policy comes back empty rather than erroring, which looks like missing data.

---

## Pagination

```ts
// Offset — simple, degrades on deep pages
const { data, count } = await supabase
  .from('posts')
  .select('*', { count: 'exact' })
  .range(0, 19)

// Keyset — stable and fast at any depth
const { data } = await supabase
  .from('posts')
  .select('*')
  .order('created_at', { ascending: false })
  .lt('created_at', cursor)
  .limit(20)
```

`count: 'exact'` runs a full count on every request. Use `'planned'` or `'estimated'` on large tables, or drop the count and use keyset pagination.

Offset pagination also skips and repeats rows when the underlying data changes between pages. Keyset does not.

---

## Insert, Update, Upsert, Delete

```ts
// Insert — returns nothing unless you ask
const { data, error } = await supabase
  .from('posts')
  .insert({ title, body, author_id: userId })
  .select()
  .single()

// Bulk insert
await supabase.from('posts').insert([{ … }, { … }])

// Update — a missing filter updates every row the policy allows
await supabase.from('posts').update({ title }).eq('id', postId).select()

// Upsert
await supabase
  .from('profiles')
  .upsert({ id: userId, username }, { onConflict: 'id' })

// Delete
await supabase.from('posts').delete().eq('id', postId)
```

Two things that bite:

- **`.select()` is required** to get rows back. Without it `data` is `null` even on success.
- **A filterless `update` or `delete` applies to everything RLS permits.** There is no confirmation step. Always filter, and let the policy be the backstop rather than the plan.

Insert does not report rows blocked by RLS as an error in bulk mode — check the returned count.

---

## RPC

For anything multi-statement, transactional, or too complex for the query builder:

```ts
const { data, error } = await supabase.rpc('transfer_credits', {
  from_user: userId,
  to_user: recipientId,
  amount: 100,
})
```

PostgREST has no client-side transaction API. Multiple `supabase.from(...)` calls are separate requests and separate transactions — if the second fails, the first is already committed. Anything needing atomicity belongs in a database function. See `references/database-functions.md`.

---

## Typed Results

```ts
import type { Database, Tables } from '@/lib/database.types'

type Post = Tables<'posts'>

// Infer the shape of an embedded query
import type { QueryData } from '@supabase/supabase-js'

const postsQuery = supabase.from('posts').select('id, title, author:profiles(username)')
type PostsWithAuthor = QueryData<typeof postsQuery>

const { data } = await postsQuery   // data is PostsWithAuthor | null
```

`QueryData` derives the exact nested shape, including which embeds are arrays versus objects — worth using rather than hand-writing the type of a joined result.

See `references/type-generation.md`.

---

## Query Patterns

```ts
// Parallel independent queries
const [posts, tags] = await Promise.all([
  supabase.from('posts').select().eq('published', true),
  supabase.from('tags').select(),
])

// Full-text search
await supabase.from('posts').select().textSearch('fts', query, {
  type: 'websearch',
  config: 'english',
})

// Case-insensitive partial match on a large table needs a trigram index
await supabase.from('posts').select().ilike('title', `%${term}%`)

// Non-default schema (must be exposed first)
await supabase.schema('analytics').from('events').select()

// Abort a slow query
const controller = new AbortController()
await supabase.from('posts').select().abortSignal(controller.signal)
```

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| `data` is `null` after a successful insert | Missing `.select()` |
| Empty array, no error | RLS denial — not an empty table |
| `PGRST116` | `.single()` matched 0 or 2+ rows; use `.maybeSingle()` |
| Every row updated | `update` without a filter |
| Embedded resource always empty | No read policy on the embedded table |
| `.eq('col', null)` matches nothing | Use `.is('col', null)` |
| Slow deep pagination | Offset paging — switch to keyset |
| Count query dominates response time | `count: 'exact'` on a large table |
| Partial writes after a failure | Multiple calls are separate transactions — use an RPC |
| `PGRST200` on an embed | No foreign key between the tables |
| Errors silently ignored | `error` never checked — it is returned, not thrown |
