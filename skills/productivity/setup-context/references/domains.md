# Domain Reference

Descriptions, consuming skills, and seed templates for each `setup-context` domain.

Each domain file uses these layers where applicable:
- **Glossary** — what terms mean in this project
- **Decisions** — why things were built this way
- **Conventions** — rules and patterns to follow

---

## project.md

**Consumed by:** angular-engineer, python-engineer, strapi-engineer, ga4-measurement, security-audit, stakeholder-update, write-a-prd, write-a-story

**Explainer:** Stack, repo layout, environment setup, and core vocabulary. The broadest context file — most skills read it first.

```markdown
# Project Context

## Stack

[Key technologies, frameworks, runtimes, and versions]

## Repo Structure

[Folder layout and what lives where]

## Environment

[Dev setup, env vars, local run commands]

## Glossary

| Term | Meaning |
|---|---|
| [term] | [definition as used in this project] |
```

---

## engineering.md

**Consumed by:** angular-engineer, python-engineer, strapi-engineer, tdd, diagnose

**Explainer:** Code conventions, patterns, and testing strategy. Skills use this to match the project's existing style rather than applying generic defaults.

```markdown
# Engineering Context

## Conventions

[Naming, folder structure, file organisation rules]

## Patterns

[Preferred patterns for state, data access, error handling]

## Testing Strategy

[Test runner, what to unit-test vs. integration-test, fixture conventions]

## Framework Notes

[Version-specific rules or non-obvious behaviours]
```

---

## git-workflow.md

**Consumed by:** angular-engineer, python-engineer, strapi-engineer, triage

**Explainer:** Branch naming, commit conventions, PR process, and merge rules.

```markdown
# Git Workflow

## Branch Naming

[Pattern, e.g. feat/<ticket>-<slug>, fix/<slug>]

## Commit Convention

[Format, e.g. Conventional Commits, scope rules]

## Pull Requests

[PR template, reviewer rules, merge strategy]

## Protected Branches

[main, release/*, etc. and what protection applies]
```

---

## security.md

**Consumed by:** security-audit, angular-engineer, python-engineer, strapi-engineer

**Explainer:** Threat model, auth patterns, known risks, and controls. security-audit reads this before reviewing so it focuses on gaps rather than re-mapping known ground.

```markdown
# Security Context

## Threat Model

[Assets, threat actors, trust boundaries]

## Authentication & Authorisation

[Auth mechanism, token handling, RBAC/ABAC rules]

## Known Risks

[Accepted risks, deferred mitigations, known gaps]

## Controls

[WAF, rate limiting, secrets management, dependency scanning]
```

---

## analytics.md

**Consumed by:** ga4-measurement

**Explainer:** Measurement plan, activation definitions, and event taxonomy. ga4-measurement treats this as the source of truth for event names and reporting audiences.

```markdown
# Analytics Context

## Activation Definition

[What counts as an activated user for this product]

## Key Funnels

[Funnel name → steps → success event]

## Event Taxonomy

| Event | Trigger | Key Parameters |
|---|---|---|
| [event_name] | [when it fires] | [param: value] |

## Reporting Audiences

[Who reads reports and what decisions they make from the data]
```

---

## adr/ (directory)

**Consumed by:** diagnose, tdd, scrutinize

**Explainer:** Architectural decisions with rationale. Skills check this before proposing changes that might contradict past decisions.

One file per decision, named `NNNN-short-title.md`:

```markdown
# ADR-0001: [Title]

**Status:** Accepted | Superseded by ADR-XXXX | Deprecated

## Context

[What problem or constraint prompted this decision]

## Decision

[What was decided]

## Rationale

[Why this option over the alternatives]

## Consequences

[What becomes easier, harder, or different]
```

---

## triage.md

**Consumed by:** triage

**Explainer:** Issue tracker location, label mapping, and project-specific triage rules.

```markdown
# Triage Context

## Issue Tracker

[GitHub / GitLab / Jira / local-markdown]

## Label Mapping

| Canonical Role | Tracker Label |
|---|---|
| needs-triage | [label] |
| needs-info | [label] |
| ready-for-agent | [label] |
| ready-for-human | [label] |
| wontfix | [label] |

## Priority Rules

[What makes something P1 vs P2 in this project]

## Out-of-scope Patterns

[Known categories that are always wontfix]
```

---

## post-mortem.md

**Consumed by:** post-mortem, diagnose

**Explainer:** Recurring failure patterns and past incident summaries. diagnose reads this to avoid re-investigating known root causes.

```markdown
# Post-mortem Context

## Recurring Failure Patterns

- [Pattern name] — [brief description, last seen date]

## Past Incidents

| Date | Title | Root Cause | Fix |
|---|---|---|---|
| [date] | [title] | [RCA summary] | [link or description] |

## High-risk Areas

[Parts of the codebase that have caused repeated incidents]
```

---

## learning.md

**Consumed by:** diagnose, tdd, angular-engineer, python-engineer

**Explainer:** Gotchas, non-obvious facts, and lessons learned. Skills read this to avoid repeating known mistakes.

```markdown
# Learning Context

## Gotchas

- [Non-obvious behaviour or footgun, and how to avoid it]

## Non-obvious Facts

- [Fact about the codebase or infrastructure that would surprise a newcomer]

## Lessons Learned

- [Lesson from past mistakes, with brief context]
```
