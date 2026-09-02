---
name: subagent-driven-development
description: "User entry point for executing an approved implementation plan task-by-task, each task built by a fresh subagent and checked by an independent reviewer before the next one starts. Use when the user wants to build out an approved plan, task list, or backlog of engineering work with per-task review and a durable progress record."
disable-model-invocation: true
argument-hint: "<path to plan or task list>"
---

# Subagent-Driven Development

Execute an approved plan task-by-task: a fresh subagent builds each task, an independent reviewer checks it against two questions before the next task starts, and progress lives in a file that survives lost context.

## When to Use

Use when the user has an approved plan, task list, or backlog (from `write-a-story`, `write-a-prd`, `brainstorming`, or pasted directly) and wants it built out task by task with a review gate between each one.

## When Not to Use

- A single small change with no real task breakdown — just make the change directly.
- Tasks are tightly coupled and can't be split into independent, reviewable units — build it in one pass instead.

## Artifacts

- Consumes: the plan or task list file passed in as the argument
- Produces: progress ledger at the `sdd-progress` key path — see `references/artifact-paths.md` (default `.context/sdd-progress/<slug>.md`, one ledger per plan); one commit per task
- Bundled: `references/implementer-prompt.md`, `references/task-reviewer-prompt.md` — dispatch templates for steps 2 and 4; `references/task-loop.md` — the loop's mechanics

## Core Rule

Give each task a fresh subagent with only what it needs, gate it with two separate verdicts — does it match spec, and is it well-built — before moving on, and keep the record of what's done in a file, not in memory.

## Workflow

1. Read the plan, list every task, and write the ledger file with all tasks marked pending.
2. Record BASE (`git rev-parse HEAD`), then dispatch an implementer using `references/implementer-prompt.md` with only that task's text plus the interfaces or decisions from earlier tasks it needs — not the whole plan. Hand work over as file paths, not pasted text.
3. Handle the report by its status — `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED`. Each has a different move; see `references/task-loop.md`.
4. On DONE (or once concerns are resolved), dispatch a reviewer using `references/task-reviewer-prompt.md` with the diff from BASE to HEAD — never `HEAD~1`, which drops all but the last commit of a multi-commit task.
5. Route the findings by severity: Critical and Important enter the fix loop; Minor is recorded in the ledger as deferred and triaged at the final review. The fix loop runs at most five rounds — rounds 1–3 resume the original implementer, rounds 4–5 go to a fresh one on a more capable model.
6. Mark the task complete in the ledger with its commit range, then continue to the next pending task without stopping to check in. Only stop for a blocker you can't resolve or genuine ambiguity.
7. After all tasks are complete, run one broader review across the full diff — pointed at the deferred-Minor list — before calling the plan done.

Load `references/task-loop.md` for the mechanics of any of these steps: the implementer contract, what each status requires, review inputs, severity routing, and the fix loop's escalation.

## Model Selection

| Task | Model |
|---|---|
| Mechanical, 1-2 files, fully specified | Cheapest available |
| Multi-file, needs judgment | Standard |
| Architecture-level, or the final broad review | Most capable available |

## Progress Ledger

Check the ledger at the `sdd-progress` key path (see `references/artifact-paths.md`, default `.context/sdd-progress/<slug>.md`) before dispatching anything — tasks already marked complete are done; resume at the first one that isn't. After a compaction or a resumed session, trust this file and `git log` over memory of what happened.

## Operating Rules

- Never dispatch more than one implementer at a time — parallel implementers on the same plan conflict with each other.
- Never skip either review verdict, and never advance past unresolved Critical or Important findings.
- Give the implementer only its own task's text, not the whole plan file. Everything pasted into a dispatch stays in context for the rest of the session and is re-read every turn.
- The implementer dispatches no subagents of its own — not helpers, and not a reviewer. Review comes from the controller, after the report.
- Never pre-judge findings for a reviewer. Telling it to ignore an issue, or capping a severity in advance, buys one skipped round and costs the review its point.
- If a task reports BLOCKED, change something — more context, a stronger model, a smaller task, a ruling on a wrong plan step — before retrying. Don't re-dispatch unchanged.
- Batch small same-shape edits into one dispatch and review them as one diff. One dispatch per task is for work that needs its own judgment, tests, or review surface.

## Reference Map

- `references/task-loop.md`: the loop's mechanics — BASE tracking, review verdicts, and recovery when a task fails review.
- `references/implementer-prompt.md`: dispatch template for step 2.
- `references/task-reviewer-prompt.md`: dispatch template for step 4.

## Next Step

- **If all tasks are complete and the final broad review passes:** move to `tdd` for any remaining test gaps, or `security-audit`/`ga4-measurement` for a pre-ship review, then `post-mortem` or `management-talk` to close out. To move remaining work onto the tracker, tell the user to run `/triage`.
- **If blocked, or a review verdict fails:** resolve the specific blocker (more context, a stronger model, a smaller task) and retry — do not advance to the next task.
