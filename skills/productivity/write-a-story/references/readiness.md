# Readiness and Done

Use this reference when the user asks for Jira-ready, sprint-ready, ready-for-refinement, ready-for-planning, implementation-ready, or readiness review output.

## Acceptance Criteria Rules

- Make criteria observable by QA, product, or another engineer.
- Use Given/When/Then where it improves clarity, especially for user workflows.
- Include negative cases, permissions, error states, loading states, or edge cases when relevant.
- Include analytics, accessibility, security, performance, localization, or rollout criteria when the prompt clearly implies them.
- Avoid criteria that merely restate implementation tasks, such as "code is updated" or "API is changed".
- Treat error handling, permissions, recovery paths, and important edge cases as separate items when they deliver separately testable value.

## Definition of Done

Include a generic Definition of Done when the user asks for Jira-ready, sprint-ready, or implementation-ready story output.

Use this default checklist unless the user provides a team-specific DoD:

```markdown
## Definition of Done

- [ ] Acceptance criteria verified in the target environment
- [ ] Relevant automated tests added or updated
- [ ] Regression risk reviewed
- [ ] Code reviewed and merged
- [ ] Documentation, release notes, or support notes updated if applicable
- [ ] Analytics, accessibility, security, or performance checks completed if applicable
```

For non-code work, adapt the checklist to the artifact being delivered. Do not force code review or automated tests onto research, design, support, or operations tasks unless they apply.

## Sprint Readiness Score

Use a Sprint Readiness Score when the user asks whether a story is ready, asks for sprint planning, asks for refinement, asks for Jira-ready output, or asks to assess an existing story.

Evaluate each readiness item as:

- Confirmed: verifiable from the story content.
- Needs team input: cannot be determined from the available information.
- Blocked: a clear failure that should be fixed before sprint commitment.

Fix blocked items before presenting when possible. Surface team-input items as explicit flags.

Score one point for each confirmed item:

| # | Criterion |
|---|---|
| 1 | Story has a clear actor, goal, and outcome |
| 2 | Value or "so that" outcome is explicit |
| 3 | Title describes user, business, operational, or learning value rather than implementation detail |
| 4 | Acceptance criteria are testable |
| 5 | Story appears small enough for one sprint |
| 6 | Dependencies are identified or marked unknown |
| 7 | Estimate is provided, or spike-needed is flagged |
| 8 | Design, content, data, or approval readiness is identified when applicable |
| 9 | Rollout, analytics, security, accessibility, or performance considerations are identified when applicable |
| 10 | Open questions are visible and specific |

Interpretation:

- 8-10: Sprint Ready.
- 5-7: Nearly Ready.
- Below 5: Not Ready.

Use this output shape:

```markdown
## Sprint Readiness

| # | Criterion | Status |
|---|---|---|
| 1 | Clear actor, goal, and outcome | Confirmed |
| 2 | Explicit value or outcome | Needs team input |

**Score:** <n>/10 - <Sprint Ready | Nearly Ready | Not Ready>
```

## Mental Model Triggers

Apply these checks automatically while drafting or reviewing:

| Signal | Action |
|---|---|
| Value or "so that" outcome is vague or missing | Apply JTBD: identify what progress the user, team, or system is trying to make before writing the final story. |
| Story appears larger than one sprint | Flag it and offer to split by journey step, capability slice, risk slice, or user type. |
| Acceptance criteria use vague words like fast, smooth, easy, robust, seamless, intuitive, or user-friendly | Rewrite with observable behavior, thresholds, examples, or measurable outcomes. |
| Story title contains implementation details such as endpoint, schema, refactor, migration, or framework names | Rewrite the title around the user, business, operational, or learning outcome. |
| The item mixes discovery and delivery | Split into a spike plus one or more delivery stories. |
| The item depends on design, content, data, security, legal, or another team | Surface the dependency and mark readiness accordingly. |
