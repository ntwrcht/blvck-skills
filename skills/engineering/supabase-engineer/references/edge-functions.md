# Edge Functions

TypeScript on Deno, deployed globally. Use them for work that must not run in a browser and does not belong in the database.

---

## When to Use One

| Fit | Why |
|---|---|
| Third-party API calls needing a secret | Keeps the key off the client |
| Webhook receivers (Stripe, Resend, GitHub) | Public URL with signature verification |
| Scheduled jobs invoked by `pg_cron` | Runs outside a database transaction |
| Server-side integrations (OpenAI, email, PDFs) | Long-running work a trigger must not do |
| Custom auth flows or token exchange | Needs the secret key |

Not a fit: plain CRUD (the data API already does it, typed and with RLS), or anything transactional and data-adjacent (a database function is closer and atomic).

---

## Layout and the `withSupabase` Wrapper

```bash
supabase functions new send-welcome-email
```

```
supabase/
  config.toml
  functions/
    send-welcome-email/index.ts
    _shared/cors.ts               # underscore-prefixed folders are not deployed as functions
```

```ts
// supabase/functions/send-welcome-email/index.ts
import { withSupabase } from 'npm:@supabase/server'

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    const { supabase, userClaims } = ctx      // supabase is RLS-scoped to the caller

    const { email } = await req.json()
    if (!email) return Response.json({ error: 'email required' }, { status: 400 })

    const { error } = await sendEmail(email, userClaims?.sub)
    if (error) return Response.json({ error: 'send failed' }, { status: 502 })

    return Response.json({ ok: true })
  }),
}
```

`withSupabase` verifies the caller against a declared auth mode and hands back a pre-configured client on `ctx`.

| `auth` mode | Caller | Client on `ctx` |
|---|---|---|
| `'user'` | An authenticated end user | `ctx.supabase`, RLS-scoped to them |
| `'secret'` | A trusted service holding a secret key | `ctx.supabaseAdmin`, RLS bypassed |
| `'secret:automations'` | Only that named secret key | as above |
| `['publishable', 'secret']` | Either | scoped accordingly |
| `'none'` | Anyone | none — you authorize |

`auth: 'none'` combined with `verify_jwt = false` makes a genuinely public endpoint. That is correct for webhooks, where the provider has no Supabase JWT — but then signature verification is the only thing standing between you and anyone on the internet.

Older functions use the bare `Deno.serve(async req => …)` pattern with a hand-built client. Both work; match the project.

---

## Config

```toml
# supabase/config.toml
[functions.send-welcome-email]
verify_jwt = true

[functions.stripe-webhook]
verify_jwt = false          # Stripe has no Supabase JWT
```

`verify_jwt = true` (the default) rejects unauthenticated callers at the platform edge, before your handler runs.

---

## Secrets

```bash
supabase secrets set RESEND_API_KEY=re_… OPENAI_API_KEY=sk-…
supabase secrets list
supabase secrets unset OLD_KEY
```

```ts
const key = Deno.env.get('RESEND_API_KEY')
if (!key) return Response.json({ error: 'misconfigured' }, { status: 500 })
```

Locally, `supabase/functions/.env` — gitignored.

`SUPABASE_URL`, `SUPABASE_ANON_KEY` / publishable, `SUPABASE_SERVICE_ROLE_KEY` / secret, and `SUPABASE_DB_URL` are injected automatically.

---

## Webhooks

```ts
import { withSupabase } from 'npm:@supabase/server'
import Stripe from 'npm:stripe'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!)

export default {
  fetch: withSupabase({ auth: 'none' }, async (req, ctx) => {
    const body = await req.text()                     // raw text, not parsed JSON
    const signature = req.headers.get('stripe-signature')

    let event: Stripe.Event
    try {
      event = await stripe.webhooks.constructEventAsync(
        body, signature!, Deno.env.get('STRIPE_WEBHOOK_SECRET')!
      )
    } catch {
      return Response.json({ error: 'invalid signature' }, { status: 400 })
    }

    // Idempotency — providers retry
    const { error: seen } = await ctx.supabaseAdmin
      .from('processed_events')
      .insert({ id: event.id })
    if (seen?.code === '23505') return Response.json({ ok: true })   // already handled

    await handleEvent(event, ctx.supabaseAdmin)
    return Response.json({ received: true })
  }),
}
```

Four things matter here:

- Verify against the **raw** body. Re-serializing parsed JSON changes bytes and breaks the HMAC.
- Set `verify_jwt = false` for this function, or the provider gets a 401.
- Make it idempotent. A unique-violation on the event id is the cheapest way.
- Return 2xx quickly; providers retry on timeout.

---

## Local Development

```bash
supabase start
supabase functions serve send-welcome-email          # hot reload
supabase functions serve                             # all of them

curl -i -X POST 'http://127.0.0.1:54321/functions/v1/send-welcome-email' \
  -H 'apiKey: <publishable key>' \
  -H 'Authorization: Bearer <user access token>' \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com"}'
```

```bash
supabase functions serve --inspect-mode brk          # debugger
```

---

## Deploy

```bash
supabase login
supabase link --project-ref <ref>
supabase functions deploy send-welcome-email
supabase functions deploy                            # all
supabase functions delete old-function
supabase functions logs send-welcome-email
```

In CI:

```yaml
- uses: supabase/setup-cli@v1
- run: supabase functions deploy --project-ref ${{ secrets.PROJECT_REF }}
  env:
    SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
```

---

## Invoking

```ts
// From the client — attaches the user's JWT automatically
const { data, error } = await supabase.functions.invoke('send-welcome-email', {
  body: { email },
})
```

```sql
-- From Postgres, via pg_net
select net.http_post(
  url     := 'https://<ref>.supabase.co/functions/v1/send-welcome-email',
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || current_setting('app.settings.secret_key')
  ),
  body    := jsonb_build_object('email', new.email)
) as request_id;
```

`net.http_post` is asynchronous and fire-and-forget — it returns a request id, not a response. Never treat it as a synchronous call, and never let a trigger block on HTTP.

---

## Deno Notes

- Imports are URLs or `npm:` specifiers — `import Stripe from 'npm:stripe'`, `import { z } from 'npm:zod'`.
- `deno.json` in the function folder for an import map.
- Node built-ins via `node:` — `import { Buffer } from 'node:buffer'`.
- Web APIs (`fetch`, `crypto`, `Response`) are global; Node-only packages may not work.

CORS for browser callers:

```ts
// supabase/functions/_shared/cors.ts
export const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? '',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
```

Handle `OPTIONS` before anything else, and allowlist origins rather than reflecting `*`.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| 401 on every call | `verify_jwt = true` with an unauthenticated caller |
| Webhook always 401s | `verify_jwt` not disabled for that function |
| Signature verification fails | Body parsed as JSON before verifying |
| Duplicate side effects | Handler not idempotent; provider retried |
| Secret undefined at runtime | `supabase secrets set` not run for the linked project |
| Works locally, fails deployed | Local `.env` never promoted to project secrets |
| Browser calls blocked | No `OPTIONS` handler or CORS headers |
| Function times out | Long work inline — queue it instead |
| `_shared` deployed as a function | It is not; underscore folders are skipped by design |
| Trigger slow after adding an HTTP call | `net.http_post` inside a synchronous path |
