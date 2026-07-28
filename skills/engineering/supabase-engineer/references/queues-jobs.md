# Queues, Scheduling, and Background Work

The rule underneath everything here: **triggers run inside the writing transaction**. Anything slow or fallible in a trigger — an HTTP call, an email, an LLM request — slows every write and can fail it. Enqueue instead.

---

## Choosing

| Need | Tool |
|---|---|
| Run SQL on a schedule | `pg_cron` |
| Call an Edge Function on a schedule | `pg_cron` + `pg_net` |
| React to a row change, asynchronously | Database Webhooks, or a trigger enqueueing work |
| Reliable work queue with retries | `pgmq` |
| Fire-and-forget HTTP from SQL | `pg_net` |
| Long-running or CPU-heavy work | Edge Function invoked from a queue consumer |

---

## `pg_cron`

```sql
create extension if not exists pg_cron with schema extensions;
```

```sql
-- Nightly cleanup
select cron.schedule(
  'purge-expired-sessions',
  '0 3 * * *',
  $$ delete from public.sessions where expires_at < now() $$
);

-- Every five minutes
select cron.schedule('refresh-stats', '*/5 * * * *',
  $$ refresh materialized view concurrently public.daily_stats $$);

-- Sub-minute
select cron.schedule('drain-queue', '10 seconds', $$ select public.process_jobs() $$);

select * from cron.job;
select cron.unschedule('purge-expired-sessions');
```

Job history:

```sql
select jobid, runid, status, return_message, start_time, end_time
from cron.job_run_details
order by start_time desc
limit 20;
```

Check this table when a scheduled job "isn't running" — failures are recorded here, not raised anywhere visible.

`cron.job_run_details` grows without bound. Schedule its own cleanup:

```sql
select cron.schedule('trim-cron-history', '0 4 * * *',
  $$ delete from cron.job_run_details where end_time < now() - interval '7 days' $$);
```

Jobs run as the user who scheduled them, bypassing RLS. Keep the SQL narrow.

---

## Calling an Edge Function on a Schedule

```sql
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'send-digest',
  '0 9 * * 1',
  $$
  select net.http_post(
    url     := 'https://<ref>.supabase.co/functions/v1/send-digest',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || vault.read_secret('edge_secret_key')
    ),
    body    := '{}'::jsonb,
    timeout_milliseconds := 5000
  );
  $$
);
```

`net.http_post` is **asynchronous** — it queues the request and returns an id immediately. It never returns the response, and a failure is invisible unless you look:

```sql
select id, status_code, error_msg, created
from net._http_response
order by created desc
limit 20;
```

Never write code that assumes `net.http_post` completed successfully.

Read the key from Vault rather than embedding it in the job definition, which is world-readable via `cron.job`.

---

## `pgmq`

For work needing retries, visibility timeouts, and a dead-letter path, a real queue beats a status column.

```sql
create extension if not exists pgmq;
select pgmq.create('email_jobs');
```

```sql
-- Enqueue from a trigger — cheap, stays inside the transaction safely
create or replace function public.enqueue_welcome_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pgmq.send('email_jobs', jsonb_build_object('user_id', new.id, 'email', new.email));
  return new;
end;
$$;

create trigger profiles_welcome_email
after insert on public.profiles
for each row execute function public.enqueue_welcome_email();
```

Enqueueing is a local insert, so it is transactional with the write that caused it — if the insert rolls back, so does the job. That is the property an HTTP call in a trigger cannot give you.

```sql
-- Consume
create or replace function public.process_email_jobs()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  msg record;
  processed int := 0;
begin
  for msg in select * from pgmq.read('email_jobs', 30, 10) loop   -- 30s visibility, 10 msgs
    begin
      perform net.http_post(
        url     := 'https://<ref>.supabase.co/functions/v1/send-email',
        headers := jsonb_build_object('Content-Type','application/json',
                                      'Authorization','Bearer ' || vault.read_secret('edge_secret_key')),
        body    := msg.message
      );
      perform pgmq.delete('email_jobs', msg.msg_id);
      processed := processed + 1;
    exception when others then
      if msg.read_ct >= 5 then
        perform pgmq.archive('email_jobs', msg.msg_id);          -- dead letter
      end if;
      -- otherwise leave it; visibility timeout returns it to the queue
    end;
  end loop;
  return processed;
end;
$$;

select cron.schedule('drain-emails', '30 seconds', $$ select public.process_email_jobs() $$);
```

`pgmq.read` hides messages for the visibility timeout, so concurrent consumers do not double-process. Deleting only after success gives at-least-once delivery — make the handler idempotent.

`read_ct` is the retry counter; archive past a threshold rather than retrying forever.

---

## Database Webhooks

Configured in the dashboard: a row change POSTs to a URL. Convenient, but it is `pg_net` under the hood — asynchronous, unretried, and invisible on failure.

Use them for low-stakes notifications. For anything that must not be lost, enqueue with `pgmq` and consume.

---

## Idempotency

At-least-once delivery means handlers must tolerate repeats.

```sql
create table public.processed_jobs (
  id          text primary key,
  processed_at timestamptz not null default now()
);
```

```ts
const { error } = await ctx.supabaseAdmin
  .from('processed_jobs')
  .insert({ id: jobId })

if (error?.code === '23505') {
  return Response.json({ ok: true, skipped: true })   // already done
}
```

A unique-violation on insert is the cheapest idempotency check available — no read, no race.

---

## Keeping Work Out of the Write Path

```sql
-- ❌ Blocks the insert on a network call, and fails it if the call errors
create trigger on_signup after insert on public.profiles
for each row execute function public.call_welcome_api();

-- ✅ Local enqueue; a scheduled consumer does the work
create trigger on_signup after insert on public.profiles
for each row execute function public.enqueue_welcome_email();
```

The same reasoning applies to embeddings, PDF generation, image processing, and third-party syncs.

---

## Monitoring

```sql
-- Queue depth and oldest message
select queue_length, oldest_msg_age_sec, newest_msg_age_sec
from pgmq.metrics('email_jobs');

-- Failures
select * from cron.job_run_details where status <> 'succeeded' order by start_time desc limit 20;
select * from net._http_response where status_code >= 400 order by created desc limit 20;
```

Alert on growing queue depth and on rising `oldest_msg_age_sec` — a consumer that stopped looks exactly like a quiet system until the backlog is enormous.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Writes became slow after a feature landed | HTTP call inside a trigger |
| Sign-ups fail intermittently | Trigger on `auth.users` raising on a third-party error |
| Scheduled job "not running" | Check `cron.job_run_details` — it recorded the failure |
| HTTP from SQL silently does nothing | `net.http_post` is async; check `net._http_response` |
| Jobs processed twice | At-least-once delivery; handler not idempotent |
| Queue grows without bound | Consumer stopped, or throwing before `pgmq.delete` |
| Messages retried forever | No `read_ct` threshold and no archive step |
| Database bloats over time | `cron.job_run_details` never trimmed |
| Secret key visible in `cron.job` | Embedded in the job SQL instead of read from Vault |
| Job enqueued for a rolled-back write | Enqueued outside the transaction |
