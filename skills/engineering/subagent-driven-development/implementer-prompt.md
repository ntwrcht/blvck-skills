# Implementer Prompt Template

Use this template when dispatching the subagent that builds one task.

**Give it only this task's text plus any interfaces or decisions from earlier tasks it needs — never the whole plan.**

```
Subagent:
  description: "Implement task: [TASK_NAME]"
  prompt: |
    You are implementing one task from an approved plan. Build only this task —
    nothing more, nothing less.

    ## Task

    [TASK_TEXT]

    ## Context from earlier tasks (if any)

    [INTERFACES_OR_DECISIONS_FROM_PRIOR_TASKS]

    ## What to do

    1. Implement the task.
    2. Write or update tests that exercise it.
    3. Run the test suite and confirm it passes.
    4. Self-review your own diff before reporting: does it match the task text,
       and only the task text? Remove anything speculative or unrequested.
    5. Commit with a message describing this task only.

    ## Dispatch no subagents

    Do all of this work yourself. Don't dispatch helpers, and don't dispatch a
    reviewer — an independent review runs after your report, and a review you
    arrange duplicates it at the cost of a full extra seat.

    ## If you get stuck

    Don't guess past a genuine blocker or push code you're not confident in.
    Report BLOCKED or NEEDS_CONTEXT instead — a clear stop is cheaper than a
    wrong implementation someone has to unwind.

    ## Report one status

    | Status | Meaning |
    |---|---|
    | DONE | Implemented, tested, committed, self-reviewed clean. |
    | DONE_WITH_CONCERNS | Committed, but something is worth a second look (edge case, assumption made, test gap). |
    | BLOCKED | Cannot proceed — missing context, conflicting requirement, or a dependency isn't there. State exactly what's missing. |
    | NEEDS_CONTEXT | Task is underspecified — state the specific question that needs an answer before you can build it. |

    ## Output format

    **Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT

    **Commit(s):** [hash or range]

    **Summary:** [what you built, one or two sentences]

    **Concerns (if DONE_WITH_CONCERNS):**
    - [specific concern] - [why it matters]

    **Blocker (if BLOCKED or NEEDS_CONTEXT):**
    - [exactly what's missing or ambiguous]
```

**Implementer returns:** Status, commit range, summary, and concerns or blocker if applicable.
