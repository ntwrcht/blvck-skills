# Self-Hosting

Supabase is open source and runs via Docker Compose. Most projects should not self-host — the reasons that justify it are specific, and the operational load is real.

---

## When It Is Justified

| Reason | Notes |
|---|---|
| Data residency or regulatory constraint | The usual legitimate driver |
| Air-gapped or on-premises deployment | No alternative |
| Existing Postgres you must keep | Can adopt parts rather than the whole platform |
| Genuine cost at very large scale | Compare against the salary cost of operating it |

Not good reasons: avoiding a small monthly bill, or preferring to control everything. Self-hosting means you own backups, upgrades, monitoring, TLS, scaling, and incident response for seven services.

---

## Stack

```bash
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env
docker compose up -d
```

| Service | Role |
|---|---|
| Postgres | The database |
| PostgREST | The data API |
| GoTrue | Auth |
| Realtime | WebSocket subscriptions |
| Storage API | Object storage, backed by disk or S3 |
| Kong | API gateway and routing |
| Studio | Dashboard |
| `imgproxy` | Image transformations |
| `supavisor` | Connection pooling |

Edge Functions run separately via `edge-runtime`, and the hosted Vector/Logflare log pipeline has no drop-in equivalent — log aggregation is on you.

---

## Secrets

The example `.env` ships with public demo values. Every one of them must be replaced before the stack is reachable from anywhere but localhost.

```bash
openssl rand -base64 48          # JWT_SECRET (min 32 chars)
openssl rand -base64 32          # POSTGRES_PASSWORD
openssl rand -base64 32          # DASHBOARD_PASSWORD, SECRET_KEY_BASE, VAULT_ENC_KEY
```

```bash
POSTGRES_PASSWORD=…
JWT_SECRET=…
ANON_KEY=…                 # JWT signed with JWT_SECRET, role "anon"
SERVICE_ROLE_KEY=…         # JWT signed with JWT_SECRET, role "service_role"
DASHBOARD_USERNAME=…
DASHBOARD_PASSWORD=…
SECRET_KEY_BASE=…
VAULT_ENC_KEY=…
SITE_URL=https://app.example.com
API_EXTERNAL_URL=https://api.example.com
```

`ANON_KEY` and `SERVICE_ROLE_KEY` are JWTs signed with `JWT_SECRET` — generate them with Supabase's key generator or a JWT tool, not by inventing strings. Rotating `JWT_SECRET` invalidates both and every live session.

A self-hosted instance running the demo keys is fully open. This has happened to real deployments found by internet-wide scans.

---

## Exposure

Kong is the only service that should be reachable. Bind everything else to the internal network:

```yaml
services:
  db:
    ports: []                      # not "5432:5432"
  kong:
    ports:
      - "127.0.0.1:8000:8000"      # behind a reverse proxy that terminates TLS
```

Checklist:

- Postgres not exposed publicly; access over a private network or a bastion.
- Studio behind auth and IP restriction — it is a full admin console.
- TLS terminated at nginx/Caddy/Traefik in front of Kong.
- Firewall default-deny.
- `edge-runtime` reachable only through Kong.

---

## Backups

Nothing is automatic. This is the single biggest operational difference from hosted.

```bash
# Logical
docker exec supabase-db pg_dump -U postgres -Fc postgres > backup_$(date +%F).dump

# Physical / PITR
# pgBackRest or WAL-G with WAL archiving to object storage
```

Requirements worth writing down before going live:

- Automated daily dumps plus WAL archiving for point-in-time recovery.
- Off-host, off-region storage.
- **A restore rehearsed on a clean host.** An untested backup is a hypothesis.
- Storage objects backed up too — the `storage` volume or the S3 bucket. A database restore without files is half a restore.
- Documented RPO and RTO.

---

## Upgrades

```bash
docker compose pull
docker compose up -d
```

Images move independently and are not always mutually compatible. Practice:

- Pin image tags; never run `latest` in production.
- Read the changelogs for GoTrue, PostgREST, and Realtime — auth and API breakage lands there.
- Back up before every upgrade.
- Rehearse on staging.

Postgres major version upgrades are a separate, planned exercise: `pg_upgrade` or dump-and-restore, with downtime.

---

## Adopting Parts

You do not have to run the whole stack. PostgREST and GoTrue in front of an existing Postgres is a common middle path:

```yaml
services:
  postgrest:
    image: postgrest/postgrest
    environment:
      PGRST_DB_URI: postgres://authenticator:…@existing-db:5432/app
      PGRST_DB_SCHEMAS: public
      PGRST_DB_ANON_ROLE: anon
      PGRST_JWT_SECRET: ${JWT_SECRET}
```

The client libraries work against it, and RLS behaves identically — it is the same PostgREST.

---

## Differences from Hosted

| Feature | Self-hosted |
|---|---|
| Automatic backups | You build it |
| Point-in-time recovery | You build it |
| Read replicas | Manual streaming replication |
| Log explorer | No hosted pipeline; ship logs yourself |
| Advisors | Not available — run the queries by hand |
| Branching | Not available |
| Edge Functions | Separate `edge-runtime` container |
| Storage CDN | Put a CDN in front yourself |
| Metrics endpoint | Scrape Postgres and container metrics yourself |
| Upgrades | Manual, coordinated |

Losing the advisors matters more than it sounds. Keep the RLS check in CI:

```sql
select c.relname from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind in ('r','p') and not c.relrowsecurity;
```

---

## Local CLI vs Self-Hosting

`supabase start` runs a similar stack for development. It is not a production deployment — no TLS, fixed development keys, no persistence guarantees, no backups. Do not repurpose it.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Instance compromised shortly after launch | Demo `.env` keys never replaced |
| Database reachable from the internet | Postgres port published in Compose |
| Anyone can reach the admin console | Studio not behind auth or IP restriction |
| No recovery after data loss | Backups never configured or never tested |
| Files missing after a restore | Storage volume not included in backups |
| Auth breaks after an upgrade | Independent image versions; pin tags |
| All sessions invalidated | `JWT_SECRET` rotated |
| Unprotected table found late | No advisors — add the RLS check to CI |
| Slow queries invisible | No log pipeline configured |
