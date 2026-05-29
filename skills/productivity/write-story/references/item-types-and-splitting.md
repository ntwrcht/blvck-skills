# Item Types and Splitting

Use this reference when choosing item types or decomposing large work.

## Item Types

### Epic

Use an epic when the requested outcome spans multiple independently deliverable changes.

Include:

- Business or user outcome.
- Clear boundaries.
- Child items grouped by capability or delivery phase.
- Exit criteria for closing the epic.

### Story

Use a story when the work delivers user-visible or workflow-visible value.

Use the story format when it clarifies the work. For internal platform work, a plain goal is often clearer than forcing a user-story shape.

### Task or Chore

Use a task for implementation work with a known outcome. Use a chore for maintenance that preserves existing behavior.

Acceptance criteria should describe completed state and verification, not implementation steps.

### Bug

Use a bug when actual behavior differs from expected behavior.

Include:

- Current behavior.
- Expected behavior.
- Reproduction steps, if known.
- Environment, version, or affected segment, if known.
- Regression risk and validation path.

### Spike

Use a spike when the work is discovery, research, or de-risking.

Acceptance criteria should be time-boxed or deliverable-based:

- Documented options and recommendation.
- Prototype or proof of concept.
- Decision record.
- Follow-up backlog items.

## Splitting Rules

Split work when:

- Different teams or owners would naturally own parts.
- Each part can be shipped, tested, or reviewed independently.
- The item mixes discovery, implementation, migration, and rollout.
- Acceptance criteria are too broad to verify in one pass.

Do not over-split into mechanical subtasks unless the user asks for a task breakdown. Prefer outcome slices over file-by-file or function-by-function tasks.

One item should represent one deployable or reviewable unit of value. If an item needs another item before it has any standalone value, combine them or make the dependency explicit.

Flag an item as a spike when technical investigation is required before estimation or implementation can start.

If the feature would require more than 15 items, suggest epics, phases, or a story map instead of producing an oversized flat list.
