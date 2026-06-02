---
name: post-mortem
description: "Write engineering post-mortems for fixed and validated bugs with symptom, root cause, mechanism, fix, validation, and follow-ups. Use when closing a bug, drafting an RCA, documenting a fix, or converting a debug ledger into a maintainer-readable record."
---

# Post-mortem

Write the engineering record of a bug fix after the cause is known and the fix is validated.

## When to Use

Use this skill for "post-mortem", "postmortem", "RCA", "root cause analysis", "document this fix", "write up the root cause", or after a debug session lands a real fix.

Use `debug-mantra` first when the cause is still uncertain. Use `management-talk` after this skill when the user needs a leadership or cross-functional version.

## When Not to Use

- The bug is not fixed or validation has not run.
- The root cause is still a hypothesis.
- The event is a customer-visible incident that needs a timeline, blast radius, paging history, and communications record.
- The change is a trivial typo or obvious one-liner; a PR note is enough.

## Required Inputs

Confirm these before drafting. If any are missing, list the gap and stop.

- Repro: the original failure was reproduced or otherwise captured.
- Root cause: the mechanism is known, not guessed.
- Fix: a patch, PR, commit, branch, or concrete code change exists.
- Validation: the fix was checked against the original repro or affected workload.

## Project Context

Read `.context/INDEX.md` when present, then load relevant domains such as `.context/project.md`, `.context/post-mortem.md`, `.context/learning.md`, and `.context/adr/` before drafting. Use them for known failure patterns, vocabulary, and past decisions; do not let context override the required evidence above.

## Output Structure

Use these sections in order. Omit optional sections only when no facts exist.

1. **Summary.** One paragraph covering what broke, impact in workload terms, what fixed it, and key references.
2. **Symptom.** Concrete evidence: error text, log line, test output, metric, report, or visible behavior.
3. **Root Cause.** The actual bug mechanism with grep-able identifiers: files, functions, fields, flags, commits, configs, or branch conditions.
4. **Why It Produced the Symptom.** Connect cause to visible failure, especially when the bug lives away from where the symptom appears.
5. **Fix.** What changed and why it addresses the cause rather than hiding the symptom.
6. **How It Was Found.** Repro, trace tools, rejected hypotheses, and the confirming experiment.
7. **Why It Slipped Through.** CI gap, workload gap, latent path, incomplete prior fix, review miss, or "it should have been caught."
8. **Validation.** Exact commands, tests, workloads, before/after numbers, soak/stress/fuzz runs, and untested configurations.
9. **Action Items / Follow-ups.** Concrete item, owner, and tracking artifact. If none: `None - the fix is sufficient and no class-of-bug follow-up is warranted.`

## Style Rules

- Engineer-to-engineer, active voice, short paragraphs.
- Mechanism over narrative.
- Keep code identifiers, paths, and commands.
- Be blameless: describe system gaps and code behavior, not personal failure.
- Never invent owner, impact, validation, or follow-up work.
- State validation coverage honestly; do not imply broader testing than occurred.

## Output Flow

Default to chat output. If the user asks to create a file, use their path or suggest `docs/postmortems/<ticket-or-topic>.md` when a durable record is appropriate. Ask before overwriting unrelated context.

If the user asks to post externally, show the exact body first and wait for explicit approval before using any posting tool.
