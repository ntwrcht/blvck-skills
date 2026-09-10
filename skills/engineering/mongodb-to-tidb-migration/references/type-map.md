# Type Map

BSON types and the TiDB column each one lands in. Sample the real values before choosing widths: `scripts/infer-schema.js` reports the maximum string length, array cardinality, and type mix per field path.

| BSON type | TiDB column | Notes |
|---|---|---|
| `ObjectId` | `CHAR(24) CHARACTER SET ascii COLLATE ascii_bin`, or `BINARY(12)` | Hex keeps URLs, logs, and client code unchanged; binary halves index width. Time-prefixed, so see the Keys section of `references/pattern-map.md` before making it a clustered primary key |
| `Date` | `DATETIME(3)` | BSON dates are UTC milliseconds; `DATETIME` stores exactly what it is given with no session time-zone conversion, and it does not stop at 2038 as `TIMESTAMP` does. Write UTC, convert in the application |
| `String` | `VARCHAR(n)` sized from the sampled maximum with headroom; `TEXT` or `MEDIUMTEXT` past a few thousand characters | TiDB's default collation is `utf8mb4_bin`, which matches MongoDB's default binary comparison. A field the application compares case-insensitively (collation option, `$regex` with `i`) gets a case-insensitive collation on the column; check `SHOW COLLATION` on the target |
| `Int32` | `INT` | |
| `Int64` / `Long` | `BIGINT` | JavaScript drivers return `BIGINT` as a string or `BigInt` above 2^53; `tidb-engineer` has the driver settings |
| `Double` | `DOUBLE` | A double that is really money in disguise becomes `DECIMAL`; sample for fractional digits |
| `Decimal128` | `DECIMAL(p, s)` | 34 significant digits fit in `DECIMAL`'s 65; pick `s` from the sampled values and the domain, and refuse to silently narrow |
| `Boolean` | `BOOLEAN` | |
| `Binary` subtype 0 | `VARBINARY(n)` or `BLOB` | Large binaries belong in object storage with a key column, not in the row |
| `Binary` subtype 4 (UUID) | `BINARY(16)` | Or `CHAR(36)` when humans read it; `BIN_TO_UUID` and `UUID_TO_BIN` are available |
| `Array` | Child table or `JSON` | `references/pattern-map.md`, The Three Landing Shapes |
| `Object` | Columns or `JSON` | Same section |
| `Null` and missing field | Nullable column | SQL merges "absent" and "null" into one `NULL`. When the application distinguishes them, keep the field inside a `JSON` column, which preserves both |
| `Timestamp` (internal oplog type) | `BIGINT` or drop | Rarely application data |
| `Regex`, `JavaScript`, `MinKey`, `MaxKey`, `Symbol` | No column | Move behaviour to the application; report any occurrence in the plan |
| `DBRef` | Two columns: `ref_collection`, `ref_id` | Or a proper foreign key column when the target is always one table |

## Enumerations

A string field with a small fixed set of values (`status`, `tier`) becomes `ENUM` when the set is genuinely closed and `VARCHAR(16)` when the application adds values. Adding an `ENUM` value is an `ALTER TABLE ... MODIFY COLUMN` that TiDB executes without rewriting rows when the new value is appended at the end.

## Field Names

MongoDB field names are case-sensitive camelCase; SQL identifiers on TiDB are case-insensitive for column names. Convert to snake_case once, in the transform, and record the mapping in the plan so the applier and the application agree. A field name that collides with a reserved word (`order`, `group`, `key`) gets a suffix rather than a lifetime of backticks.

## Row Width

Wide documents flattened into one row hit limits before the storage does: 1017 columns per table by default, 64 indexes, and 6 MiB per row entry. A field set that would push a row past these belongs in `JSON` or in a child table.
