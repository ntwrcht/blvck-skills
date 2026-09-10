// infer-schema.js — sample a MongoDB collection and print the facts a migration plan needs.
//
// Usage (read-only; uses $sample, $collStats, getIndexes, $indexStats):
//   COLL=tickets SAMPLE=5000 mongosh "$MONGODB_URI" --quiet infer-schema.js > tickets.json
//
// Environment:
//   COLL           collection name (required)
//   DB             database name (default: the database in the URI)
//   SAMPLE         documents to sample (default 5000)
//   VERSION_FIELD  schema version field (default schemaVersion)
//   MAX_DEPTH      nesting depth to walk (default 6)
//
// Output: one JSON object with stats, docSize percentiles, versions, keySets, fields, indexes, hints.

const collName = process.env.COLL;
if (!collName) {
  print('Set COLL=<collection>');
  quit(1);
}
const dbh = process.env.DB ? db.getSiblingDB(process.env.DB) : db;
const sampleSize = parseInt(process.env.SAMPLE || '5000', 10);
const versionField = process.env.VERSION_FIELD || 'schemaVersion';
const maxDepth = parseInt(process.env.MAX_DEPTH || '6', 10);
const coll = dbh.getCollection(collName);
const ROW_ENTRY_LIMIT = 6 * 1024 * 1024; // TiDB txn-entry-size-limit default

function bsonType(v) {
  if (v === null || v === undefined) return 'null';
  if (Array.isArray(v)) return 'array';
  if (v instanceof ObjectId) return 'objectId';
  if (v instanceof Date) return 'date';
  if (typeof Decimal128 !== 'undefined' && v instanceof Decimal128) return 'decimal128';
  if (typeof Long !== 'undefined' && v instanceof Long) return 'long';
  if (typeof Int32 !== 'undefined' && v instanceof Int32) return 'int';
  if (typeof Double !== 'undefined' && v instanceof Double) return 'double';
  if (typeof Timestamp !== 'undefined' && v instanceof Timestamp) return 'timestamp';
  if (typeof Binary !== 'undefined' && v instanceof Binary) return v.sub_type === 4 ? 'uuid' : 'binData';
  if (typeof BSONRegExp !== 'undefined' && v instanceof BSONRegExp) return 'regex';
  if (v instanceof RegExp) return 'regex';
  const t = typeof v;
  if (t === 'number') return Number.isInteger(v) ? 'number(int|double)' : 'double';
  if (t === 'string') return 'string';
  if (t === 'boolean') return 'bool';
  if (t === 'object') return 'object';
  return t;
}

function percentile(sorted, p) {
  if (sorted.length === 0) return null;
  const idx = Math.min(sorted.length - 1, Math.floor(p * (sorted.length - 1)));
  return sorted[idx];
}

const fields = new Map();
let seenThisDoc;

function fieldEntry(path) {
  let f = fields.get(path);
  if (!f) {
    f = { docs: 0, occurrences: 0, types: {}, arrayLens: [], maxStrLen: 0 };
    fields.set(path, f);
  }
  return f;
}

function visit(path, v, depth) {
  const f = fieldEntry(path);
  f.occurrences++;
  if (!seenThisDoc.has(path)) {
    seenThisDoc.add(path);
    f.docs++;
  }
  const t = bsonType(v);
  f.types[t] = (f.types[t] || 0) + 1;
  if (t === 'string' && v.length > f.maxStrLen) f.maxStrLen = v.length;
  if (t === 'array') {
    f.arrayLens.push(v.length);
    if (depth < maxDepth) {
      // The first 50 elements are enough to learn element shape.
      v.slice(0, 50).forEach((e) => visit(path + '[]', e, depth + 1));
    }
  } else if (t === 'object' && depth < maxDepth) {
    for (const k of Object.keys(v)) visit(path ? path + '.' + k : k, v[k], depth + 1);
  }
}

// ── Collection stats ─────────────────────────────────────────────────────────
let stats = {};
try {
  const cs = coll.aggregate([{ $collStats: { storageStats: {} } }]).next();
  const s = cs.storageStats || {};
  stats = {
    count: s.count,
    avgObjSize: s.avgObjSize,
    dataSize: s.size,
    storageSize: s.storageSize,
    totalIndexSize: s.totalIndexSize,
    nindexes: s.nindexes,
  };
} catch (e) {
  stats = { error: String(e.message || e) };
}

// ── Sample walk ──────────────────────────────────────────────────────────────
const docSizes = [];
const keySets = new Map();
const versions = new Map();
let sampled = 0;

const cursor = coll.aggregate(
  [{ $sample: { size: sampleSize } }, { $addFields: { __bsonSize: { $bsonSize: '$$ROOT' } } }],
  { allowDiskUse: true }
);

while (cursor.hasNext()) {
  const doc = cursor.next();
  const size = doc.__bsonSize;
  delete doc.__bsonSize;
  docSizes.push(size);
  sampled++;

  const ks = Object.keys(doc).sort().join(',');
  keySets.set(ks, (keySets.get(ks) || 0) + 1);

  const ver = doc[versionField] === undefined ? '(missing)' : String(doc[versionField]);
  versions.set(ver, (versions.get(ver) || 0) + 1);

  seenThisDoc = new Set();
  for (const k of Object.keys(doc)) visit(k, doc[k], 1);
}

