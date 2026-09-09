-- collect-diag.sql
-- Baseline metadata for a TiDB tuning session. Read-only.
-- Usage: mysql --ssl-mode=VERIFY_IDENTITY -h HOST -P 4000 -u USER -p DB < collect-diag.sql

-- 1. Version, transaction mode, analyze coverage
SELECT tidb_version()\G
SELECT @@tidb_txn_mode AS txn_mode, @@tidb_analyze_column_options AS analyze_columns, @@tidb_cost_model_version AS cost_model;

-- 2. TiFlash replicas (empty means no columnar storage)
SELECT table_schema, table_name, replica_count, available FROM information_schema.tiflash_replica;

-- 3. Slow queries in the last hour
SELECT query, query_time, process_time, wait_time, mem_max, plan_digest, is_internal
FROM information_schema.slow_query
WHERE time > NOW() - INTERVAL 1 HOUR
ORDER BY query_time DESC
LIMIT 10;

-- 4. Heaviest statements by total latency
SELECT digest_text, sum_latency, avg_latency, exec_count, avg_mem, avg_processed_keys, avg_total_keys
FROM information_schema.statements_summary
WHERE digest_text IS NOT NULL
ORDER BY sum_latency DESC
LIMIT 10;

-- 5. Active connections
SELECT user, host, db, command, time, state, info
FROM information_schema.processlist
WHERE command != 'Sleep'
ORDER BY time DESC;

-- 6. Hot regions
SELECT db_name, table_name, type, flow_bytes, max_hot_degree
FROM information_schema.tidb_hot_regions
ORDER BY flow_bytes DESC
LIMIT 5;

-- 7. Plan bindings already in force
SHOW GLOBAL BINDINGS;

-- 8. Statistics health
SHOW STATS_HEALTHY;

-- 9. Running or recent analyze jobs
SHOW ANALYZE STATUS;
