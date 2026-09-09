# Transactions

TiDB offers two transaction modes. MySQL and InnoDB users expect pessimistic behaviour, and pessimistic is the TiDB default since v3.0.8, so most applications never notice. The differences that bite are commit-time conflicts under optimistic mode, transaction size limits, and isolation-level naming.

## Choose a mode

| Mode | Locks | Conflict surfaces | Use when |
|---|---|---|---|
| Pessimistic (default) | Row locks taken at DML time, like InnoDB | At the conflicting statement, as a lock wait or deadlock | Conflicts are common, or the application cannot safely retry a whole transaction |
| Optimistic | No locks until `COMMIT` | At `COMMIT`, as a write-conflict error | Write-write conflicts are rare and the application retries the whole transaction |

Set the cluster default:

```sql
SET GLOBAL tidb_txn_mode = 'pessimistic';
```

Force a mode for one transaction:

```sql
BEGIN PESSIMISTIC;
-- DML
COMMIT;

BEGIN OPTIMISTIC;
-- DML
COMMIT;
```

## Optimistic mode contract

Under optimistic mode `COMMIT` can fail with a write conflict. Any code path that opens an optimistic transaction owns a retry loop that re-runs the whole transaction, and every statement inside must be idempotent under retry. Generating optimistic SQL without stating this contract to the caller is a bug.

## Isolation

TiDB implements snapshot isolation and reports it as `REPEATABLE READ`. `READ COMMITTED` is available in pessimistic mode only (v4.0+); in optimistic mode it is silently ignored. `SERIALIZABLE` and `READ UNCOMMITTED` are not supported: setting one returns error 8048 unless `tidb_skip_isolation_level_check = 1`, which downgrades it to a warning while the isolation stays snapshot. Frameworks that set `SERIALIZABLE` on connect need that variable.

## Size limits

- A single transaction is bounded by `txn-total-size-limit` (default 100 MiB, maximum 1 TB). From v6.5.0 the default is superseded by session memory accounting under `tidb_mem_quota_query` (default 1 GB); a non-default `txn-total-size-limit` still applies. Bulk loads and mass deletes that fit in one InnoDB transaction can exceed either bound. `tidb_dml_type = 'bulk'` (v8.0+) lifts the size limit for large single-statement DML.
- Batch large writes: chunk by primary key range, commit per chunk, and make each chunk idempotent.
- For deletes by age, prefer a TTL attribute on the table (`TTL = created_at + INTERVAL 90 DAY`) over a nightly `DELETE`. TiDB expires rows in the background. See `references/schema-design.md`.

## Deadlocks and lock waits

Pessimistic mode detects deadlocks and aborts one transaction with error 1213, the same code as MySQL. Lock wait timeout is `innodb_lock_wait_timeout` (default 50 s) and surfaces as error 1205. Retry on 1213 the same way MySQL code does.

## Error codes worth handling

| Code | Meaning | Action |
|---|---|---|
| 1213 | Deadlock (pessimistic) | Retry the transaction |
| 1205 | Lock wait timeout | Retry with backoff, or shorten the transaction |
| 8005, 9007 | Write conflict (optimistic) | Retry the whole transaction |
| 8022 | Commit failed and rolled back | Retry the whole transaction |
| 8028 | Schema changed during the transaction | Retry; rare since metadata locks became default in v6.5.0 |
| 8048 | Unsupported isolation level | Set `tidb_skip_isolation_level_check`, or stop requesting `SERIALIZABLE` |
| 9006 | GC life time shorter than transaction duration | Break the transaction up, or raise `tidb_gc_life_time` |

## Gotchas

- Autocommit is on by default, same as MySQL.
- `SELECT ... FOR UPDATE` takes pessimistic locks only in pessimistic mode. In optimistic mode it records the read for conflict checking at commit.
- Long-running transactions and garbage collection: a transaction older than `tidb_gc_life_time` (default 10 minutes) can fail with error 9006, and GC waits for it at most `tidb_gc_max_wait_time` (default 24 h). Pessimistic transactions are also capped by `max-txn-ttl` (default 1 hour). Break long work into shorter transactions.
- TiDB does not auto-retry optimistic transactions since v8.0.0; the application owns the retry.
