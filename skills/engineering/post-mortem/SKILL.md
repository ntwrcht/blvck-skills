---
name: post-mortem
description: >
  Write the canonical engineering record of a fixed and validated bug: summary,
  symptom, root cause, mechanism, fix, validation, and why it slipped through.
  Use after a debug session lands a real fix, before closing the ticket. Trigger
  on /post-mortem, postmortem, RCA, root cause analysis, document this fix, write
  up the root cause, close out this bug with a writeup, or when the user hands
  over a fixed-and-validated bug and asks for an engineering writeup.
---

# Post-mortem

Write the engineering record of a bug fix after debugging has landed a real, validated fix. The audience is other engineers and future maintainers. Code identifiers are welcome because this artifact should let someone recover the mental model quickly.

This skill pairs with `debug-mantra`: use the repro, fail path, falsified hypotheses, and experiment ledger as raw material. For a leadership version, hand the finished engineering record to `management-talk`.

## When to Use

- `/post-mortem`
- "write the post-mortem", "postmortem", "RCA", or "root cause analysis"
- "document this fix", "write up the root cause", or "close out this bug with a writeup"
- After a debug session clearly lands and validates a fix, proactively offer to draft one.

## When Not to Use

- The bug is not fixed or the fix is not validated. Refuse to draft and list what is missing.
- The event is a customer-visible outage or incident. Flag that it may need an incident report with timeline, blast radius, paging history, and communications.
- The fix is trivial, such as a typo or obvious one-liner. Suggest using the PR description as the record.

## Required Inputs

Before drafting, confirm all four. If any are missing, list the missing items and stop.

- Reliable repro exists.
- Root cause is known and is not just a hypothesis.
- Fix is identified, such as PR, commit, branch, or patch.
- Fix is validated against the original repro or affected workload.

Never write a post-mortem of a hypothesis.

## Structure

Use these sections in order. Summary, Root cause, Fix, and Validation are mandatory. Include the others when facts exist.

### Summary

One paragraph. What broke in user or workload terms, what fixed it, and the main tracking references: ticket, PR, owner.

### Symptom

What was observed: test output, error message, log line, performance number, customer report, or workload behavior. Use concrete identifiers.

### Root Cause

The actual bug mechanism. Include file paths, function names, branch conditions, struct fields, commit SHAs, and other grep-able identifiers when they matter. Walk the cause chain end-to-end.

### Why It Produced the Symptom

Connect the root cause to the visible failure. Explain why the symptom appeared where it did and why the actual bug may live elsewhere.

### Fix

What changed and why that change addresses the root cause rather than hiding the symptom. Link or name the PR, commit, branch, or patch. If a prior fix attempt papered over the symptom, name it and explain what was incomplete.

### How It Was Found

Keep this short and learnable:

- What repro made it deterministic.
- What tools or tactics narrowed the path: debugger, source trace, knob enumeration, or instrumentation.
- Hypotheses tried and rejected, with one-line reasons.
- The experiment that confirmed the cause.

### Why It Slipped Through

Describe the real gap, blamelessly:

- CI gap.
- Latent code path.
- Workload or configuration gap.
- Incomplete prior fix.
- Review miss.
- No good reason; it should have been caught.

### Validation

How we know the fix works. Be concrete:

- Original failing test now passes.
- Customer workload now completes.
- Performance number before and after.
- Stress, soak, or fuzz run completed cleanly.
- Other affected configurations tested.

If only one configuration was validated, say so explicitly. Never imply broader coverage than exists.

### Action Items / Follow-ups

Concrete items not already in the fix PR. Each item should include what, owner, and tracking artifact when known.

If none are warranted, write: `None — the fix is sufficient and no class-of-bug follow-up is warranted.`

## Tone

- Engineer-to-engineer.
- Code identifiers are first-class.
- Mechanism over narrative.
- Active voice, concrete subjects, short paragraphs.
- No hedging: state it or leave it out.
- Blameless: describe bugs and gaps, not personal failures.
- No advocacy unless the user asks for a proposal.

## Output Flow

1. Confirm the four required inputs are satisfied. If any are missing, stop.
2. Confirm destination if it affects formatting. Default is print-only chat output. Other common destinations: ticket comment, PR description, `docs/postmortems/<ticket>.md`, or internal wiki.
3. Produce the draft as a single chat block.
4. Default to print-only output. Do not post externally unless a suitable tool is available and the user explicitly asks you to post.
5. If a Jira-capable tool is available and the user explicitly asks to post to Jira:
   - Show the exact comment body or payload that will be posted.
   - Wait for explicit approval such as "post it", "go ahead", or "yes".
   - Only then use the available Jira tool to post.
   - If posting fails, report the failure and leave the draft in chat.
6. If the user asks to create a file, use the artifact convention below unless they provide a destination path.
7. Offer the `management-talk` handoff: "Want a leadership-flavored version?"

## Rules

- Refuse to draft without all four required inputs.
- Never invent root cause, owner, validation runs, or action items.
- Never strip code identifiers from the engineering record.
- State validation coverage honestly.
- Keep it blameless.
- Get explicit sign-off before posting to Jira. Print-only output needs no approval.
- One revision is normal. If the user requests a third pass, ask what specific section is wrong.

## Optional Context Artifact

Default to chat output. If the user asks to persist, hand off, or reuse the post-mortem, write or update `.context/post-mortem.md` in the current workspace.

If a ticket key, PR number, incident key, or clear topic is available, suggest a named durable file such as `docs/postmortems/<ticket-or-topic>.md` or `.context/post-mortem-<ticket-or-topic>.md`.

Use the stable `.context/post-mortem.md` path only when it appears to belong to the same active bug. Ask before overwriting unrelated content. If no clear workspace exists, keep the draft in chat unless the user provides a path.
