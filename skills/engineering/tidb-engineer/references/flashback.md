# Flashback

Recover from an accidental `DROP` or `TRUNCATE`, or roll a whole cluster back to a point in time. Every form is bounded by garbage collection: once the GC safe point passes the moment of the mistake, the history is gone. Default `tidb_gc_life_time` is 10 minutes, so act first and explain later.

## Before recovering

1. Confirm TiDB: `SELECT VERSION();`
2. Check the GC safe point:

```sql
SELECT * FROM mysql.tidb WHERE variable_name = 'tikv_gc_safe_point';
```

If the mistake happened before the safe point, flashback cannot reach it. Restore from backup instead.

To buy time during an incident, extend the window (returns the space cost later):

```sql
SET GLOBAL tidb_gc_life_time = '24h';
```

## FLASHBACK TABLE (v4.0+)

Recover a dropped table:

```sql
FLASHBACK TABLE t;
```

After `TRUNCATE` the name still exists, so recover under a new name:

```sql
FLASHBACK TABLE t TO t_recovered;
```

The restored table reuses the original table ID, so the same drop can be recovered only once.

## FLASHBACK DATABASE (v6.4.0+)

```sql
FLASHBACK DATABASE test;
FLASHBACK DATABASE test TO test_recovered;
```

Same rule: each dropped database is recoverable once.

## FLASHBACK CLUSTER TO TIMESTAMP / TSO

Rolls every table in the cluster back to a point in time. High impact.

Gates:

- Not available on TiDB Cloud Starter, Essential, or Premium.
- Requires `SUPER`.
- Must be within GC lifetime, and the timestamp must be in the past.
- TiDB disconnects related sessions and blocks reads and writes while it runs. It cannot be cancelled.
- It writes the old versions forward under a new timestamp rather than deleting current data, so it needs storage headroom.
- TiCDC does not replicate the metadata rollback. Pause changefeeds first and reconcile downstream schemas after.

```sql
FLASHBACK CLUSTER TO TIMESTAMP '2026-09-01 16:02:50';
FLASHBACK CLUSTER TO TSO 445494839813079041;
SELECT @@tidb_current_ts;   -- capture a TSO before risky work
```

## Reading history without rolling back

`AS OF TIMESTAMP` (Stale Read, v5.1.0+) reads a past snapshot without changing anything, and is often enough to repair a bad `UPDATE`:

```sql
SELECT * FROM orders AS OF TIMESTAMP '2026-09-01 16:00:00' WHERE id = 42;
INSERT INTO orders_repair SELECT * FROM orders AS OF TIMESTAMP '2026-09-01 16:00:00' WHERE status = 'corrupted';
```
