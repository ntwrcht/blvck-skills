---
name: stakeholder-comms
description: "Writes communication for leadership, cross-functional partners, and customers — gathering the facts first when nobody has written them down, or rewriting existing engineering source material for a new audience and register. Use when a status report, sprint summary, launch note, risk escalation, executive summary, customer progress note, Jira comment, Slack post, standup note, email, or meeting talking points is needed."
argument-hint: "<update type and audience, or the source material to rewrite>"
---

# Stakeholder Comms

Make current state, impact, risk, decision, and next action clear for the people who have to act on them.

## When to Use

Use this skill for any audience-facing update: cadence reporting, sprint summaries, launch notes, customer progress updates, risk escalations, leadership versions of engineering work, executive summaries, Jira comments, Slack posts, standup notes, emails, meeting talking points, and multi-audience versions of the same update.

## When Not to Use

- Use `write-a-story` when the output is backlog-ready acceptance criteria, story text, or Jira issue structure.
- Use `post-mortem` when the user needs the full incident or bug writeup first; use this skill afterward for the leadership-facing version.
- Use `doc-coauthoring` when the deliverable is a long-form proposal, spec, or RFC built section by section from context only the user holds — not an update.
- Use `write-user-docs` when the audience needs instructions rather than a status or outcome.

## Artifacts

- Produces: communication artifact (chat, or a doc at the `stakeholder-comms` key path on request — see `references/artifact-paths.md`, default `.context/stakeholder-comms/<slug>.md`)
- Consumes: technical source material when it exists, `docs/prd.md` (if present), `docs/postmortems/<topic>.md` (if present), `.context/project.md`, `.context/INDEX.md`

## Core Rule

Identify the audience and the update's purpose before drafting. The same facts need different framing, detail, and risk language depending on who needs to act.

If either is unclear, ask the next decision-shaping question with a recommended answer:

```text
Is this for the internal team, management, cross-functional partners, or external customers?
Recommended: [audience], because [evidence from the request].
```

## Pick a branch

One question decides where the work starts, and it is answerable by looking rather than asking:

> **Is there already written source material to work from?**

- **Yes** — a ticket, a postmortem, a Slack thread, an engineer's draft, a commit series. The facts are settled; the work is audience and register. **Skip Step 4** and load `references/rewriting-source.md`, which carries what to preserve, strip, and translate.
- **No** — the facts live across tickets, dashboards, commits, and people's heads, and nobody has written them down. **Step 4 is the work**: establish the facts before framing them.

Step 4 is the tell in both directions. When it has nothing to gather because the source already says it all, the answer was yes. When the "source" turns out to be a fragment that leaves impact, owner, or status unknown, the answer was no — go gather.

## Workflow

1. Determine the audience: internal team, management, cross-functional partners, external customers, or multiple audiences. Use `references/audience-rules.md` for fit and sanitization.
2. Determine the purpose: inform status, summarize progress, announce launch, escalate risk, request a decision, document a pivot, close something out, or provide a customer progress note.
3. Determine the channel: issue tracker, team chat, email, website, document, slides, standup, or meeting talking points. Use `references/channel-templates.md` for channel formatting.
4. **Gather the facts.** *(No-source branch.)* Read `.context/INDEX.md` when present, then load relevant domain files such as `.context/project.md`. Establish: goal, progress, impact, metrics, timeline, blockers, decisions, owners, and next milestone. Ask only for facts that change the message, decision, risk level, or required action.
5. Draft one complete output block in the chosen channel format, using `references/update-templates.md` when a standard format fits. On the source-exists branch, hold every line to `references/rewriting-source.md` — each fact traces back to the source, and nothing is invented to fill a gap.
6. For risk-heavy updates, apply `references/risk-status.md`. For decision records or decision-needed updates, apply `references/decision-notes.md`.
7. Review for audience fit, outcome-first language, channel fit, specific asks, and sensitive internal references.

If the user asks to persist the draft, write it to the `stakeholder-comms` key path (see `references/artifact-paths.md`).

## Decision-Shaping Questions

Ask at most one question at a time, and only when the answer blocks a good draft. On the source-exists branch, infer from the source first and ask only when the missing decision would change the format or the message. Prefer these questions:

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
- Post only through a connected issue-tracker tool. Provide chat, email, and every other channel as a draft for the user to send.
- Do not include organization-specific names, customer names, internal project codes, or tool names unless the user supplies them for the draft.

## Reference Map

- `references/rewriting-source.md`: the source-exists branch — what to preserve, strip, translate, and never invent.
- `references/audience-rules.md`: audience tiers, what each group cares about, and sanitization rules.
- `references/channel-templates.md`: issue tracker, team chat, email, website, document, slides, standup, and meeting talking points.
- `references/update-templates.md`: sprint summary, leadership, engineering, partner, and customer templates.
- `references/risk-status.md`: Green/Yellow/Red status and risk communication.
- `references/decision-notes.md`: compact decision note and ADR format.
- `references/artifact-paths.md`: where a persisted update gets written.

## Final Review Checklist

Before delivering the update:

- Does the first line tell the reader what matters most?
- Is every bullet tied to an outcome, decision, risk, or next action?
- Is the language appropriate for the audience?
- Are sensitive internal names and private references removed when needed?
- Are asks specific and time-bound?
- Does the update end with next steps?
- On the source-exists branch: does every fact trace back to the source?

## Next Step

Before posting through any connected tool, show the exact message and wait for explicit approval.

- **If approved:** post through the connected tool (already stated). If this was the leadership-facing follow-up to `post-mortem`, no further hand-off is needed. A later request to re-cut the same update for another audience starts from written source — that is this skill's source-exists branch, not a different skill.
- **If not approved:** revise per feedback — keep as draft-only until approval is explicit.
