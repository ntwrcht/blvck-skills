---
name: management-talk
description: "Rewrite engineering updates into clear leadership and cross-functional communication while preserving state, impact, ownership, risks, and next steps. Use when drafting Jira comments, Slack posts, standup notes, emails, meeting talking points, or executive summaries from technical source material."
argument-hint: "<technical update, draft, ticket context, or target channel>"
---

# Management Talk

Turn engineer-to-engineer source material into management-ready communication. Keep the facts traceable, explain the business or release impact, and remove code-level detail that does not help the audience make a decision.

## When to Use

Use this skill when the user asks for a leadership version, management update, executive summary, status rewrite, Jira comment, Slack post, standup note, email, or meeting talking points based on technical work.

Use it for audiences such as managers, directors, VPs, PMs, TPMs, release managers, support leads, and cross-functional partners who understand product and system concepts but do not need to read code.

## When Not to Use

- Use `stakeholder-update` when the request is broader program reporting, launch status, sprint summary, or multi-audience status planning rather than rewriting technical material.
- Use `write-a-story` when the output is backlog-ready acceptance criteria, story text, or Jira issue structure.
- Use `post-mortem` when the user needs the full incident or bug writeup first; use this skill afterward for the leadership-facing version.
- Do not make the copy customer-facing, marketing-oriented, legal, finance, or true ELI5 unless the user asks for that audience explicitly.

## Core Rule

Preserve state, impact, owner, next step, validation, risk, workaround, and tracking references. Strip implementation detail unless it is needed to explain consequence or decision.

## Goal Shaping

Before writing, resolve the smallest missing decision:

- Channel: Jira, Slack, standup, email, meeting talking points, or executive summary.
- Reader: leadership, PM/TPM, release manager, support, or mixed cross-functional audience.
- Purpose: inform, unblock, request a decision, explain risk, or record closure.

If one is missing but the source clearly implies it, choose the most likely option and proceed. Ask one short question only when the choice would materially change the draft.

## Translation Rules

- Keep Jira keys, PR numbers, release versions, customer or workload names, product names, team names, and owners.
- Remove function names, file paths, struct fields, code expressions, commit SHAs, environment variables, and line numbers unless the user requests an appendix.
- Translate mechanism into one or two cause-and-effect sentences without overstating certainty.
- Keep concept-level technical terms when they carry useful meaning: race condition, regression, queue, driver, kernel, synchronization, cache, rollout, rollback.
- Preserve unknowns. Say "root cause is still under investigation" when that is the actual state.
- Do not invent impact, owner, validation status, ETA, risk, mitigation, or recommendation.
- Stay blameless, concrete, and active-voice.

## Channel Formats

### Jira Comment or Written Status

Use concise labeled sections. Include only the labels that fit:

- **Status / TL;DR:** current state in one line.
- **Impact:** affected users, customers, releases, or workflows.
- **What changed:** plain-English mechanism at one level of why.
- **Owner:** person/team and primary artifact.
- **Next steps:** ordered actions or decision needed.
- **Workaround / mitigation:** current relief if users are affected.
- **Risk:** real unresolved risks only.

### Slack

Write one message. Start with a bold TL;DR for a top-level post, then add 2-4 short bullets for impact, owner/link, next step, or workaround. For a thread reply, skip the TL;DR and lead with the answer. Prefer one primary link over a link wall.

### Standup

Use 1-3 lines:

`<state> <thing>. <owner or artifact>. <next step>.`

### Email

Use the TL;DR as the subject, then two or three concise paragraphs. End with the next decision point if recipient action is needed.

### Meeting Talking Points

Use short bullets in speaking order. Include only the keys, names, and numbers the speaker needs to say aloud.

## Workflow

1. Read the source material and infer channel, reader, and purpose where possible.
2. Ask one clarifying question only if the missing decision changes the format or message.
3. Draft one complete output block in the requested channel format.
4. Keep output print-only unless the user explicitly asks to post and a suitable tool is available.
5. For Jira posting, show the exact comment body first and wait for explicit approval such as "post it" or "go ahead".
6. Never post to Slack, email, or non-Jira channels from this skill; provide the draft for the user to send.
7. If the user asks to persist the draft, write `.context/management-update.md` or `.context/management-update-<ticket-or-topic>.md` when the topic is specific.

## Review Checklist

- Does the first line answer what changed or what state the work is in?
- Are impact, owner, next step, and risk explicit when known?
- Are tracking references preserved?
- Is code-level detail removed or translated?
- Are unknowns and uncertainty represented honestly?
- Is the format appropriate for the selected channel?
