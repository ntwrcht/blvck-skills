---
name: management-talk
description: >
  Rewrite engineer-to-engineer content for engineering-org leadership: VPs,
  directors, PMs, release managers, and execs in an engineering-savvy company.
  Shape the message for JIRA comments, Slack posts, async standup lines, email,
  or meeting talking points. Use when the user asks to write or rewrite for
  management, execs, VPs, directors, PMs, release managers, asks for an executive
  summary, leadership update, status update, says to make something less
  technical or less jargony, or asks for a Slack, email, standup, or meeting
  version of engineering work.
---

# Management Talk

Rewrite engineering content for leadership and cross-functional audiences who understand product and system concepts but do not read code. Preserve state, impact, owner, next step, and tracking references. Remove function-level detail.

## When to Use

- Writing for management, execs, VPs, directors, PMs, or release managers.
- Creating an executive summary, leadership update, status update, Slack update, standup note, email, or meeting talking points.
- Rewriting engineer-to-engineer text to be less technical, less jargony, or more suitable for a non-code-reading audience.

If the channel is unclear, ask one short question: "JIRA, Slack, standup, email, or meeting talking points?"

## Audience

Engineering-org leadership reads product names, framework names, JIRA keys, PR numbers, customer identifiers, workload names, and team-owned component names. They do not need function names, file paths, struct fields, commit SHAs, code expressions, environment variable names, or line numbers.

They want to know:

- What is the current state?
- What is the customer or release impact?
- Who owns it?
- What happens next?
- Is there a workaround, mitigation, or risk?

This is not for marketing, finance, customer-facing, or true ELI5 copy. Flag that mismatch and confirm before producing the rewrite.

## Translation Rules

- Keep tracking bridges: JIRA keys, PR numbers, customer/workload names, product names, release versions, and owner/team names.
- Strip code-level identifiers unless the audience specifically asked for an engineering appendix.
- Translate mechanism into one or two plain-English cause-and-effect sentences without lying.
- Keep concept-level terms when useful: race condition, synchronization, uninitialized buffer, fast path, regression, workaround, queue, driver, kernel.
- Use active voice and concrete subjects.
- Do not invent facts, owners, validation status, ETA, impact, or risk.
- Do not advocate. Record state and next steps; make recommendations only if the user asks for a recommendation.

## Channel Shapes

### JIRA Comment or Written Status

Use a structured block with bold labels. Pick the blocks that fit:

- **Status / TL;DR:** one line the reader can stop at.
- **Impact:** who is affected and what they see.
- **What broke:** plain-English mechanism, one level of why.
- **Why now / how it slipped through:** include only when leadership will ask anyway.
- **Owner:** person/team and one primary artifact.
- **Next steps:** concrete and ordered.
- **Workaround / mitigation:** if users are affected now.
- **Risk:** real risks only.

### Slack

Use a single message:

- First line is a bold TL;DR for a top-level post.
- Add 2-4 short bullets for impact, owner/link, next step, workaround.
- Use one primary link, not a link wall.
- No greeting or signoff.
- For a thread reply, skip the TL;DR and lead with the answer.
- Target under about 80 words for a top-level post and under about 40 for a thread reply.

### Async Standup

Use 1-3 lines:

`<state> <thing>. <owner if not me>. <next>.`

Example: `Fixed Tada hang affecting dumbModel runs (JIRA-12345). PR #5751 in review. Backport to v7.2 next.`

### Email

- Subject is the TL;DR as a noun phrase.
- Use a matching greeting.
- Use two or three concise paragraphs.
- End with the next decision point if one needs recipient attention.

### Meeting Talking Points

- Use bullets, one short clause each.
- Order bullets in speaking order.
- Include the keys or numbers the speaker needs to say aloud.
- No prose paragraphs.

## Output Flow

1. Confirm the channel if the user did not specify it.
2. Use pasted source material, the current conversation, or a referenced ticket/PR if the user provides enough context. If source material is ambiguous, ask one question and stop.
3. Produce the draft as a single chat block formatted for the channel.
4. Default to print-only output. Do not post to Slack, email, JIRA, or any other external destination unless a suitable tool is available and the user explicitly asks you to post.
5. If a Jira-capable tool is available and the user explicitly asks to post to Jira:
   - Show the exact comment body or payload that will be posted.
   - Wait for explicit approval such as "post it", "go ahead", or "yes".
   - Only then use the available Jira tool to post.
   - If posting fails, report the failure and leave the draft in chat.
6. Never post to Slack, email, or any non-Jira channel from this skill. Hand the draft to the user for those channels.
7. One revision is normal. If the user requests a third pass, ask what audience or framing assumption is wrong before tweaking again.

## Rules

- Never invent facts to make the rewrite cleaner.
- Never remove JIRA keys, PR numbers, customer/workload names, owners, or release versions.
- Never invent owners or ETAs.
- Preserve "root cause unknown" if that is the actual state.
- Get explicit sign-off before posting to Jira. Print-only output needs no approval.
- Never post to Slack, email, or any non-Jira channel.
- Avoid hedging unless uncertainty is real.
- Stay blameless and concrete.

## Optional Context Artifact

Default to chat output. If the user asks to persist, hand off, or reuse the leadership-facing update, write or update `.context/management-update.md` in the current workspace.

Use a named file such as `.context/management-update-<ticket-or-topic>.md` when the update is tied to a specific ticket, release, incident, or topic and the default file already appears unrelated.

Do not create files by default. If no clear workspace exists, keep the draft in chat unless the user provides a path.
