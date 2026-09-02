---
name: diagnose
description: "Diagnoses hard bugs and performance regressions through a disciplined feedback-loop investigation. Use when a failure has no reliable repro yet — flaky, production-only, crash, hang, data corruption, or slowdown — and a harness must be built before minimisation, hypotheses, instrumentation, a fix, and a regression test."
---

# Diagnose

Run hard bug work as a feedback-loop investigation: reproduce, minimise, hypothesise, instrument, fix, and regression-test.

## When to Use

Use this skill when **no command reliably shows the failure yet** — the signal has to be built before the cause can be chased. That is the case for flaky failures, crashes, hangs, data corruption, timing issues, production-only symptoms, multi-service failures, and performance regressions, and Step 2 exists to build exactly that signal.

Use `debug-mantra` when a failing test, command, or request already reproduces every run. There the red signal exists, so the loop-construction work here is overhead. Check by running the repro twice rather than by judging the bug's difficulty; an intermittent pass means the signal is not yet real and the work belongs here.

Use the relevant language, framework, or domain skill alongside this one when implementation patterns matter. After the bug is fixed and validated, use `post-mortem` for the engineering writeup.

## When Not to Use

- The user only wants a code review, design review, or plan critique. Use `scrutinize`.
- The root cause and validated fix are already known. Implement or document instead.
- The user asks for pure test-first development of new behavior. Use `tdd`.
- The request is a simple known-error lookup or one-command fix where a full investigation loop would add noise.

## Artifacts

- Produces: debug ledger at the `debug-ledger` key path (same file as `debug-mantra` — see `references/artifact-paths.md`, default `.context/debug-ledger.md`), fix + regression test
- Consumes: `.context/debug-ledger.md` (if present), `.context/project.md`, `.context/engineering.md`, `.context/post-mortem.md`, `.context/learning.md`

## Core Rule

Build a fast, deterministic, agent-runnable pass/fail signal before chasing causes. If you cannot build a credible loop, stop, state what you tried, and ask for the missing artifact or environment access.

Load `references/feedback-loops.md` when you need loop-construction tactics, nondeterministic-bug handling, or the human-in-the-loop fallback.

## Workflow

1. **Load relevant context.** Read `.context/INDEX.md` when present, then load relevant domain files such as `.context/project.md`, `.context/engineering.md`, `.context/post-mortem.md`, `.context/learning.md`, and `.context/adr/`. Keep this quick; the feedback loop is still the priority.
2. **Build the feedback loop.** Prefer a failing test, HTTP script, CLI fixture, browser script, trace replay, throwaway harness, fuzz loop, bisection harness, or differential loop. Use `scripts/hitl-loop.template.sh` only when a human action is unavoidable. Once you have a loop, confirm it meets all four criteria before advancing:
   - [ ] Red-capable — asserts the user's exact symptom, not just "didn't crash"
   - [ ] Deterministic — same verdict every run (nondeterministic bugs: pinned high reproduction rate)
   - [ ] Fast — seconds, not minutes
   - [ ] Agent-runnable — no human step required except via `scripts/hitl-loop.template.sh`

   No loop meeting all four criteria → no Step 3.
3. **Reproduce.** Run the loop until the user's exact symptom appears. Confirm the loop drives the failure the user described — not a nearby failure. Wrong bug = wrong fix. Capture the error, wrong output, timing, or failure rate so later runs can prove the fix.
4. **Minimise.** Shrink the input, scenario, service graph, timing window, or data fixture while preserving the same failure mode. Done when every remaining element is load-bearing — removing any one makes the loop go green.
5. **Rank hypotheses.** Generate 3-5 falsifiable hypotheses before testing. State each prediction as: "If X is the cause, then changing Y will make the bug disappear or changing Z will make it worse." Show the ranked list to the user before testing — they often have domain knowledge that re-ranks instantly or have already ruled some out. Proceed if unavailable.
6. **Instrument.** Map every probe to a hypothesis. Prefer debugger or REPL inspection, then targeted logs at distinguishing boundaries. Tag temporary logs with a unique prefix such as `[DEBUG-a4f2]`.
7. **Fix with a regression test.** Write the regression test before the fix when a correct seam exists. If the fix does not hold, do not stack another on top — see **When Fixes Keep Failing**. The seam must exercise the real bug pattern as it occurs at the call site; if no correct seam exists, document that architectural gap.
8. **Verify and clean up.** Re-run the original loop, run the regression test, remove all tagged instrumentation, delete throwaway prototypes, and state the hypothesis that proved correct in the commit, PR, or handoff note. Then ask: what would have prevented this bug? If the answer points to an architectural gap — no good test seam, tangled callers, hidden coupling — surface it in the handoff note or as a follow-up task.

## When Fixes Keep Failing

Count the fix attempts. The count is the signal, not the frustration.

- **Under 3 failed fixes:** return to step 5. Re-rank hypotheses with what the failed fix taught you — a fix that failed is evidence, and it usually eliminates a hypothesis.
- **At 3 failed fixes:** stop fixing and question the architecture. Three failures is rarely three wrong guesses; it usually means the bug is a property of the design rather than a defect in one place.

The tell is what each fix produces: if every attempt reveals new shared state, new coupling, or a new symptom somewhere else, the pattern itself is the problem. Say so, show the three attempts and what each revealed, and put the architectural question to the user before attempting a fourth fix. That is not a failed hypothesis — it is a wrong structure, and another fix will not find it.

## Red Flags

These thoughts mean the loop has been abandoned. Stop and return to the step named.

- "Quick fix now, investigate later" → step 2
- "Just try changing X and see" → step 5, with a written hypothesis
- "It's probably X, let me fix that" → step 5; a guess is not a ranked hypothesis
- "I'll change these three things and run the tests" → step 6, one variable at a time
- "I don't fully understand it, but this might work" → step 3
- Proposing a fix before the loop reproduces the symptom → step 2
- Listing fixes before tracing where the bad value originates → step 5
- "One more fix attempt" after two have failed → **When Fixes Keep Failing**

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "This bug is simple, the loop is overkill" | Simple bugs have root causes too, and the loop is fastest on them. |
| "It's an emergency, there's no time" | Guess-and-check thrashing is slower than the loop, and it is what emergencies actually cost. |
| "I'll build the loop after I confirm the fix" | Without the loop there is nothing to confirm against. A fix with no red-capable signal is a hope. |
| "The test passed once, that proves it" | A regression test that has never been watched fail proves nothing about the bug. |
| "Fix several things at once to save time" | You cannot tell which change worked, and you have added new suspects. |
| "I can see the problem in the stack trace" | Seeing the symptom's location is not knowing what put the bad value there. |
| "It's environmental, there is no root cause" | Most of the time this is an incomplete investigation. Reach it by elimination, not assumption. |

## Performance Branch

For performance regressions, establish a baseline measurement before changing code: timing harness, profiler, query plan, trace, or benchmark. Prefer bisection and measurement over log-heavy inspection. Validate the fix against the original scenario and a focused regression guard when the project has an appropriate performance-test seam.

## Reference Map

- `references/feedback-loops.md`: loop-construction tactics, nondeterministic-bug handling, and the human-in-the-loop fallback.
- `scripts/hitl-loop.template.sh`: the harness to use when a human action in the loop is unavoidable.

## Next Step

Do not close the investigation until the user confirms the fix and regression test are validated.

- **If approved:** hand off to `post-mortem` for the writeup.
- **If not approved:** keep iterating the feedback loop — don't hand off with an unvalidated fix.
