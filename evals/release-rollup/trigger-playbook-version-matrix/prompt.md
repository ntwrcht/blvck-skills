---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Build the deployment playbook and version matrix for this release.

=== release-reports/identity-service__v3.4.0__v4.0.0.md ===
---
service: identity-service
old_tag: v3.4.0
new_tag: v4.0.0
commits: 41
change_class: mixed
risk: high
breaking_api: true
db_migration: true
migration_reversible: false
downtime_required: true
downtime_minutes: 25
new_config_required: true
new_infra_dependency: false
deploy_after: []
scanned_by: Nok
scanned_on: 2026-10-06
---

# identity-service — v3.4.0 → v4.0.0

## Customer-visible changes
- Single sign-on now supports SAML 2.0 identity providers alongside OIDC
- Sessions expire after 8 hours of inactivity by default (configurable)
- Password reset links now expire after 30 minutes

## Internal changes (not for customer)
- Moved token signing to a key-rotation service client

## Issue keys
- IAM-210 — SAML IdP support — story
- IAM-233 — Idle session timeout — story

## Breaking changes
- `POST /oauth/token` no longer accepts the `password` grant type. Affects any customer integration that logs in service accounts with username and password; they must switch to the `client_credentials` grant.

## Database migration
- What: splits the `users` table credentials into a new `user_credentials` table and drops the old columns
- Locking: full table lock on `users`
- Reversible: no — the old columns are dropped
- Est. runtime: 25 minutes on a 2M-user copy of the customer dataset (measured by QA)

## New configuration required
| Key | Default? | Supplied by | Notes |
|---|---|---|---|
| SAML_SP_ENTITY_ID | no | customer IT | only if they enable SAML |

## New infrastructure / network requirements
- None

## Deployment notes
- Deploy order constraint: none
- Rollback: not possible after the migration — restore the database from backup
- Smoke test after deploy:
  1. Log in with an OIDC user
  2. Request a token with client_credentials

## Open questions for PO
- None
=== release-reports/billing-api__v2.7.1__v2.8.0.md ===
---
service: billing-api
old_tag: v2.7.1
new_tag: v2.8.0
commits: 18
change_class: feature
risk: medium
breaking_api: false
db_migration: true
migration_reversible: true
downtime_required: false
downtime_minutes: 0
new_config_required: true
new_infra_dependency: false
deploy_after: [identity-service]
scanned_by: Pim
scanned_on: 2026-10-07
---

# billing-api — v2.7.1 → v2.8.0

## Customer-visible changes
- Invoices can be exported as CSV from the billing page
- Usage reports now show a per-department breakdown

## Internal changes (not for customer)
- Upgraded the PDF renderer library

## Issue keys
- BIL-88 — CSV invoice export — story
- BIL-91 — Department usage breakdown — story

## Breaking changes
- None

## Database migration
- What: adds nullable `department_id` column to `usage_events`
- Locking: none (online add column)
- Reversible: yes
- Est. runtime: under 1 minute

## New configuration required
| Key | Default? | Supplied by | Notes |
|---|---|---|---|
| INVOICE_EXPORT_BUCKET | no | customer IT | S3-compatible bucket for CSV exports |

## New infrastructure / network requirements
- None

## Deployment notes
- Deploy order constraint: after identity-service (uses the new token claims)
- Rollback: possible — redeploy v2.7.1
- Smoke test after deploy:
  1. Export one invoice as CSV

## Open questions for PO
- None
=== release-reports/notification-worker__v1.12.0__v1.13.0.md ===
---
service: notification-worker
old_tag: v1.12.0
new_tag: v1.13.0
commits: 9
change_class: enhancement
risk: low
breaking_api: false
db_migration: false
migration_reversible: n/a
downtime_required: false
downtime_minutes: 0
new_config_required: false
new_infra_dependency: true
deploy_after: [billing-api]
scanned_by: Nok
scanned_on: 2026-10-07
---

# notification-worker — v1.12.0 → v1.13.0

## Customer-visible changes
- Invoice-ready emails can also be sent to a Microsoft Teams channel

## Internal changes (not for customer)
- Retry backoff now uses jitter

## Issue keys
- NOT-40 — Teams webhook channel — story

## Breaking changes
- None

## Database migration
- What: none
- Locking: n/a
- Reversible: n/a
- Est. runtime: n/a

## New configuration required
| Key | Default? | Supplied by | Notes |
|---|---|---|---|
|  |  |  |  |

## New infrastructure / network requirements
- Outbound HTTPS to `*.webhook.office.com` must be allowlisted if Teams delivery is enabled

## Deployment notes
- Deploy order constraint: after billing-api (consumes its invoice-ready event)
- Rollback: possible — redeploy v1.12.0
- Smoke test after deploy:
  1. Trigger a test invoice-ready notification

## Open questions for PO
- None
=== release-reports/admin-web__v5.2.0__v5.2.1.md ===
---
service: admin-web
old_tag: v5.2.0
new_tag: v5.2.1
commits: 1
change_class: version-bump-only
risk: low
breaking_api: false
db_migration: false
migration_reversible: n/a
downtime_required: false
downtime_minutes: 0
new_config_required: false
new_infra_dependency: false
deploy_after: [identity-service]
scanned_by: Pim
scanned_on: 2026-10-07
---

# admin-web — v5.2.0 → v5.2.1

## Customer-visible changes

## Internal changes (not for customer)
- Dependency version bump only

## Issue keys
- None

## Breaking changes
- None

## Database migration
- What: none
- Locking: n/a
- Reversible: n/a
- Est. runtime: n/a

## New configuration required
| Key | Default? | Supplied by | Notes |
|---|---|---|---|
|  |  |  |  |

## New infrastructure / network requirements
- None

## Deployment notes
- Deploy order constraint: after identity-service
- Rollback: possible — redeploy v5.2.0
- Smoke test after deploy:
  1. Open the admin login page

## Open questions for PO
- None