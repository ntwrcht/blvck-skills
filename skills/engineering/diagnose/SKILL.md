---
name: diagnose
description: "Diagnoses hard bugs and performance regressions through a disciplined feedback-loop investigation. Use when a bug, flaky failure, crash, hang, data issue, or slowdown needs reproduction, minimisation, hypotheses, instrumentation, a fix, and a regression test."
---

# Diagnose

Run hard bug work as a feedback-loop investigation: reproduce, minimise, hypothesise, instrument, fix, and regression-test.

## When to Use

Use this skill for hard bugs and regressions where a quick inspection is unlikely to be enough: flaky failures, crashes, hangs, data corruption, timing issues, production-only symptoms, multi-service failures, and performance regressions.

Use `debug-mantra` for lighter active debugging when the user needs a compact discipline rather than the full diagnosis workflow. Use the relevant language, framework, or domain skill alongside this one when implementation patterns matter. After the bug is fixed and validated, use `post-mortem` for the engineering writeup.

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

1. **Load relevant context.** Read `.context/INDEX.md` when present, then load useful domains such as `.context/project.md`, `.context/engineering.md`, `.context/post-mortem.md`, `.context/learning.md`, and `.context/adr/`. Keep this quick; the feedback loop is still the priority.
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
7. **Fix with a regression test.** Write the regression test before the fix when a correct seam exists. The seam must exercise the real bug pattern as it occurs at the call site; if no correct seam exists, document that architectural gap.
8. **Verify and clean up.** Re-run the original loop, run the regression test, remove all tagged instrumentation, delete throwaway prototypes, and state the hypothesis that proved correct in the commit, PR, or handoff note. Then ask: what would have prevented this bug? If the answer points to an architectural gap — no good test seam, tangled callers, hidden coupling — surface it in the handoff note or as a follow-up task.

## Performance Branch

For performance regressions, establish a baseline measurement before changing code: timing harness, profiler, query plan, trace, or benchmark. Prefer bisection and measurement over log-heavy inspection. Validate the fix against the original scenario and a focused regression guard when the project has an appropriate performance-test seam.

## Next Step

Do not close the investigation until the user confirms the fix and regression test are validated.

- **If approved:** hand off to `post-mortem` for the writeup.
- **If not approved:** keep iterating the feedback loop — don't hand off with an unvalidated fix.
