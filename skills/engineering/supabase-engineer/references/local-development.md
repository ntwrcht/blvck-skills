# Local Development

The whole stack runs locally in Docker: Postgres, Auth, PostgREST, Storage, Realtime, Studio, and the Edge Functions runtime. Develop against it rather than a shared remote project.

---

## Getting Started

```bash
npm install -D supabase
npx supabase init          # creates supabase/config.toml
npx supabase start         # boots the stack (first run pulls images)
npx supabase status        # URLs and local keys
npx supabase stop          # stop; --no-backup to discard the local database
```

`supabase start` prints the local API URL, Studio URL, and keys. Local keys are fixed development values — they are not secret and are safe to commit in a `.env.example`.

| Service | Local URL |
|---|---|
| API | http://127.0.0.1:54321 |
| Studio | http://127.0.0.1:54323 |
| Postgres | postgresql://postgres:postgres@127.0.0.1:54322/postgres |
| Inbucket (email) | http://127.0.0.1:54324 |

Inbucket catches every outbound email, so sign-up confirmations and magic links are testable without a mail provider.

---

## The Loop

```bash
supabase migration new add_posts       # write SQL
supabase db reset                      # re-apply everything + seed
npm run db:types                       # regenerate types
supabase test db                       # run pgTAP
```

`supabase db reset` is the workhorse: it drops the database, replays every migration, and runs `seed.sql`. Running it often means migration-history bugs surface immediately rather than in CI.

Never change the schema in Studio and move on. Studio edits are real, but they live only in your local database and vanish on the next reset. Either write the migration first, or use `supabase db diff` to capture what you did:

```bash
supabase db diff -f captured_changes     # generate a migration from local drift
```

---

## `config.toml`

```toml
project_id = "my-app"

[api]
enabled = true
port = 54321
schemas = ["public", "graphql_public"]      # exposed schemas — keep internal ones out
extra_search_path = ["public", "extensions"]
max_rows = 1000

[db]
port = 54322
major_version = 17

[db.migrations]
schema_paths = ["./schemas/*.sql"]          # declarative schemas

[auth]
enabled = true
site_url = "http://127.0.0.1:3000"
additional_redirect_urls = ["http://127.0.0.1:3000/auth/callback"]
jwt_expiry = 3600
enable_signup = true

[auth.email]
enable_confirmations = false                # local convenience; keep true in production

[auth.external.github]
enabled = true
client_id = "env(GITHUB_CLIENT_ID)"
secret = "env(GITHUB_SECRET)"

[functions.stripe-webhook]
verify_jwt = false

[storage]
file_size_limit = "50MiB"
```

Commit `config.toml`. It is how the whole team gets the same local environment.

`env(VAR)` reads from the environment, so OAuth secrets stay out of the file.

`api.schemas` mirrors the remote project's exposed schemas — a mismatch means something works locally and 404s in production, or worse, is exposed in production but not locally.

---

## Linking a Remote Project

```bash
supabase login
supabase link --project-ref <ref>

supabase db pull                 # pull remote schema into a migration
supabase db push                 # apply local migrations to remote
supabase migration list          # compare local and remote history
supabase db diff --linked        # what differs from the remote
```

`supabase db pull` is how to adopt an existing project that was built in the dashboard: it captures the current schema as a baseline migration. Do that once, then stop editing in the dashboard.

---

## Seeding

```sql
-- supabase/seed.sql — runs after migrations on every reset
insert into public.tags (id, name) values
  ('11111111-1111-1111-1111-111111111111', 'postgres'),
  ('22222222-2222-2222-2222-222222222222', 'typescript')
on conflict (id) do nothing;
```

Fixed UUIDs keep tests deterministic. `on conflict do nothing` makes the file re-runnable.

Auth users need the admin API, not SQL:

```ts
await admin.auth.admin.createUser({
  email: 'a@test.dev', password: 'password123', email_confirm: true,
})
```

---

## Edge Functions Locally

```bash
supabase functions serve                     # all, with hot reload
supabase functions serve my-fn --inspect-mode brk
```

Secrets come from `supabase/functions/.env` locally — gitignore it. Remote secrets are set with `supabase secrets set`, and forgetting to promote them is the usual reason a function works locally and fails deployed.

---

## Studio

http://127.0.0.1:54323 gives table and SQL editors, an auth user list, a storage browser, and log views.

Use it to **inspect**, not to change. Anything structural goes through a migration. The one safe habit: explore in the SQL editor, then paste the working statement into a migration file.

---

## Environment Parity

Differences that bite:

| Setting | Local default | Production |
|---|---|---|
| Email confirmation | often off | should be on |
| Redirect URLs | localhost | real domain, allowlisted |
| Rate limits | permissive | tightened |
| Extensions | whatever you installed | must be in a migration |
| Exposed schemas | `config.toml` | dashboard setting |
| Secrets | `.env` files | `supabase secrets set` |

Extensions are the sneakiest: `create extension` run in Studio locally works, then production fails on a function that depends on it. Put every extension in a migration.

---

## Troubleshooting

```bash
supabase stop --no-backup && supabase start   # clean slate
supabase start --debug
docker ps                                     # what is actually running
supabase db reset --debug
```

| Problem | Fix |
|---|---|
| Port already in use | Change ports in `config.toml`, or stop the other project |
| Stack will not start | Docker not running, or out of disk |
| Schema drift after manual edits | `supabase db diff -f fix` to capture, then reset |
| Migration works on reset but not push | Remote has state the history does not create |
| Slow first start | Image pull; subsequent starts are fast |

Running two Supabase projects at once needs distinct ports and `project_id` values.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Schema change disappears | Made in Studio, never captured in a migration |
| Works locally, fails in production | Extension, exposed schema, or secret only set locally |
| Confirmation emails never arrive | Check Inbucket — local mail does not leave the machine |
| OAuth fails locally | Redirect URL not in `additional_redirect_urls` |
| Types out of date | `gen types` not re-run after `db reset` |
| Local keys committed as secrets | They are fixed development values, but production keys must never follow |
| `db reset` wipes test data | By design — put it in `seed.sql` |
| Team environments differ | `config.toml` not committed |
