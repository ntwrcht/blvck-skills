# Artifact Paths

Canonical registry of where pipeline skills write and read produced artifacts. This is the single source of truth — skill bodies should point here rather than repeat this table.

## Roots

- `docs_root` (default `docs/`) — durable, human-facing artifacts meant to be committed and read later.
- `context_root` (default `.context/`) — ephemeral, session-scoped working state.

A project can override either root, or override an individual key, in `.context/output-paths.md` (written by the `setup-context` skill). If that file doesn't exist, or doesn't mention a given root or key, use the defaults below — never interrupt the user to ask whether `output-paths.md` exists.

## Registry

| Key | Producer | Default path pattern | Root | Shape |
|---|---|---|---|---|
| `prd` | write-a-prd | `docs/prd/<slug>.md` | docs_root | slug'd |
| `story` | write-a-story | `docs/stories/<slug>.md` | docs_root | slug'd |
| `design` | grilling | `docs/design/<slug>.md` | docs_root | slug'd |
| `adr-dir` | domain-modeling | `.context/adr/` (sequentially-numbered files inside) | context_root | already slug'd |
| `postmortem-dir` | post-mortem | `docs/postmortems/<slug>.md` | docs_root | already slug'd (topic = slug) |
| `debug-ledger` | debug | `.context/debug-ledger.md` | context_root | singular |
| `security-findings` | security-audit | `.context/security-findings/<slug>.md` | context_root | slug'd |
| `analytics` | ga4-measurement | `.context/analytics.md` | context_root | singular — shares the file with `setup-context`'s own `analytics.md` domain; read-then-update, not per-feature |
| `scrutiny` | scrutinize | `.context/scrutiny.md`, or `.context/scrutiny-<slug>.md` when a PR/design/topic is clear | context_root | slug'd (flat file, hyphen-suffixed — matches this skill's pre-existing convention, not a subdirectory) |
| `sdd-progress` | subagent-driven-development | `.context/sdd-progress/<slug>.md` | context_root | slug'd (one ledger per plan) |
| `stakeholder-comms` | stakeholder-comms | `.context/stakeholder-comms/<slug>.md` | context_root | slug'd |
| `domain-glossary` | domain-modeling | `CONTEXT.md` | none — fixed at repo root | singular (one evolving glossary, not per-feature) |
| `architecture` | code-to-docs | `docs/architecture/<slug>.md` | docs_root | slug'd (one per documented service or subsystem) |
| `openapi` | code-to-docs | `docs/api/<slug>.yaml` | docs_root | slug'd |
| `diagrams-dir` | code-to-docs | `docs/diagrams/` (one file per diagram inside) | docs_root | already slug'd |
| `runbook` | code-to-docs | `docs/runbooks/<slug>.md` | docs_root | slug'd (one per procedure) |
| `doc-audit` | code-to-docs | `.context/doc-audit/<slug>.md` | context_root | slug'd |
| `user-docs` | write-user-docs | `docs/user/<slug>.md` | docs_root | slug'd (one per manual, guide, or tutorial) |
| `research` | research | `docs/research/<slug>.md` | docs_root | slug'd (one per question investigated) |
| `questionnaire` | to-questionnaire | `docs/questionnaires/<slug>.md` | docs_root | slug'd (one per recipient and topic) |
| `priorities` | prioritize | `docs/priorities/<slug>.md` | docs_root | slug'd (one per ranking exercise) |
| `discovery` | discovery-synthesis | `docs/discovery/<slug>.md` | docs_root | slug'd (one per evidence set synthesized) |

`debug-ledger` is singular because it tracks the *current* investigation and is expected to be reused or cleared once the bug is resolved (see `post-mortem` for the durable writeup). `analytics` is singular for the same reason `domain-glossary` is: it's the same file as `setup-context`'s `analytics.md` domain (one evolving measurement plan, read as input and updated as output — not one file per feature). `domain-glossary` is singular because it is one evolving document, not one per feature — it deliberately lives at the repo root rather than under either root, while its companion ADRs live under `context_root` (`adr-dir` above), matching the `adr/` domain already scaffolded by `setup-context`.

`research` uses `docs_root` because a cited findings file stays valuable long after the question that prompted it — it is the kind of thing a future reader wants, unlike a one-shot work list. `questionnaire` likewise: the answers that come back are a primary source worth keeping beside the decision they informed. `discovery` and `priorities` likewise: synthesized user evidence and a ranking with its assumptions ledger are both things a future reader reopens to ask why a decision was made.

