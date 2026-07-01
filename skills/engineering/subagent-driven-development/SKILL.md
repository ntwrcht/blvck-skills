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
- Produces: `.context/sdd-progress.md` (progress ledger) → at the `sdd-progress` key path, see `references/artifact-paths.md` (default `.context/sdd-progress/<slug>.md`, one ledger per plan), one commit per task
- Bundled: `implementer-prompt.md`, `task-reviewer-prompt.md` — dispatch templates for steps 2 and 3

## Core Rule

Give each task a fresh subagent with only what it needs, gate it with two separate verdicts — does it match spec, and is it well-built — before moving on, and keep the record of what's done in a file, not in memory.

## Workflow

1. Read the plan, list every task, and write the ledger file with all tasks marked pending.
2. For each pending task, dispatch an implementer subagent using `implementer-prompt.md`, filled in with only that task's text plus any interfaces or decisions from earlier tasks it needs — not the whole plan.
3. On DONE (or once concerns are resolved), dispatch a reviewer subagent using `task-reviewer-prompt.md`, filled in with the task's requirements and the diff.
4. If either verdict fails, dispatch a fix using `implementer-prompt.md` with the findings appended, then re-review. Don't advance with open issues.
5. Mark the task complete in the ledger with its commit range, then continue to the next pending task without stopping to check in. Only stop for a blocker you can't resolve or genuine ambiguity.
6. After all tasks are complete, run one broader review across the full diff before calling the plan done.

## Model Selection

| Task | Model |
|---|---|
| Mechanical, 1-2 files, fully specified | Cheapest available |
| Multi-file, needs judgment | Standard |
| Architecture-level, or the final broad review | Most capable available |

## Progress Ledger

Check `.context/sdd-progress.md` before dispatching anything — tasks already marked complete are done; resume at the first one that isn't. After a compaction or a resumed session, trust this file and `git log` over memory of what happened.

## Operating Rules

- Never dispatch more than one implementer at a time — parallel implementers on the same plan conflict with each other.
- Never skip either review verdict, and never advance past unresolved Critical or Important findings.
- Give the implementer only its own task's text, not the whole plan file.
- If a task reports BLOCKED, resolve the specific blocker — more context, a stronger model, a smaller task — before retrying. Don't re-dispatch unchanged.

## Next Step

- **If all tasks are complete and the final broad review passes:** move to `tdd` for any remaining test gaps, or `security-audit`/`ga4-measurement` for a pre-ship review, then `triage`, `post-mortem`, or `management-talk` to close out.
- **If blocked, or a review verdict fails:** resolve the specific blocker (more context, a stronger model, a smaller task) and retry — do not advance to the next task.
