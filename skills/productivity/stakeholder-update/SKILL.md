---
name: stakeholder-update
description: "Draft audience-aware stakeholder updates that clarify status, impact, risks, decisions, and next steps. Use when preparing status reports, sprint summaries, launch notes, risk escalations, executive updates, customer progress notes, or multi-audience variants."
argument-hint: "<update type and audience>"
---

# Stakeholder Update

Draft stakeholder communication that makes current state, impact, risk, decision, and next action clear for the intended audience.

## When to Use

Use this skill for cadence reporting, sprint summaries, launch notes, customer progress updates, risk escalations, and multi-audience versions of the same update.

Use `management-talk` instead when the request is mainly rewriting engineering or team-internal material for leadership, Slack, Jira, email, standup notes, or meeting talking points without a broader status, risk, decision, or audience-routing problem.

When both apply, use this skill first to decide the audience, message, risk framing, and update structure.

## Core Rule

Identify the audience and the update's purpose before drafting. The same facts need different framing, detail, and risk language depending on who needs to act.

If either is unclear, ask the next decision-shaping question with a recommended answer:

```text
Is this for the internal team, management, cross-functional partners, or external customers?
Recommended: [audience], because [evidence from the request].
```

## Workflow

1. Determine the audience: internal team, management, cross-functional partners, external customers, or multiple audiences. Use `references/audience-rules.md` for fit and sanitization.
2. Determine the purpose: inform status, summarize progress, announce launch, escalate risk, request a decision, document a pivot, or provide a customer progress note.
3. Determine the channel: issue tracker, team chat, email, website, document, slides, or meeting notes. Use `references/channel-templates.md` for channel formatting.
4. Gather context from supplied material, `.context/INDEX.md` and relevant domain files such as `.context/project.md`, or authorized tools: goal, progress, impact, metrics, timeline, blockers, decisions, owners, and next milestone.
5. If context is missing, ask only for facts that change the message, decision, risk level, or required action.
6. Draft the update using `references/update-templates.md` when a standard format fits.
7. For risk-heavy updates, apply `references/risk-status.md`.
8. For decision records or decision-needed updates, apply `references/decision-notes.md`.
9. Review for audience fit, outcome-first language, channel fit, specific asks, and sensitive internal references.

## Decision-Shaping Questions

Ask at most one question at a time when the answer blocks a good draft. Prefer these questions:

- Who is the audience, and what do they need to do after reading?
- Is the goal to inform, reassure, escalate, request a decision, or create a record?
- What changed since the last update, and why does it matter?
- What is the current status: Green, Yellow, or Red?
- What decision, owner, deadline, or action should be explicit?

Use the available evidence to recommend an answer when possible, then ask the user to confirm or correct it.

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
- Do not include organization-specific names, customer names, internal project codes, or tool names unless the user supplies them for the draft.

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
