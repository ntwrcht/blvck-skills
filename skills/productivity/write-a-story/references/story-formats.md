# Story Formats

Use these formats when drafting or converting backlog items.

## User Stories

Use user stories when a role, persona, permission level, or workflow actor matters.

Format:

```markdown
As a <user or system actor>,
I want <capability>,
so that <outcome>.
```

Follow the 3 C's:

- Card: keep the title and story sentence concise.
- Conversation: include context, assumptions, design references, and implementation notes outside the story sentence.
- Confirmation: make acceptance criteria testable.

Check against INVEST:

- Independent: can be delivered without hidden required siblings.
- Negotiable: describes outcome, not every implementation detail.
- Valuable: provides user, business, operational, or learning value.
- Estimable: has enough context to size or has a spike flagged.
- Small: can fit in a normal sprint when possible.
- Testable: includes observable acceptance criteria.

Only use the story sentence when it clarifies the work. For internal platform work, a plain goal is often clearer than forcing a user-story shape.

## Job Stories

Use job stories when context and motivation matter more than a named user role.

Format:

```markdown
When <situation>,
I want to <motivation>,
so I can <outcome>.
```

Focus on:

- Situation: what is happening when the need appears.
- Motivation: what progress the user or system needs to make.
- Outcome: what becomes possible once the job is complete.

Prefer job stories for JTBD-oriented teams, research-derived needs, workflow pain points, and cross-role features.

## WWA

Use WWA when cross-functional readers need explicit business context.

Format:

```markdown
Why <strategic context>
What <deliverable>
Acceptance <criteria>
```

Structure each item around:

- Why: strategic context, customer problem, business objective, risk reduction, or operational need.
- What: the deliverable or behavior to build.
- Acceptance: testable criteria for completion.

Prefer WWA for roadmap work, platform initiatives, compliance work, migrations, and features where "why now" matters.
