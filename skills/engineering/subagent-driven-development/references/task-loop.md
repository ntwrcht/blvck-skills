# The Task Loop

Mechanics for dispatching, reviewing, and fixing one task. The `SKILL.md` workflow is the shape; this is what each step actually requires.

## Before Dispatching

**Record BASE.** Run `git rev-parse HEAD` and keep the value. The review package for this task is the diff from BASE to HEAD.

Never review with `HEAD~1`. A task that lands in more than one commit silently loses everything but the last one, and the reviewer approves a diff that is missing most of the work.

**Batch same-shape work.** When the plan lists several small, independent edits of the same kind — the same one-line change repeated across files — compose one brief covering every file and send the batch to a single subagent, reviewed as one diff. Reserve one dispatch per task for work that needs its own judgment, its own tests, or its own review surface.

## Context Discipline

Everything pasted into a dispatch prompt, and everything a subagent prints back, stays in the controller's context for the rest of the session and is re-read every turn.

- Hand work over as **files**, not pasted text. Write the task brief to a file and pass the path.
- A dispatch prompt describes **one task**, not the session's history. Accumulated summaries of prior tasks are the main way these prompts bloat.
- Give the implementer its own task's text, the interfaces it touches, and the global constraints. Nothing else.

## The Implementer Contract

The implementer never dispatches subagents of its own — no helpers, and no reviewer. Review arrives from the controller after the report. An implementer that spawns its own reviewer duplicates the review the controller runs anyway, at the cost of a full extra seat per task.

Implementers report one of four statuses:

| Status | What it means | Controller's move |
|---|---|---|
| `DONE` | Work complete | Generate the review package and dispatch the reviewer |
| `DONE_WITH_CONCERNS` | Complete, with doubts flagged | Read the concerns first. Correctness or scope concerns get resolved before review; observations get noted and reviewed as normal |
| `NEEDS_CONTEXT` | Missing information | Supply what is missing and re-dispatch |
| `BLOCKED` | Cannot complete | Change something before retrying — see below |

Never re-dispatch the same model on an unchanged `BLOCKED` task. If the implementer says it is stuck, something has to change: more context, a more capable model, a smaller task, or a ruling on a wrong plan step. Ignoring an escalation wastes the seat and returns the same result.

## Reviewing

The task review is a task-scoped gate. Both verdicts are required — does it match spec, and is it well built — and an implementer's self-review never substitutes for either.

Hand the reviewer files, not pasted diffs: the review package path, the brief path, and the report path, plus the global constraints binding this task. Copy those constraints verbatim from the plan — exact values, exact formats, stated relationships between components.

**Do not pre-judge findings.** Never instruct a reviewer to ignore an issue, to treat something as not-a-defect, or to cap a severity. If a finding would be a false positive, let the reviewer raise it and adjudicate it afterwards. A prompt containing "do not flag", "don't treat X as a defect", or "at most Minor" is pre-judging, usually to avoid a review round.

Also avoid open-ended directives — "check all uses", "run whatever tests seem useful" — without a concrete, task-specific reason, and do not ask the reviewer to re-run tests the implementer already ran on the same code. The report carries that evidence.

**"Cannot verify from diff" items.** A reviewer may flag requirements that live in unchanged code or span several tasks. These do not block the rest of the review, but the controller resolves each one before marking the task complete — the controller holds the plan and the cross-task context the reviewer lacks. A confirmed gap becomes a failed spec review and enters the fix loop.

## Severity Routing

Not every finding enters the fix loop.

- **Critical and Important** findings, a failed spec verdict, and confirmed "cannot verify" gaps → the fix loop.
- **Minor** findings → recorded in the ledger as `Task <N>: minor (deferred): <one-liner>`, and the final whole-branch review is pointed at that list to triage what must be fixed before merge. A deferred list nobody reads is a silent discard.
- **Plan-mandated** findings — where the finding conflicts with what the plan requires — are the controller's to rule on. Weigh the finding against the plan text with the spec as binding authority, record the ruling in the ledger, then act. Do not dismiss a finding merely because the plan mandated the behaviour, and do not dispatch a fix that contradicts the plan without a recorded ruling.

## The Fix Loop

One round is one fix dispatch plus one scoped re-review. **Five rounds maximum per task.**

**Rounds 1–3 — resume the original implementer.** Send the open findings verbatim. Its context is intact: it knows the task, the code, and why it made its choices. If the harness cannot message a live subagent, dispatch a fresh one carrying the brief path, the report path, and the findings — the report file is the persistent memory either way.

**Rounds 4–5 — dispatch a fresh implementer on a more capable model**, with the brief path, the report path, the open findings, and the framing that a prior implementer attempted this task several times and it now belongs to them, with the report file describing what was tried. A loop that survives three resumes usually means the implementer cannot see its own mistake; fresh eyes and a capability bump address that in one move.

Every round, either way: the implementer fixes, re-runs the tests covering the amended code, appends its fix report to the same report file, and returns the short contract.

**If five rounds do not clear the findings,** stop dispatching. Five failed rounds is evidence about the task or the plan, not about the implementer — surface it to the user with the findings and what each round tried.