`architecture` is deliberately separate from `design`: `design` holds the forward-looking design doc `grilling` produces before code exists, while `architecture` holds the description of a system as it is actually built, extracted from the code. `doc-audit` uses `context_root` because an audit report is a work list consumed once and then acted on, not a durable artifact — the same reasoning as `scrutiny` and `security-findings`. `diagrams-dir` is directory-shaped rather than slug'd because one documented system normally yields several diagrams at different C4 levels.

`adr-dir` uses `context_root`, not `docs_root`, even though ADRs are durable/reviewable — this matches the existing `adr/` domain in `setup-context`'s own domain reference (same `NNNN-short-title.md` numbering `domain-modeling` uses) and the majority of skills that already read `.context/adr/`.

## Resolution rule

Before writing or reading a keyed artifact:

1. Check `.context/output-paths.md` for `docs_root`, `context_root`, and the specific key.
2. Resolve in this order: exact key override → root override + default filename pattern → hardcoded default above.
3. For slug'd keys, derive `<slug>` as a short kebab-case name from the artifact's feature/topic/subject (the same judgment `post-mortem` already applies to `<topic>`).
4. If a file with that slug already exists, ask the user whether to update it in place or create a new one — never silently overwrite a different artifact under a name collision.
5. If `.context/output-paths.md` doesn't exist at all, silently use the defaults above — do not interrupt the user to ask about configuring it.

## Out of scope

Not part of this registry, with reasons: `handoff` (always the OS temp directory, deliberately never the repo), `codebase-design` (produces vocabulary and a recommendation, not a file), `wait-what` (rewrites a message, produces nothing), `git-guardrails` (target is inherent to the tool — `.claude/settings.json`), `skill-smith` (its output path — `skills/<bucket>/<name>/SKILL.md` — is structural, not a workspace preference), `agent-smith` (same reason — one output path is the repo's own agent roster, the other is fixed by the agent runtime), `caveman` (produces nothing), `triage` (produces tracker state via a connected tool, not a file), `technical-trading-strategy` (no single fixed artifact path).

## Migration (pre-existing projects only)

This registry replaced a set of single-file defaults with directory + slug defaults (and fixed one wrong default). A project that used these skills *before* this registry existed may already have artifacts at the **old** default location below. New projects will never hit this — only run the migration check if a project already has files from prior use.

| Key | Old default (pre-registry) | New default | Why it changed |
|---|---|---|---|
| `prd` | `docs/prd.md` | `docs/prd/<slug>.md` | one file couldn't hold more than one PRD without overwriting |
| `story` | `tasks/stories.md` | `docs/stories/<slug>.md` | same, plus removed the single-file `tasks/` root |
| `design` | `docs/design.md` | `docs/design/<slug>.md` | one file couldn't hold more than one design doc |
| `goals` | `docs/goals.md`, then `docs/goals/<slug>.md` | `docs/design/<slug>.md` | one file couldn't hold more than one goals doc; then `brainstorming` merged into `grilling` and the goals doc and design doc became one artifact |
| `security-findings` | `.context/security-findings.md` | `.context/security-findings/<slug>.md` | one file couldn't hold more than one audit's findings |
| `sdd-progress` | `.context/sdd-progress.md` | `.context/sdd-progress/<slug>.md` | one file couldn't hold more than one plan's ledger |
| `management-update` | `.context/management-update.md`, then `.context/management-update/<slug>.md` | `.context/stakeholder-comms/<slug>.md` | one file couldn't hold more than one update; then `management-talk` and `stakeholder-update` merged into `stakeholder-comms` |
| `stakeholder-update` | `.context/stakeholder-update/<slug>.md` | `.context/stakeholder-comms/<slug>.md` | the two producing skills merged into `stakeholder-comms` |
| `adr-dir` | `docs/adr/` | `.context/adr/` | this was an outright bug — `domain-modeling` wrote here while every consumer read `.context/adr/` |

Keys not in this table (`debug-ledger`, `analytics`, `scrutiny`, `postmortem-dir`, `domain-glossary`) never had a default that changed shape — nothing to migrate for those.

For directory-shaped keys (everything except `adr-dir`), migrating an old single file means choosing a slug for it (derive one from its content/title, or ask) and moving it to `<new-default-dir>/<slug>.md`. For `adr-dir`, move the whole `docs/adr/` directory to `.context/adr/` (merge by ADR number if `.context/adr/` already has entries — don't overwrite an existing number). Prefer `git mv` when the project is a git repo, to preserve file history.

## Configuring

Run the `setup-context` skill to interview for root and per-key overrides; it writes `.context/output-paths.md`. The same skill also checks for and offers to migrate old-location files — see its "Migrate existing artifacts" step.
