# Vector Search

`pgvector` stores embeddings in Postgres, so similarity search sits alongside relational data — one query can filter by tenant, date, and semantic similarity at once, under the same RLS policies.

---

## Setup

```sql
create extension if not exists vector with schema extensions;

create table public.documents (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations on delete cascade,
  content    text not null,
  metadata   jsonb not null default '{}',
  embedding  vector(1536),                  -- must match the model's dimensions
  created_at timestamptz not null default now()
);

alter table public.documents enable row level security;

create policy "org members read org documents"
on public.documents for select to authenticated
using ( org_id = any (select public.user_org_ids()) );

create index documents_org_id_idx on public.documents (org_id);
```

The dimension is fixed at column creation and must match the model exactly:

| Model | Dimensions |
|---|---|
| OpenAI `text-embedding-3-small` | 1536 |
| OpenAI `text-embedding-3-large` | 3072 |
| Cohere `embed-english-v3.0` | 1024 |
| `gte-small` (Supabase built-in) | 384 |

Changing models means a new column and a re-embed of the whole corpus. Pick deliberately.

---

## Indexes

```sql
-- HNSW — better recall and speed, slower to build, more memory. Default choice.
create index documents_embedding_hnsw
on public.documents using hnsw (embedding vector_cosine_ops)
with (m = 16, ef_construction = 64);

-- IVFFlat — faster build, less memory, needs data present before creation
create index documents_embedding_ivfflat
on public.documents using ivfflat (embedding vector_cosine_ops)
with (lists = 100);                          -- ≈ rows/1000, capped around sqrt(rows)
```

| | HNSW | IVFFlat |
|---|---|---|
| Build time | Slow | Fast |
| Query speed | Faster | Slower |
| Recall | Higher | Lower |
| Needs existing data | No | **Yes** |
| Memory | Higher | Lower |

Prefer HNSW unless build time or memory is the binding constraint.

**IVFFlat built on an empty table produces garbage results** — it clusters on the data present at build time. Load first, then index, and rebuild after large ingests.

Match the operator class to the distance function you query with, or the index is ignored:

| Operator | Distance | Operator class |
|---|---|---|
| `<=>` | Cosine | `vector_cosine_ops` |
| `<->` | L2 / Euclidean | `vector_l2_ops` |
| `<#>` | Inner product | `vector_ip_ops` |

Most text embedding models are normalized, making cosine the right default.

---

## Matching Function

The client cannot express `<=>`, so wrap the search in a function.

```sql
create or replace function public.match_documents(
  query_embedding vector(1536),
  match_threshold float default 0.7,
  match_count     int   default 10,
  filter_org_id   uuid  default null
)
returns table (id uuid, content text, metadata jsonb, similarity float)
language sql
stable
security invoker                              -- RLS still applies
set search_path = ''
as $$
  select
    d.id,
    d.content,
    d.metadata,
    1 - (d.embedding <=> query_embedding) as similarity
  from public.documents d
  where d.embedding is not null
    and (filter_org_id is null or d.org_id = filter_org_id)
    and 1 - (d.embedding <=> query_embedding) > match_threshold
  order by d.embedding <=> query_embedding      -- order by distance, not similarity
  limit match_count;
$$;
```

```ts
const { data } = await supabase.rpc('match_documents', {
  query_embedding: embedding,
  match_threshold: 0.75,
  match_count: 5,
  filter_org_id: orgId,
})
```

Two details decide whether the index is used:

- **`order by embedding <=> query_embedding`**, ascending distance. Ordering by the computed `similarity` descending is mathematically equivalent but the planner cannot use the index for it.
- **`security invoker`** keeps RLS in force, so a user cannot search another tenant's documents even if they pass a different `filter_org_id`.

---

## Generating Embeddings

