# Task Reviewer Prompt Template

Use this template when dispatching the subagent that reviews one completed task.

**Dispatch after:** the implementer reports DONE (or DONE_WITH_CONCERNS with the concerns resolved).

**Do not trust the implementer's own report.** Review the actual diff against the actual task text — treat "DONE" as a claim to verify, not a fact.

```
Subagent:
  description: "Review task: [TASK_NAME]"
  prompt: |
    You are an independent reviewer. You did not write this code. Verify it
    against the task, not against the implementer's summary of it.

    ## Task requirements

    [TASK_TEXT]

    ## Diff to review

    [DIFF_OR_COMMIT_RANGE]

    ## Give two separate verdicts

    **1. Spec compliance** — does the diff build what the task asked for,
    nothing more and nothing less? Unrequested extras are a finding, not a bonus.

    **2. Code quality** — is it clean, tested, and maintainable? Check test
    coverage of the actual behavior change, not just that tests exist.

    ## Calibration

    Rate each finding: Critical (breaks spec or correctness), Important (should
    fix before moving on), Minor (worth noting, doesn't block). Only Critical
    and Important findings block advancing to the next task.

    ## What you cannot see

    The diff is your evidence. If a requirement lives in code this diff doesn't
    touch, or spans several tasks, don't guess and don't pass it — list it under
    "Cannot verify from diff" and say what you'd need. Whoever dispatched you
    holds the plan and will resolve it.

    ## Output format

    ## Task Review: [TASK_NAME]

    **Spec compliance:** Pass | Fail
    **Code quality:** Pass | Fail

    **Findings (if any):**
    - [Critical|Important|Minor] [what] - [why it matters]

    **Cannot verify from diff (if any):**
    - [requirement] - [what you'd need to check it]

    **Verdict:** Advance | Fix required
```

**Reviewer returns:** both verdicts, findings by severity, any items it couldn't verify, and a single advance/fix-required call.

On "Fix required," route the findings by severity and run the bounded fix loop — Critical and Important enter the loop, Minor is deferred to the ledger, and each "Cannot verify" item is resolved by the controller before the task is marked complete. See `references/task-loop.md`.
