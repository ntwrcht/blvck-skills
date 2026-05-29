---
name: stakeholder-update
description: Audience-aware workflow for stakeholder updates, status reports, sprint summaries, launch notes, risk escalations, executive updates, customer progress notes, and multi-audience variants.
argument-hint: "<update type and audience>"
---

# Stakeholder Update

Generate stakeholder updates tailored to audience, cadence, and delivery channel.

Keep organization-specific names, customer names, internal project codes, and tool names out of this skill. If that context is needed to draft the update, ask the user for it directly.

## Relationship to Rewrite Skills

Use this skill when the work is a stakeholder update: cadence reporting, sprint summaries, launch notes, customer progress updates, risk escalations, or multi-audience versions of the same update.

If a separate leadership rewrite skill is available, use it when the work is specifically rewriting technical or team-internal content for management. In this repo, that skill is `management-talk`.

When both apply, use this skill to choose the audience, message, risk framing, and update structure. Then use the channel guidance here, or hand off to the rewrite skill for a management-specific rewrite.

## Usage

```text
/stakeholder-update $ARGUMENTS
```

## Core Rule

Always identify the audience before drafting. Ask: "Is this for the internal team, management, cross-functional partners, or external customers?"

Do not assume the audience. The same facts need different framing, detail, and risk language for each group.

## Workflow

1. Determine the audience. Use `references/audience-rules.md` if the audience is ambiguous or the output must be sanitized.
2. Determine the update type: sprint summary, weekly or monthly status, launch announcement, escalation, risk flag, pivot, or decision update.
3. Determine the delivery channel: issue tracker, team chat, email, website, document, slides, or meeting notes. Use `references/channel-templates.md` for channel formatting.
4. Gather context from available connected tools if the user has authorized them.
5. If required context is missing, ask the user for accomplishments, blockers or risks, key decisions, next steps, audience-specific names, and any required metrics.
6. Draft the update. Use `references/update-templates.md` for sprint, executive, engineering, partner, and customer templates.
7. For status or risk-heavy updates, use `references/risk-status.md`.
8. For decision records or decision-needed updates, use `references/decision-notes.md`.
9. Review the draft for audience fit, outcome-first language, channel fit, and sensitive internal references.
10. Ask whether the user wants a different tone, detail level, emphasis, or delivery format.

## Context Gathering

When relevant tools are available, use them to collect:

- Completed work since the last update
- Items currently at risk or blocked
- Decisions made or needed
- Milestones, launch dates, or sprint progress
- Metrics, customer impact, or operational impact
- Follow-ups from recent discussions, meeting notes, or planning documents

If connected tools are not available or do not include enough context, ask the user for the same facts directly.

## Output Rules

- Lead with the outcome, not the activity.
- Use plain language for management, partners, and customers.
- Keep management updates under 200 words and at most 5 bullets.
- Remove internal references from customer-facing updates.
- End every update with what is coming next and any decisions or actions needed.
- If there is bad news or a meaningful risk, surface it early.
- Make asks specific: owner, decision, deadline, and recommendation when possible.
- Default to draft-only output. Do not post to an issue tracker, chat tool, email system, website, or any external destination unless a suitable tool is available and the user explicitly asks to post.
- Before posting through any connected tool, show the exact message and wait for explicit approval.

## Reference Map

- `references/audience-rules.md`: audience tiers, what each group cares about, and sanitization rules.
- `references/channel-templates.md`: issue tracker, team chat, email, website, document, and slide formatting.
- `references/update-templates.md`: sprint summary, leadership, engineering, partner, and customer templates.
- `references/risk-status.md`: Green/Yellow/Red status and risk communication.
- `references/decision-notes.md`: compact decision note and ADR format.

## Final Review Checklist

Before delivering the update:

- Does the first line tell the reader what matters most?
- Is every bullet tied to an outcome, decision, risk, or next action?
- Is the language appropriate for the audience?
- Are sensitive internal names and private references removed when needed?
- Are asks specific and time-bound?
- Does the update end with next steps?
