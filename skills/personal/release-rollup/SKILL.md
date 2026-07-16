---
name: release-rollup
description: "Merges per-service release reports into one customer-facing release document covering major changes, benefits, impact, a deployment playbook, and a version matrix. Use when combining several service reports into a single release note, customer announcement, upgrade notice, change request, or maintenance-window plan for a dedicated or on-prem environment."
argument-hint: "<reports directory>"
---

# Release Roll-Up — Customer Release Document

Turns N per-service reports into one document a customer's IT lead reads and approves.

Consumes what `release-scan` produces. Run that skill once per repository first — this skill
merges, it never scans.

## When to Use

- Combining several `release-scan` reports into one customer release note
- Building a deployment playbook or version matrix across multiple services
- Preparing a maintenance-window plan or upgrade notice for a dedicated or on-prem customer

## When Not to Use

- Working out what changed in a repo — that is `release-scan`, which produces this skill's input
- Writing an internal changelog — this document is written for a customer's IT lead
- Recapping a release that already shipped — this is an approval artifact, written before the window

## Workflow

### Step 1 — Parse the frontmatter first

The input is a directory of reports (`release-reports/*.md`) carrying the `release-scan`
contract. Parse every file's YAML frontmatter and build a table before writing any prose — the
frontmatter alone determines the document's structure:

- any `breaking_api: true` → Impact leads with breaking changes
- any `db_migration: true` with `migration_reversible: false` → rollback is restore-from-backup,
  not redeploy, and the playbook must say so
- all `deploy_after` values → the deploy wave ordering
- any `downtime_required: true` → this is a maintenance window, not a rolling deploy

A report whose frontmatter keys have drifted from the contract is not a parse failure to route
around — it silently drops that service from the document. Say so and stop.

### Step 2 — Block on gaps

Collect every `NEEDS-HUMAN` and `UNKNOWN` across the reports and present them as one chase list,
**before** drafting.

Do not resolve them yourself. This document becomes the customer's reference for a maintenance
window — an invented downtime figure or a guessed config owner surfaces at the worst possible
moment. If the user chooses to proceed with gaps, mark each one `TBC` visibly in the draft
rather than smoothing it over.

### Step 3 — Write the document

Copy `assets/release-document-template.md` and work its eight sections in order. Read
`references/document-sections.md` for the rule each section follows — clustering by theme rather
than by repo, wave ordering from `deploy_after`, and what belongs in Customer Actions.

Save to `release-notes/<platform-version>.md`.

## Tone

Factual and calm. State breaking changes and downtime plainly and early. An enterprise client
who finds a breaking change on their own, after reading a cheerful summary, trusts the next
document less — naming a limitation is what makes the rest credible.

## Next Step

The document is a proposal, not an announcement. It is not finished until the customer has
approved the maintenance window; the schedule inside it is a request in their timezone.

- **If approved:** the window is booked, and the playbook's rollback decision point and abort
  criteria become the operational script for the deploy itself.
- **If not approved:** revise in place. A rejection usually names a section — a window in the
  wrong timezone, unacceptable downtime, an unresolved TBC. If a service's report changes
  underneath the document, re-run `release-scan` for that service and redo Step 1: frontmatter
  drives structure, so one changed field can move the whole document.