```ts
// Edge Function — keeps the API key server-side
import { withSupabase } from 'npm:@supabase/server'
import OpenAI from 'npm:openai'

const openai = new OpenAI({ apiKey: Deno.env.get('OPENAI_API_KEY') })

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    const { content, orgId } = await req.json()

    const { data: [{ embedding }] } = await openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: content.replace(/\n/g, ' '),
    })

    const { error } = await ctx.supabase
      .from('documents')
      .insert({ content, org_id: orgId, embedding })

    if (error) return Response.json({ error: 'insert failed' }, { status: 500 })
    return Response.json({ ok: true })
  }),
}
```

Embed queries with the **same model** used for documents. Mixing models produces vectors in different spaces and silently meaningless results — no error, just bad ranking.

Batch ingestion:

```ts
const { data } = await openai.embeddings.create({
  model: 'text-embedding-3-small',
  input: chunks,                    // array — one request for many chunks
})
await supabaseAdmin.from('documents').insert(
  chunks.map((content, i) => ({ content, org_id: orgId, embedding: data[i].embedding }))
)
```

---

## Chunking

Retrieval quality depends more on chunking than on index tuning.

- 200–500 tokens per chunk for prose; respect natural boundaries (headings, paragraphs).
- 10–20% overlap so a sentence spanning a boundary is not orphaned.
- Store `source_id`, `chunk_index`, and a heading path in `metadata` so results can be cited and neighbours fetched.
- Prepend the document title or section heading to each chunk before embedding — it gives short chunks context.

```sql
alter table public.documents add column source_id uuid references public.sources on delete cascade;
alter table public.documents add column chunk_index int;
create index documents_source_idx on public.documents (source_id, chunk_index);
```

The `on delete cascade` matters: re-ingesting a source should replace its chunks, not accumulate them.

---

## Hybrid Search

Semantic search misses exact terms — product codes, error strings, names. Combining it with full-text search fixes that.

```sql
alter table public.documents
  add column fts tsvector generated always as (to_tsvector('english', content)) stored;
create index documents_fts_idx on public.documents using gin (fts);
```

```sql
create or replace function public.hybrid_search(
  query_text      text,
  query_embedding vector(1536),
  match_count     int default 10,
  rrf_k           int default 50
)
returns setof public.documents
language sql
stable
set search_path = ''
as $$
with semantic as (
  select id, row_number() over (order by embedding <=> query_embedding) as rank
  from public.documents
  where embedding is not null
  order by embedding <=> query_embedding
  limit match_count * 2
),
keyword as (
  select id, row_number() over (order by ts_rank_cd(fts, websearch_to_tsquery(query_text)) desc) as rank
  from public.documents
  where fts @@ websearch_to_tsquery(query_text)
  limit match_count * 2
)
select d.*
from public.documents d
join (
  select coalesce(s.id, k.id) as id,
         coalesce(1.0 / (rrf_k + s.rank), 0) + coalesce(1.0 / (rrf_k + k.rank), 0) as score
  from semantic s
  full outer join keyword k on k.id = s.id
) fused on fused.id = d.id
order by fused.score desc
limit match_count;
$$;
```

Reciprocal Rank Fusion combines rankings without needing the two scores to be on comparable scales — which they are not.

---

## Storage and Cost

A 1536-dimension `vector` is about 6 KB per row before indexing. A million documents is several GB plus index.

Options when that bites:

- `halfvec(1536)` — half precision, roughly half the storage, minor recall loss.
- Matryoshka models (`text-embedding-3-*`) support truncation to fewer dimensions with graceful degradation.
- Binary quantization for very large corpora.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Results are nonsense | Query and documents embedded with different models |
| Index ignored, query slow | `order by` on computed similarity instead of the distance operator |
| Index ignored despite correct order | Operator class does not match the operator used |
| IVFFlat returns poor matches | Built on an empty or much smaller table — rebuild |
| Dimension mismatch error | Column dimension differs from the model output |
| Users search other tenants' documents | Function is `security definer`, or no RLS on the table |
| Exact terms never found | Semantic-only search — add hybrid |
| Duplicate chunks after re-ingest | No cascade delete on `source_id` |
| Short chunks retrieve poorly | No heading or title context prepended |
| Storage cost unexpectedly high | Full-precision vectors where `halfvec` would do |