docSizes.sort((a, b) => a - b);

// ── Resolve int32 vs double ──────────────────────────────────────────────────
// mongosh unwraps int32 and double to plain JS numbers, so the walk cannot tell
// them apart. Ask the server with $type for each ambiguous non-array path.
const ambiguous = [...fields.entries()]
  .filter(([path, f]) => f.types['number(int|double)'] && !path.includes('[]'))
  .map(([path]) => path)
  .slice(0, 40);
for (const path of ambiguous) {
  try {
    const dist = {};
    coll
      .aggregate(
        [
          { $sample: { size: Math.min(sampleSize, 1000) } },
          { $match: { [path]: { $type: 'number' } } },
          { $group: { _id: { $type: '$' + path }, n: { $sum: 1 } } },
        ],
        { allowDiskUse: true }
      )
      .forEach((r) => {
        dist[r._id] = r.n;
      });
    const f = fields.get(path);
    const ambiguousCount = f.types['number(int|double)'];
    delete f.types['number(int|double)'];
    const total = Object.values(dist).reduce((a, b) => a + b, 0) || 1;
    for (const [t, n] of Object.entries(dist)) {
      f.types[t] = (f.types[t] || 0) + Math.round((ambiguousCount * n) / total);
    }
  } catch (e) {
    // Leave the ambiguous label in place when the probe fails.
  }
}

// ── Indexes ──────────────────────────────────────────────────────────────────
let indexes = [];
try {
  const usage = new Map();
  try {
    coll.aggregate([{ $indexStats: {} }]).forEach((i) => usage.set(i.name, i.accesses ? i.accesses.ops : null));
  } catch (e) {
    // $indexStats needs a privilege the user may not have; report indexes without usage.
  }
  indexes = coll.getIndexes().map((i) => ({
    name: i.name,
    key: i.key,
    unique: !!i.unique,
    sparse: !!i.sparse,
    partial: !!i.partialFilterExpression,
    ttlSeconds: i.expireAfterSeconds === undefined ? null : i.expireAfterSeconds,
    ops: usage.has(i.name) ? Number(usage.get(i.name)) : null,
  }));
} catch (e) {
  indexes = [{ error: String(e.message || e) }];
}

// ── Assemble ─────────────────────────────────────────────────────────────────
const fieldRows = [];
const hints = [];

for (const [path, f] of [...fields.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
  const row = {
    path,
    docsPct: Math.round((f.docs / sampled) * 1000) / 10,
    types: f.types,
  };
  if (f.maxStrLen) row.maxStrLen = f.maxStrLen;
  if (f.arrayLens.length) {
    const lens = f.arrayLens.slice().sort((a, b) => a - b);
    row.arrayLen = { p50: percentile(lens, 0.5), p95: percentile(lens, 0.95), max: lens[lens.length - 1] };
    if (row.arrayLen.max > 100 || row.arrayLen.p95 > 50) {
      hints.push(`${path}: array p95=${row.arrayLen.p95} max=${row.arrayLen.max}; child-table candidate`);
    }
  }
  const typeNames = Object.keys(f.types).filter((t) => t !== 'null');
  if (typeNames.length > 1) hints.push(`${path}: mixed types ${typeNames.join('|')}`);
  if (row.docsPct < 100 && !path.includes('[]')) row.optional = true;
  if (f.maxStrLen > 1000) hints.push(`${path}: strings up to ${f.maxStrLen} chars; TEXT rather than VARCHAR`);
  fieldRows.push(row);
}

for (const i of indexes) {
  if (i.ttlSeconds !== null && i.ttlSeconds !== undefined) {
    hints.push(`index ${i.name}: TTL ${i.ttlSeconds}s on ${Object.keys(i.key)[0]}; TiDB TTL attribute candidate`);
  }
  if (i.ops === 0 && i.name !== '_id_' && (i.ttlSeconds === null || i.ttlSeconds === undefined)) hints.push(`index ${i.name}: zero accesses since restart; do not port without a query that needs it`);
}
if (keySets.size > 1) hints.push(`${keySets.size} distinct top-level key sets in the sample; schema drift, see keySets`);
if (versions.size > 1) hints.push(`${versions.size} distinct ${versionField} values; transform must converge them`);
const oversize = docSizes.filter((s) => s > ROW_ENTRY_LIMIT).length;
if (oversize) hints.push(`${oversize} sampled documents exceed 6 MiB; they cannot land whole in one TiDB row`);
if (stats.count && sampled < stats.count && sampled / stats.count < 0.001) {
  hints.push(`sample is ${(100 * sampled / stats.count).toFixed(3)}% of the collection; rare shapes may be missing`);
}

const out = {
  collection: `${dbh.getName()}.${collName}`,
  sampledAt: new Date().toISOString(),
  stats,
  sampled,
  docSize: {
    p50: percentile(docSizes, 0.5),
    p95: percentile(docSizes, 0.95),
    p99: percentile(docSizes, 0.99),
    max: docSizes[docSizes.length - 1] || null,
  },
  versions: Object.fromEntries([...versions.entries()].sort((a, b) => b[1] - a[1])),
  keySets: [...keySets.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([keys, n]) => ({ n, keys })),
  fields: fieldRows,
  indexes,
  hints,
};

print(JSON.stringify(out, null, 2));
