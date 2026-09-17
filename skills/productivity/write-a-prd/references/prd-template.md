# PRD Template

Use this template for `write-a-prd` output. Keep the structure stable unless the user provides a project-specific PRD template.

## Formatting Rules

- Write from the user's perspective first, then add implementation and testing decisions for handoff.
- Preserve project vocabulary, domain terms, ADR decisions, and known constraints from the repository.
- Label assumptions, unknowns, and unresolved decisions explicitly.
- Do not include specific file paths or code snippets in implementation decisions.
- Exception: include a trimmed prototype snippet only when it captures a decision more precisely than prose, such as a state machine, reducer, schema, or type shape. Note that it came from a prototype.
- Keep user stories at scope level: three to eight lines that bound the feature, with no acceptance criteria and no task breakdown.
- Group them by actor when the feature has more than one actor.

## Template

```md
## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## Success Metrics

How we will know the solution worked, as a metric tree from outcome down to signal.

- **North Star:** the one metric this feature is meant to move, or the existing product North Star it contributes to. Name it, its direction, and the mechanism — how a user getting the Solution above shows up in this number.
- **L1 metrics:** the two to four drivers of the North Star this feature touches. Each one: definition, direction, baseline, target.
- **L2 metrics:** the leading indicators that move first — adoption, completion, error, or time signals per L1.
- **Guardrails:** metrics that must not get worse (latency, support volume, churn, cost).

Every metric row carries: definition, direction, baseline, target, and the event or data source that produces it. A baseline or target the conversation and repo do not supply is written as `UNKNOWN`, never estimated — an invented target becomes a commitment nobody agreed to. Read `.context/analytics.md` first when it exists: reuse its activation definition and event names rather than inventing parallel ones.

## User Stories

A numbered list that bounds the feature — the smallest set that shows a reviewer what it covers. Each story uses this format:

1. As an <actor>, I want a <feature>, so that <benefit>

Write three to eight, one per distinct actor-and-outcome pair, grouped by actor when the feature has more than one. Cover the primary workflow, plus any secondary or operational workflow a reviewer would otherwise ask about.

Leave out acceptance criteria, task breakdowns, estimates, and edge-case enumeration. This list settles scope before approval; `write-a-story` turns it into implementation-ready items with acceptance criteria after.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- Modules or system areas that will be built or modified.
- Interfaces, contracts, or integration points that will change.
- Technical clarifications from the developer.
- Architectural decisions.
- Schema changes.
- API contracts.
- Specific interactions.

Do not include specific file paths or code snippets. They may become outdated quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can, inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts.

## Testing Decisions

A list of testing decisions that were made. Include:

- What makes a good test for this feature.
- How tests should focus on external behavior instead of implementation details.
- Which modules, surfaces, or system seams will be tested.
- Prior art for similar tests in the codebase.

## Out of Scope

A description of the things that are out of scope for this PRD.

## Further Notes

Any further notes about the feature, including assumptions, dependencies, open questions, risks, rollout considerations, or follow-up work.
```
