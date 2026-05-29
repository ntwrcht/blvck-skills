# Output Templates

Use these templates unless the user provides a team-specific or tracker-specific format.

## Default Item Format

```markdown
**Title:** <action-oriented noun phrase>

**Type:** <Epic | Story | Task | Bug | Spike | Chore>

**Goal:** <one or two sentences describing the desired outcome and why it matters>

**Scope:**
- In: <included behavior/work>
- Out: <explicit exclusions, if known>

**Acceptance criteria:**
- Given <context>, when <action/event>, then <observable result>
- <additional testable criteria>

**Implementation notes:**
- <constraints, suggested approach, affected areas, or references>

**Dependencies / risks:**
- <dependency, risk, or "None known">

**Open questions:**
- <specific question or "None">
```

Omit empty optional sections only when they add no value. Keep `Acceptance criteria` unless the user explicitly asks for a quick title-only draft.

Include `Definition of Done` and `Sprint Readiness` when the user asks for sprint-ready, Jira-ready, ready-for-refinement, ready-for-planning, or readiness review output.

## Feature Breakdown Format

Use this format when the user asks to break a feature into stories or backlog items:

```markdown
## Backlog: <feature name>

**Format:** <User stories | Job stories | WWA | Generic backlog items>
**Total items:** <count>
**Estimated total effort:** <only if enough context exists, otherwise "Not estimated">

### Items

#### Item 1: <short title>
**<story, job story, WWA statement, or item goal>**

**Acceptance criteria:**
- [ ] <criterion 1>
- [ ] <criterion 2>
- [ ] <criterion 3>

**Priority:** <P0 | P1 | P2 | Not set>
**Effort:** <S | M | L | Spike needed | Not estimated>
**Dependencies:** <none or list>

---

### Story Map
- Must-have: <ordered item titles>
- Should-have: <ordered item titles>
- Nice-to-have: <ordered item titles>

### Technical Notes
- <cross-cutting concerns, API changes, data migration, rollout, analytics, security, accessibility, or infrastructure>

### Open Questions
- <specific questions blocking implementation or estimation>
```

Default to chat output. Save as a markdown file only when the user asks to save, export, persist, or create a file.
