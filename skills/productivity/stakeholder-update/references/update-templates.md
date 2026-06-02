# Update Templates

## Message Frame

Use this frame before choosing a template:

```text
Audience: [reader]
Purpose: [inform / reassure / escalate / request decision / record decision]
Status: [Green / Yellow / Red, if relevant]
Main message: [one sentence]
Ask or next action: [owner, action, date]
```

If the update has no ask, make the next milestone explicit.

## Sprint Summary

Use this format for sprint summaries. Adjust detail by audience.

```text
Sprint [N] - [Start date] to [End date]
Goal: [one sentence, outcome-focused]
Status: [Green / Yellow / Red, if useful]

Completed:
- [Feature or fix] - [user or business impact]
- [Feature or fix] - [user or business impact]

In progress / carried over:
- [Item] - [reason if delayed]

Next sprint focus:
- [1-2 sentences on what the next sprint is aiming to achieve]
```

For management and external customers, drop carried-over items that have no audience impact and reframe completed work as business or user outcomes.

## Executive / Leadership Update

Use this when the reader needs strategic context, risk visibility, or a decision.

```text
Status: [Green / Yellow / Red]

TL;DR: [One sentence with the most important thing to know]

Progress:
- [Outcome achieved, tied to goal]
- [Milestone reached, with impact]
- [Metric movement, if available]

Risks:
- [Risk]: [Mitigation plan]. [Ask if needed].

Decisions needed:
- [Decision]: [Options with recommendation]. Need by [date].

Next milestones:
- [Milestone] - [Date]
```

Keep it concise. Only include risks that affect a decision, timeline, customer, or commitment.
If the status is Yellow or Red, move `Risks` before `Progress`.

## Engineering Team Update

Use this when the reader needs working context, priority changes, or concrete next actions.

```text
Shipped:
- [Feature/fix] - [Link to ticket, pull request, document, or artifact if available]. [Impact if notable].

In progress:
- [Item] - [Owner]. [Expected completion]. [Blockers if any].

Decisions:
- [Decision made]: [Rationale]. [Link if available].
- [Decision needed]: [Context]. [Options]. [Recommendation].

Priority changes:
- [What changed and why]

Coming up:
- [Next items] - [Context on why these are next]
```

## Cross-Functional Partner Update

Use this for design, marketing, sales, support, operations, or other partner teams.

```text
What's coming:
- [Feature/launch] - [Date]. [What this means for your team].

What we need from you:
- [Specific ask] - [Context]. By [date].

Dependencies:
- [Dependency] - [Owner]. [Impact if missed].

Decisions made:
- [Decision] - [How it affects your team].

Open for input:
- [Topic for feedback] - [How to provide it].
```

## Customer / External Update

Use this for customer-facing progress notes, launch updates, and account updates.

```text
What's new:
- [Feature] - [Benefit in customer terms]. [How to use it or where to learn more].

Coming soon:
- [Feature] - [Expected timing]. [Why it matters].

Known issues:
- [Customer-impacting issue] - [Status]. [Workaround if available].

Feedback:
- [How to share feedback or request help]
```

Do not include internal project names, ticket IDs, architecture details, tool names, or team process unless the customer explicitly needs that information.
For customer risks, state only customer-visible impact, mitigation, timing, and workaround.
