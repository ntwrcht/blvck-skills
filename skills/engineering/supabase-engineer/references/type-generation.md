# Type Generation

Types are generated from the live schema, not hand-written. A hand-written row interface drifts from the database and the drift is silent.

---

## Generating

```bash
# Local database
supabase gen types typescript --local > lib/database.types.ts

# Linked remote project
supabase gen types typescript --project-id "$PROJECT_REF" --schema public > lib/database.types.ts

# Direct connection (self-hosted)
supabase gen types typescript --db-url "$DATABASE_URL" --schema public > lib/database.types.ts

# Multiple schemas
supabase gen types typescript --local --schema public --schema analytics > lib/database.types.ts
```

```json
// package.json
{
  "scripts": {
    "db:types": "supabase gen types typescript --local > lib/database.types.ts",
    "db:reset": "supabase db reset && npm run db:types"
  }
}
```

Pairing reset with regeneration in one script is the habit that keeps them in sync. Regenerating is a step people forget after every schema change otherwise.

Commit the generated file. It makes schema changes visible in review — a PR that alters a column shows the type change in the diff.

---

## Typing the Client

```ts
import { createBrowserClient } from '@supabase/ssr'
import type { Database } from '@/lib/database.types'

export function createClient() {
  return createBrowserClient<Database>(url, key)
}
```

The generic propagates through everything: `from('posts')` autocompletes table names, `.select('id, title')` narrows the result to those columns, `.insert()` requires the non-defaulted columns, and a typo in a column name is a compile error.

Passing it once at client creation is all that is needed — do not annotate individual queries.

---

## Helper Types

```ts
import type { Tables, TablesInsert, TablesUpdate, Enums } from '@/lib/database.types'

type Post = Tables<'posts'>              // row shape
type NewPost = TablesInsert<'posts'>     // insert shape — defaults optional
type PostPatch = TablesUpdate<'posts'>   // update shape — all optional
type Status = Enums<'post_status'>       // 'draft' | 'published' | 'archived'
```

These three differ in ways that matter: `id` and `created_at` are required in `Tables` but optional in `TablesInsert` because the database supplies them. Using `Tables<'posts'>` as a function parameter for creation forces callers to invent values the database owns.

```ts
// ❌ Caller must fabricate an id and timestamp
async function createPost(post: Tables<'posts'>) { … }

// ✅
async function createPost(post: TablesInsert<'posts'>) { … }
```

---

## Query Result Types

Embedded selects produce nested shapes that are tedious to write by hand and easy to get wrong — particularly whether an embed is an object or an array.

```ts
import type { QueryData } from '@supabase/supabase-js'

const postsQuery = supabase
  .from('posts')
  .select(`
    id, title,
    author:profiles ( id, username ),
    comments ( id, body )
  `)

type PostsWithAuthor = QueryData<typeof postsQuery>

const { data, error } = await postsQuery
if (error) throw error
// data: PostsWithAuthor — author is an object, comments is an array
```

Define the query once and derive the type from it. If the select string changes, the type follows automatically.

For a single row:

```ts
type PostWithAuthor = QueryData<typeof postsQuery>[number]
```

---

## Function Return Types

```sql
-- ✅ Concrete row type
create function public.search_posts(term text)
returns setof public.posts …

-- ✅ Also typed
create function public.post_stats(post_id uuid)
returns table (views bigint, comments bigint) …

-- ❌ Generates `Json` — no safety
create function public.get_dashboard()
returns json …
```

```ts
const { data } = await supabase.rpc('search_posts', { term: 'postgres' })
// data: Tables<'posts'>[]
```

Argument names and types are generated too, so a mismatched RPC parameter is a compile error rather than a `PGRST202` at runtime.

---

## Non-Generated Types

```ts
// JSONB columns generate as `Json` — narrow them yourself
type PostMetadata = { readingTime: number; tags: string[] }

const metadata = post.metadata as PostMetadata     // validate before trusting
```

`Json` is as far as the generator can go for `jsonb`. Parse with a schema (Zod) rather than casting if the value comes from user input — a cast is a promise, not a check.

For a column with a database `check` constraint that is not an enum, the generator emits `string`. Consider an enum instead so the type carries the constraint.

---

## Keeping Types Current

The failure is always the same: someone changes the schema, forgets to regenerate, and TypeScript keeps validating against a schema that no longer exists.

```yaml
# CI — fail when the committed types are stale
- run: supabase start
- run: supabase db reset
- run: supabase gen types typescript --local > /tmp/types.ts
- run: |
    diff -u lib/database.types.ts /tmp/types.ts \
      || { echo "Generated types are out of date — run npm run db:types"; exit 1; }
```

This check is cheap and catches the mistake at PR time rather than in production.

A pre-commit hook works too, but CI is the one that cannot be skipped.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| No autocomplete on `from()` | `Database` generic not passed to the client |
| Types disagree with the database | Not regenerated after a migration |
| Insert demands `id` and `created_at` | Used `Tables<'…'>` instead of `TablesInsert<'…'>` |
| Embedded result typed as `any` | Query defined inline; use `QueryData<typeof query>` |
| RPC result is `Json` | Function returns `json` instead of `setof`/`table` |
| `PGRST202` at runtime | Types stale, so the argument mismatch was not caught |
| Types missing a schema's tables | `--schema` not passed for non-public schemas |
| Merge conflicts in the types file | Expected — regenerate rather than hand-resolving |
