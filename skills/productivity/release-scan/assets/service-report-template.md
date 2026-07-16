---
# ── machine-readable contract: the roll-up parses this. Do not rename keys. ──
service: <repo / service name>
old_tag: <tag currently in target env>
new_tag: <tag being released>
commits: <n>
change_class: feature | enhancement | fix | security | mixed | version-bump-only
risk: low | medium | high
breaking_api: true | false
db_migration: true | false
migration_reversible: true | false | n/a
downtime_required: true | false | UNKNOWN
downtime_minutes: <n> | NEEDS-HUMAN
new_config_required: true | false
new_infra_dependency: true | false
deploy_after: [<service>, ...]   # services that must be deployed before this one
scanned_by: <name>
scanned_on: <YYYY-MM-DD>
---

# <service> — <old_tag> → <new_tag>

## Customer-visible changes
<!-- 3–7 bullets, business language, no repo/file/function names.
     Empty list is a valid and common answer. -->
- 

## Internal changes (not for customer)
- 

## Issue keys
<!-- Key — Jira summary — type. Mark UNRESOLVED if Jira lookup wasn't available. -->
- 

## Breaking changes
<!-- Per change: what broke, which caller is affected, what they must do.
     "None" if none. -->
- 

## Database migration
- What: 
- Locking: 
- Reversible: 
- Est. runtime: NEEDS-HUMAN — depends on target environment data volume

## New configuration required
| Key | Default? | Supplied by | Notes |
|---|---|---|---|
|  |  |  |  |

## New infrastructure / network requirements
<!-- New services, and outbound hosts the customer must allowlist. -->
- 

## Deployment notes
- Deploy order constraint: 
- Rollback: possible | conditional | not possible — <why>
- Smoke test after deploy:
  1. 
  2. 

## Open questions for PO
<!-- Every NEEDS-HUMAN above, restated as a question with an owner.
     This is the PO's chase list — be specific. -->
- 
