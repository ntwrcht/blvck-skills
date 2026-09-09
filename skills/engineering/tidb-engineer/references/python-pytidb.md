# Python with pytidb

`pytidb` is PingCAP's Python client on top of SQLAlchemy: table models, CRUD, raw SQL, and first-class vector, full-text, and hybrid search. For plain relational work SQLAlchemy with `PyMySQL` or `mysqlclient` is equally fine; pytidb earns its place when search or embeddings are involved.

## Rules

- Credentials from `.env`; never in code.
- Leave `pytidb` unpinned unless the user asks and the version is verified to exist.
- Parameterised SQL for every dynamic value.
- Interactive environments re-run cells; use `extend_existing=True`, `create_table(..., if_exists="skip")`, or `open_table`.

## Setup

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install pytidb python-dotenv
```

```bash
# .env
TIDB_HOST=gateway01.ap-southeast-1.prod.aws.tidbcloud.com
TIDB_PORT=4000
TIDB_USERNAME=PREFIX.root
TIDB_PASSWORD=...
TIDB_DATABASE=app
# or: TIDB_DATABASE_URL=mysql+pymysql://PREFIX.root:PASS@HOST:4000/app?ssl_verify_cert=true&ssl_verify_identity=true
```

## Connect and model

```python
import os, dotenv
from pytidb import TiDBClient
from pytidb.schema import TableModel, Field, VectorField, FullTextField
from pytidb.datatype import JSON, TEXT

dotenv.load_dotenv()
db = TiDBClient.connect(
    host=os.getenv("TIDB_HOST"), port=int(os.getenv("TIDB_PORT", "4000")),
    username=os.getenv("TIDB_USERNAME"), password=os.getenv("TIDB_PASSWORD"),
    database=os.getenv("TIDB_DATABASE"), ensure_db=True,
)
print(db.query("SELECT VERSION()").scalar())

class Item(TableModel):
    __tablename__ = "items"
    __table_args__ = {"extend_existing": True}
    id: int = Field(primary_key=True)
    content: str = Field(sa_type=TEXT)
    title: str = FullTextField()
    embedding: list[float] = VectorField(dimensions=1536)
    meta: dict = Field(sa_type=JSON, default_factory=dict)

table = db.create_table(schema=Item, if_exists="skip")
```

## CRUD

```python
table.insert(Item(id=1, content="TiDB is a distributed SQL database", title="TiDB", embedding=[...], meta={"k": "v"}))
table.bulk_insert([...])
rows = table.query(filters={"meta.k": "v"}, limit=10).to_pydantic()
table.update(values={"content": "..."}, filters={"id": 1})
table.delete(filters={"id": 2})
table.rows()
db.query("SELECT COUNT(*) FROM items WHERE id > :n", {"n": 0}).scalar()
```

## Search

| Kind | Column | Call |
|---|---|---|
| Vector | `VectorField(dimensions=D)`, optionally auto-embedded | `table.search(query_vector_or_text).limit(k)` |
| Full-text | `FullTextField()` | `table.search("keywords", search_type="fulltext").limit(k)` |
| Hybrid | both | `table.search(text, search_type="hybrid").limit(k)` with RRF or weighted fusion |

Auto embedding: declare an `EmbeddingFunction` (OpenAI, Jina, Bedrock, or a custom `BaseEmbeddingFunction`) and pass it as `VectorField(source_field="content", embed_fn=...)`; pytidb embeds on insert and on query. Dimension mismatches between the model and `VectorField(dimensions=...)` are the most common failure. Vector search with filters trades recall for speed; adjust `num_candidate` and choose pre- or post-filtering deliberately. Full-text index creation failing means the cluster or region does not offer it; see `references/full-text-search.md`.

## Plain SQLAlchemy

```python
from sqlalchemy import create_engine, text
engine = create_engine(os.environ["TIDB_DATABASE_URL"], pool_recycle=280, pool_pre_ping=True)
with engine.begin() as conn:
    conn.execute(text("INSERT INTO players (name) VALUES (:n)"), {"n": "alice"})
```

`pool_recycle` below 300 seconds matches the TiDB Cloud idle disconnect. Alembic migrations run MySQL DDL; review generated `ALTER TABLE` statements against `references/schema-design.md`.

## Smoke test

```bash
python -c "from pytidb import TiDBClient;import os;print(TiDBClient.connect(database_url=os.environ['TIDB_DATABASE_URL']).query('SELECT 1').scalar())"
```
