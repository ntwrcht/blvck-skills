# Observability

Supabase surfaces most of what you need without setup — the advisors and the log explorer answer more questions faster than adding instrumentation.

---

## Advisors

Dashboard → Advisors. Check these before hand-analyzing anything.

**Security Advisor**

| Finding | Why it matters |
|---|---|
| Table without RLS in an exposed schema | World-readable via the publishable key |
| `security definer` view | Bypasses RLS for every caller |
| Function with a mutable `search_path` | Privilege-escalation path |
| Exposed `auth` schema | Leaks user records |
| Leaked-password protection disabled | Credential stuffing |

**Performance Advisor**

| Finding | Fix |
|---|---|
| Unindexed foreign key | `create index` on the FK column |
| Unused index | Drop it — it costs write throughput |
| RLS policy with unwrapped `auth.uid()` | Wrap in `(select …)` |
| Multiple permissive policies for one role and action | Consolidate; each is evaluated |
| Duplicate index | Drop the redundant one |

The security findings are the ones to gate a release on. Every item is a real exposure, not a style preference.

---

## Logs

Dashboard → Logs, or the log explorer for SQL over log data.

| Source | Contains |
|---|---|
| API (PostgREST) | Every data API request, status, duration |
| Postgres | Query errors, slow queries, connection events |
| Auth | Sign-in, sign-up, token refresh, failures |
| Storage | Object operations |
| Edge Functions | `console` output, uncaught errors |
| Realtime | Connections, subscriptions, disconnects |

```sql
-- Failing API requests in the last hour
select
  cast(timestamp as datetime) as ts,
  status_code,
  path,
  event_message
from edge_logs
cross join unnest(metadata) as m
cross join unnest(m.response) as response
cross join unnest(m.request) as request
where status_code >= 400
order by timestamp desc
limit 100;
```

A spike in `401`s usually means session refresh broke. A spike in `403`/empty results means a policy changed.

---

## Slow Queries

```sql
create extension if not exists pg_stat_statements;

select
  calls,
  round(total_exec_time::numeric, 2) as total_ms,
  round(mean_exec_time::numeric, 2)  as mean_ms,
  round((100 * total_exec_time / sum(total_exec_time) over ())::numeric, 2) as pct_total,
  query
from pg_stat_statements
order by total_exec_time desc
limit 20;
```

Sort by `total_exec_time`. A 5 ms query called a million times outranks a 2 s report run twice daily, and only one is worth attention.

```sql
select pg_stat_statements_reset();     -- after a fix, to measure the effect
```

Reproduce with RLS in force, or the plan will not match production:

```sql
set local role authenticated;
set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}';
explain (analyze, buffers) select * from public.posts;
```

---

## Connections

```sql
select
  count(*) filter (where state = 'active')             as active,
  count(*) filter (where state = 'idle')               as idle,
  count(*) filter (where state = 'idle in transaction') as idle_in_txn,
  count(*)                                              as total
from pg_stat_activity;

-- Long-running queries
select pid, now() - query_start as duration, state, left(query, 120) as query
from pg_stat_activity
where state <> 'idle' and now() - query_start > interval '30 seconds'
order by duration desc;
```

`idle in transaction` connections hold locks and block vacuum. A rising count means a code path opens a transaction and does slow work — usually an HTTP call — before committing.

---

## Table Health

```sql
-- Size
select
  relname,
  pg_size_pretty(pg_total_relation_size(c.oid)) as total,
  pg_size_pretty(pg_relation_size(c.oid))       as table_only
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by pg_total_relation_size(c.oid) desc
limit 20;

-- Dead tuples and vacuum lag
select relname, n_live_tup, n_dead_tup, last_autovacuum, last_autoanalyze
from pg_stat_user_tables
where n_dead_tup > 10000
order by n_dead_tup desc;
```

High `n_dead_tup` with a stale `last_autovacuum` means autovacuum cannot keep up — queries slow down as the planner works from stale statistics.

---

## Application Instrumentation

```ts
export async function tracedQuery<T>(name: string, fn: () => Promise<T>) {
  const start = performance.now()
  try {
    return await fn()
  } finally {
    const ms = performance.now() - start
    if (ms > 500) console.warn('slow query', { name, ms: Math.round(ms) })
  }
}
```

```ts
// Log errors with context, never the whole row
if (error) {
  console.error('createPost failed', {
    code: error.code,
    details: error.details,
    userId: claims.sub,
  })
}
```

Log ids and error codes. A logged row can contain PII, and logs are retained and widely readable.

Never log the secret key, session tokens, or `process.env`.

---

## What to Alert On

| Signal | Threshold |
|---|---|
| API 5xx rate | Any sustained increase |
| API 401 rate | Spike — session refresh is broken |
| Database CPU | Sustained above ~70% |
| Connection count | Approaching the plan limit |
| Disk usage | Above ~80% — a full disk takes the project read-only |
| Queue depth / oldest message age | Growing — a consumer stopped |
| `cron.job_run_details` failures | Any |
| New Security Advisor finding | Any |

Disk is the one that causes outages rather than slowdowns: Postgres goes read-only when it fills, and recovery needs a resize.

---

## Metrics Endpoint

```
https://<ref>.supabase.co/customer/v1/privileged/metrics
```

Prometheus format, authenticated with the service role key. Scrape into Grafana or Datadog for retention beyond the dashboard's window and for alerting alongside the rest of your infrastructure.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Table exposed for months | Advisors never checked |
| Slow queries invisible | `pg_stat_statements` not enabled |
| Plans do not match production | `explain` run without impersonating a role |
| Spike in 401s | Session refresh broken — check the proxy |
| Connections exhausted | Direct connections from serverless, or `idle in transaction` |
| Queries slow with no query change | Autovacuum lag, stale statistics |
| Project goes read-only | Disk full |
| Scheduled job silently stopped | `cron.job_run_details` not monitored |
| PII in logs | Whole rows logged on error |
