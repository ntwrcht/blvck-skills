# Vector Search

TiDB stores embeddings in a `VECTOR` column, ranks with distance functions, and accelerates top-K queries with an HNSW index on TiFlash. On TiDB Cloud Starter it can also compute the embeddings itself.

## Feature gate

Vector types and functions need TiDB v8.4.0+ (v8.5.0+ recommended) and are still marked experimental in v8.5. Vector indexes need TiFlash and support only cosine and L2 distance. Confirm both before generating DDL:

```sql
SELECT VERSION();
SELECT * FROM information_schema.tiflash_replica LIMIT 1;   -- errors or empty means no TiFlash yet
```

## Types

| Type | Index-able | Use |
|---|---|---|
| `VECTOR` | No | Mixed dimensions, prototypes |
| `VECTOR(D)` | Yes | Production; `D` must equal the model's output dimension |

```sql
CREATE TABLE embedded_documents (
  id BIGINT PRIMARY KEY AUTO_RANDOM,
  document TEXT,
  embedding VECTOR(1536)
);
INSERT INTO embedded_documents (document, embedding) VALUES ('dog', '[0.1, 0.2, ...]');
```

Vector literals are strings. Cast explicitly when comparing constants: `VEC_FROM_TEXT('[...]')`, `CAST('[...]' AS VECTOR)`, and `VEC_AS_TEXT(vec)` for the reverse.

## Distance functions

`VEC_COSINE_DISTANCE`, `VEC_L2_DISTANCE`, `VEC_L1_DISTANCE`, `VEC_NEGATIVE_INNER_PRODUCT`. Pick one per column and use the same one in the index and in every query.

Exact scan:

```sql
SELECT id, document, VEC_COSINE_DISTANCE(embedding, '[...]') AS distance
FROM embedded_documents
ORDER BY distance
LIMIT 10;
```

## HNSW index

Constraints: single vector column, cannot be `PRIMARY KEY` or `UNIQUE`, needs a TiFlash replica, and the index distance function must match the query's.

```sql
-- at creation
CREATE TABLE foo (
  id BIGINT PRIMARY KEY AUTO_RANDOM,
  embedding VECTOR(1536),
  VECTOR INDEX idx_embedding ((VEC_COSINE_DISTANCE(embedding)))
);

-- on an existing table
ALTER TABLE foo SET TIFLASH REPLICA 1;
CREATE VECTOR INDEX idx_embedding ON foo ((VEC_COSINE_DISTANCE(embedding))) USING HNSW;
```

The index is used only for `ORDER BY <same distance function>(col, const) ASC LIMIT K`. Descending order, a missing `LIMIT`, or a different function falls back to an exact scan. Verify:

```sql
EXPLAIN SELECT * FROM foo ORDER BY VEC_COSINE_DISTANCE(embedding, '[...]') LIMIT 10;
SHOW WARNINGS;
```

Look for `annIndex:` in the operator info. Filtering plus ANN is a tradeoff: a `WHERE` clause is applied after the top-K candidates are fetched unless the filter is on a partition key, so raise `LIMIT` or pre-partition when recall drops.

## Auto embedding (TiDB Cloud Starter)

TiDB can compute embeddings in SQL, so the application stores text only.

Probe first:

```sql
SELECT EMBED_TEXT("tidbcloud_free/amazon/titan-embed-text-v2", "pingcap");
```

Then store a generated column and query in natural language:

```sql
CREATE TABLE docs_auto_embed (
  id BIGINT PRIMARY KEY AUTO_RANDOM,
  content TEXT NOT NULL,
  content_vec VECTOR(1024) GENERATED ALWAYS AS (
    EMBED_TEXT("tidbcloud_free/amazon/titan-embed-text-v2", content)
  ) STORED
);

SELECT id, content
FROM docs_auto_embed
ORDER BY VEC_EMBED_COSINE_DISTANCE(content_vec, 'renewable energy for cities')
LIMIT 3;
```

Bring-your-own-key providers (OpenAI, Cohere, Gemini, Jina, Hugging Face, NVIDIA NIM) are enabled through global variables such as `TIDB_EXP_EMBED_OPENAI_API_KEY`. The `VECTOR(D)` dimension must match the model (Titan v2 offers 1024, 512, or 256). Auto embedding is available only on TiDB Cloud Starter instances hosted on AWS; the probe tells you.

## Design notes

- Store the model name beside the vector, or in the table comment. A model change means a re-embed of every row.
- Keep vectors out of hot OLTP tables when the row is otherwise small; a 1536-float column dominates row size.
- For hybrid ranking with keyword search, fuse in the application or use pytidb; see `references/full-text-search.md` and `references/python-pytidb.md`.
