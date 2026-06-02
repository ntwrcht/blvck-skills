# Decision Notes

Use decision notes for decisions that affect strategy, architecture, commitments, customer experience, or future options.

Use a decision-needed update when stakeholders must choose before work can continue. Use a compact decision note after the choice is made and needs to be recorded.

## Compact Decision Format

```text
# [Decision Title]

Status: [Proposed / Accepted / Superseded]

Context:
[What situation requires a decision?]

Decision:
[What was decided?]

Consequences:
- [Positive consequence]
- [Tradeoff or constraint]

Alternatives considered:
- [Option] - [Why it was not chosen]
```

## Decision Needed Format

Use this when the update needs a stakeholder decision.

```text
Decision needed: [Decision]

Context:
- [Why this decision matters now]
- [Constraint, deadline, or dependency]

Options:
- [Option A] - [Tradeoff]
- [Option B] - [Tradeoff]

Recommendation:
- [Recommended option] because [reason]

Needed by:
- [Date] to avoid [impact]
```

## Decision-Shaping Prompt

If the user has not provided enough context, ask one question at a time:

```text
What decision must the stakeholder make?
Recommended: frame it as [decision], because [evidence].
```

Then resolve, in order:

- Deadline or consequence of delay
- Available options
- Recommended option
- Owner of the final decision

## Decision Writing Rules

- State the decision directly.
- Include the deadline when timing matters.
- Recommend an option when there is enough evidence.
- Separate facts from opinion.
- Capture tradeoffs honestly.
- Avoid documenting trivial choices that do not constrain future work.
