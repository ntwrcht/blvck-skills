---
name: handoff
description: "Compacts the current conversation into a handoff document so a fresh agent can continue the work without losing context. Use when switching sessions, handing off to another agent, ending a long conversation, or preparing a context brief for a follow-up run."
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

# Handoff

Produce a compact handoff document from the current conversation so a fresh agent can resume without re-deriving context.

## When to Use

Use when the user wants to end a session and continue later, switch to a new agent instance, share conversation context with a collaborator, or prepare a focused brief for a follow-up task.

Do not reproduce content already captured in durable artifacts — PRDs, ADRs, plans, issues, commits, diffs. Reference those by path or URL. Use `triage` when the goal is to classify or move tracker issues. Use `write-a-prd` or `write-a-story` when the goal is to produce a new product artifact, not summarise a session.

## Output

Save the document to the OS temp directory, never to the working directory or repository. Use `$TMPDIR` on macOS/Linux or `%TEMP%` on Windows. Name the file `handoff-<YYYY-MM-DD>.md`.

Tell the user the full file path when done.

## Document Structure

```
# Handoff — <date>

## Focus
<One sentence: what the next session will do. Derived from the user's argument if provided; otherwise inferred from the conversation.>

## State
<What is done, what is in progress, and what is blocked. Three to seven bullets.>

## Key Decisions
<Decisions made during this session that the next agent must honour. Skip if none.>

## Open Questions
<Unresolved questions or risks the next agent should address first. Skip if none.>

## References
<Paths or URLs to existing artifacts — PRDs, ADRs, issues, diffs, plans, commits — that the next agent should read before starting. Never copy their content here.>

## Suggested Skills
<Skills from the available skill set that the next agent should consider invoking, with one line of reasoning for each.>
```

## Rules

- **Tailor to the focus.** If the user passed arguments, treat them as the next session's goal and shape every section to serve that goal. Omit sections irrelevant to it.
- **Reference, don't duplicate.** Any content already in a file, issue, commit, or diff belongs in References, not reproduced inline.
- **Redact.** Remove API keys, passwords, tokens, secrets, and personally identifiable information before writing. Replace with `[REDACTED]`.
- **Be brief.** The document is a briefing, not a transcript. Cut anything the next agent can re-derive by reading the codebase or referenced artifacts.
- **Suggest skills concretely.** In Suggested Skills, name the exact skill and explain in one sentence why it applies to the next session's focus.
