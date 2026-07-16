# Classification Rubric

Work these six buckets in order against the evidence pack. Each bucket feeds a specific
section of the eventual customer document, which is why the report schema looks the way it does.

---

## A. Change identification → *Major Change*

Classify each commit / PR / Jira issue as one of:
`Feature` `Enhancement` `Bug fix` `Security` `Performance` `Refactor` `Chore`

Then apply the **customer-visible test**: could a customer, using only the product's
interfaces, notice this change happened? If no, it goes in `internal_changes`, not in the
customer bullets. Refactors, test additions, CI changes, and dependency patch bumps
almost always fail this test.

---

## B. Contract & interface → *Impact* (highest-risk bucket)

The evidence pack's "API / route / contract files touched" section points here. Read the
actual diff of those files when the file list alone isn't conclusive.

**Breaking** (customer integration code must change):
- Endpoint removed or path renamed
- Request/response field removed or renamed
- Field type changed (string → int, scalar → object)
- New **required** request field
- Status code semantics changed
- Auth mechanism or token format changed
- Enum value removed
- Message queue payload shape changed, or topic renamed

**Non-breaking**:
- New endpoint
- New optional request field
- New response field (assuming clients tolerate unknown fields — note this assumption)

Also capture **inter-service dependency**: if this service now calls a new endpoint on
another service, that is a deploy-order constraint. Record it in `deploy_after` — the
provider must be deployed before the consumer. Missing these is what turns a clean
maintenance window into a rollback.

---

## C. Data layer → *Impact* + *Playbook* (usually the biggest time driver)

For each migration file found:
- What it does structurally (add column, drop column, add index, backfill)
- **Locking or online?** A lock means downtime.
- **Reversible?** Dropping a column or transforming data in place is *not* reversible without
  a restore. Say so explicitly — this changes the rollback plan from "redeploy old tag" to
  "restore from backup", which is a different conversation with the customer.
- Runtime: `NEEDS-HUMAN` unless the customer's data volume is known. Index builds on a large
  collection are the classic hidden downtime.

For MongoDB specifically: new indexes, new collections, document shape changes. A shape change
with no migration script implies the code handles both shapes — verify, and if it doesn't,
that is a defect worth flagging before release, not after.

---

## D. Runtime & config → *Playbook* (where deployments actually fail)

Newly added env vars are the single most common cause of a failed dedicated-environment
deploy. For each key from the evidence pack:
- Does it have a default in code? (if not, the service won't start without it)
- Who must supply the value — your team, or the customer? (`NEEDS-HUMAN` if unclear; a secret,
  license key, or their internal endpoint means the customer)

Also record:
- Base image change, new system packages, new exposed ports
- Resource requests/limits, replica count, health check path changes
- New infra dependency: Redis, object storage, new database
- **New outbound hosts** — dedicated and on-prem environments are firewalled. A new outbound
  call fails silently unless the customer opens it first. The evidence pack lists URL
  candidates; filter out doc links and comments, keep real runtime calls.
- Cron / scheduled job changes
- Feature flags added, and their default state

---

## E. Dependency & security → *Benefit* + *Impact*

- Major version bumps only. Aggregate patch/minor as one line: "dependency updates".
- Runtime version changes (Go, Node, Angular major) — these can change base image and
  resource behavior.
- CVEs fixed: strong material for the customer's *Benefit* section, especially for regulated
  clients. Only claim a CVE if a commit, PR, or dependency bump states it.
- Security hardening: headers, auth, TLS, rate limiting.
- New dependency licenses — matters for on-prem deployments.

---

## F. Behavior & UX → *Benefit* + *Process impact*

- UI changes that alter a user's workflow — a moved screen or an added step means the
  customer's internal SOP and training material go stale. This is *process impact* and
  customers consistently under-plan for it because nobody tells them.
- Default behavior changes (something off is now on)
- Deprecations, with removal timeline
- Performance characteristics — only with evidence
- Known issues shipping with the release

---

## Risk level

- **High** — breaking contract change, irreversible migration, or new mandatory infra
- **Medium** — new required config, non-trivial migration, changed default behavior
- **Low** — additive changes, bug fixes, internal refactors

When torn between two levels, choose the higher one and explain why in one line. The cost of
an over-flagged Low is a few minutes of PO review. The cost of an under-flagged High is a
maintenance window that overruns in front of the customer.
