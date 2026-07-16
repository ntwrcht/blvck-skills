---
name: release-scan
description: "Scans one service repository between two tags and produces a standardized Service Release Report used to assemble a customer-facing release note. Use when diffing two tags or versions, working out what shipped between releases, assessing deployment impact or breaking changes, or preparing a release for a dedicated or on-prem customer environment."
argument-hint: "<old_tag> <new_tag> [repo_path]"
---

# Release Scan — Per-Service Report

Produces one **Service Release Report** for one repository, in a fixed schema, so that reports
from many repositories merge mechanically into a customer release note.

The value here is *uniformity*, not cleverness. Ten engineers running this on ten repos must
produce ten reports that differ only in content, never in structure — so resist improving the
format for a particular repo.

## When to Use

- Diffing two tags or versions of one service repo for a release
- Preparing release notes for a customer, dedicated, or on-prem environment
- Assessing deployment impact, breaking changes, or migration risk before a maintenance window
- A repo has no CHANGELOG and someone needs to know what shipped

One report covers one repository. A multi-repo release runs this skill once per repo and merges
the reports afterward — never widen a report to cover more than one.

## When Not to Use

- Reviewing a single PR or the working diff — that is code review, not a release scan
- Writing the merged customer-facing document — this skill produces its per-service input
- Explaining a release that already shipped and went wrong — use `post-mortem`

## Core Rule

**Every statement in the report must trace to evidence in the diff** — a commit, a PR title, a
Jira key, a changed file. Where evidence does not exist, write `UNKNOWN` or
`NEEDS-HUMAN: <question>`. Never infer, never fill a gap with plausible-sounding content.

`NEEDS-HUMAN: migration runtime on customer data volume` is useful — the PO knows to chase it.
Guessing "approximately 5 minutes" is worse than useless, because it gets copied into a customer
document and is then wrong during a maintenance window. Migration runtime, config ownership,
downtime, and benefit numbers are almost never yours to know; `references/classification.md`
marks where each one bites.

## Workflow

### Step 1 — Establish the tag range

Ask for `old_tag` (what is **currently running in the target environment**) and `new_tag` (what
is being released), unless both are already given.

Push back if the old tag comes from memory or from the main branch. Dedicated and on-prem
environments drift, and a wrong baseline produces a confidently wrong change list — the most
expensive failure mode of this skill. A trustworthy `old_tag` comes from the running deployment
manifest or the target environment's container registry.

### Step 2 — Collect evidence

Run the bundled script. It is deterministic and does all git extraction, so report variation
comes only from judgment, not from which commands someone happened to run:

```bash
bash scripts/collect_evidence.sh <old_tag> <new_tag> [repo_path] > /tmp/evidence.md
```

Read `/tmp/evidence.md`. If it reports a missing ref, run `git fetch --tags --force` and retry.
Sections reading `_none_` are findings — the script looked and found nothing.

**Do not explore with ad-hoc git commands.** One exception: when a changed file's *content*
decides its classification — a migration, or a route where a field may have been removed rather
than added — run a targeted `git diff old..new -- <path>`. Exploring past that reintroduces the
variability the script exists to remove.

### Step 3 — Early exit for no-op repos

If the diff is confined to tests, docs, CI config, linting, or formatting, this repo is a
**no-op for the customer**. Emit the report with `change_class: version-bump-only` and stop.
Many repos in a multi-repo release are genuinely no-ops, and saying so plainly is the correct
output — do not manufacture bullets for a repo that only bumped its CI image.

### Step 4 — Classify

Read `references/classification.md` and work its six buckets. It carries the
breaking-vs-non-breaking rules, the customer-visible test, and the risk ladder.

### Step 5 — Enrich from Jira, if available

Repos without a CHANGELOG usually still carry Jira keys in commit messages — those summaries are
the real changelog, written closer to language a customer reads than raw commit subjects.

If an Atlassian/Jira tool is available, look up each key the script extracted and use the issue
summary and type; otherwise list the keys as-is so the PO can resolve them. Prefer the Jira
summary over the commit subject when both describe the same change.

### Step 6 — Write the report

Read `references/customer-language.md` first — it separates what the customer reads from what
stays internal. Then copy `assets/service-report-template.md`, fill every field, and save to
`release-reports/<service-name>__<old_tag>__<new_tag>.md`.

Keep the YAML frontmatter exactly as templated — key names, spelling, and enum values. The
roll-up parses it, and a field renamed "helpfully" silently drops that service from the
aggregated customer document.

## Next Step

The report is the PO's input, not a customer deliverable. It is not done until the PO has worked
the **Open questions** list — every `NEEDS-HUMAN` blocks the customer document.

- **If approved:** hand it to the roll-up that merges every per-service report into the customer
  release note. Unscanned repos get their own run of this skill first — the roll-up is only as
  accurate as its least-scanned repo.
- **If not approved:** revise in place. A disputed classification means re-reading
  `references/classification.md` against the evidence pack, not softening the wording. If the
  baseline tag was wrong, discard the report and re-run from Step 1 — a wrong `old_tag`
  invalidates every field, and editing cannot repair it.
