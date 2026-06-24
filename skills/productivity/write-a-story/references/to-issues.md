# To Issues

Use this reference when converting a plan, spec, PRD, or parent issue into independently grabbable implementation issues.

## When to Use

Use this mode for requests such as "turn this plan into issues", "create implementation tickets", "break this PRD into issues", or "split this feature into tracer bullets".

Use the normal feature breakdown flow when the user only wants draft backlog items in chat. Use `grill-me` first when the plan is too vague to identify goals, constraints, or major decisions.

## Context

Work from the current conversation first. If the user provides an issue reference, URL, or path, fetch or read the full body and relevant comments before slicing.

Explore the codebase when needed to use the project's domain vocabulary, respect ADRs, and avoid issue titles that do not match the current system. Do not explore when the supplied context is already enough for a useful tracker-neutral draft.

When exploring, look for prefactoring opportunities — changes that make the planned implementation easier without delivering the feature itself. "Make the change easy, then make the easy change." If prefactoring is warranted, propose it as its own slice, ordered first.

## Vertical Slice Rules

Break the plan into tracer-bullet issues:

- Each issue delivers a narrow but complete path through the needed integration layers.
- Each issue is demoable or verifiable on its own.
- Prefer many thin slices over a few broad slices.
- Avoid horizontal slices such as "database only", "API only", or "UI only" unless that work is independently valuable.
- Mark a dependency when a slice cannot start or cannot be verified until another slice lands.

Classify slices as:

- `AFK`: can be implemented and merged without human interaction once assigned.
- `HITL`: requires human input such as an architecture decision, design review, policy choice, data access, or product signoff.

Prefer `AFK` where the dependency can be resolved through existing docs, code, tests, or project conventions.

## Review Loop

Before publishing issues, present the proposed breakdown as a numbered list. For each slice, include:

- **Title:** short descriptive name.
- **Type:** `HITL` or `AFK`.
- **Blocked by:** prerequisite slices, or `None`.
- **User stories covered:** source user stories addressed, if the source material has them.

Ask the user to review granularity, dependencies, merges or splits, and HITL/AFK classification. Iterate until the user approves the breakdown.

## Publishing Rules

Create or publish tracker issues only when a suitable issue-tracker tool is available and the user has explicitly approved the breakdown and payload.

Publish issues in dependency order, blockers first, so later issues can reference real issue identifiers. Do not close, modify, or transition the parent issue unless the user explicitly asks.

Use the project's known tracker fields and triage label vocabulary when provided. If required tracker fields or labels are missing, ask only for the missing required data.

## Issue Body Template

```markdown
## Parent

<Reference to the parent issue, if the source was an existing issue. Omit this section otherwise.>

## What to build

<Concise end-to-end behavior for this vertical slice. Describe the outcome, not a layer-by-layer checklist.>

## Acceptance criteria

- [ ] <criterion 1>
- [ ] <criterion 2>
- [ ] <criterion 3>

## Blocked by

<References to blocking tickets, or "None - can start immediately".>
```

Avoid file paths and code snippets in issue bodies because they go stale quickly. Exception: include a trimmed prototype snippet only when it captures a decision more precisely than prose, such as a state machine, reducer, schema, or type shape.
