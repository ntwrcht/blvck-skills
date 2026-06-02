---
name: diagnose
description: "Diagnose hard bugs and performance regressions through a disciplined feedback-loop investigation. Use when a bug, flaky failure, crash, hang, data issue, or slowdown needs reproduction, minimisation, hypotheses, instrumentation, a fix, and a regression test."
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

## Core Rule

Build a fast, deterministic, agent-runnable pass/fail signal before chasing causes. If you cannot build a credible loop, stop, state what you tried, and ask for the missing artifact or environment access.

Load `references/feedback-loops.md` when you need loop-construction tactics, nondeterministic-bug handling, or the human-in-the-loop fallback.

## Workflow

1. **Load relevant context.** Read `.context/INDEX.md` when present, then load useful domains such as `.context/project.md`, `.context/engineering.md`, `.context/post-mortem.md`, `.context/learning.md`, and `.context/adr/`. Keep this quick; the feedback loop is still the priority.
2. **Build the feedback loop.** Prefer a failing test, HTTP script, CLI fixture, browser script, trace replay, throwaway harness, fuzz loop, bisection harness, or differential loop. Use `scripts/hitl-loop.template.sh` only when a human action is unavoidable.
3. **Reproduce.** Run the loop until the user's exact symptom appears. Capture the error, wrong output, timing, or failure rate so later runs can prove the fix.
4. **Minimise.** Shrink the input, scenario, service graph, timing window, or data fixture while preserving the same failure mode.
5. **Rank hypotheses.** Generate 3-5 falsifiable hypotheses before testing. State each prediction as: "If X is the cause, then changing Y will make the bug disappear or changing Z will make it worse." Show the ranked list to the user, then proceed if they are unavailable.
6. **Instrument.** Map every probe to a hypothesis. Prefer debugger or REPL inspection, then targeted logs at distinguishing boundaries. Tag temporary logs with a unique prefix such as `[DEBUG-a4f2]`.
7. **Fix with a regression test.** Write the regression test before the fix when a correct seam exists. The seam must exercise the real bug pattern as it occurs at the call site; if no correct seam exists, document that architectural gap.
8. **Verify and clean up.** Re-run the original loop, run the regression test, remove all tagged instrumentation, delete throwaway prototypes, and state the hypothesis that proved correct in the commit, PR, or handoff note.

## Performance Branch

For performance regressions, establish a baseline measurement before changing code: timing harness, profiler, query plan, trace, or benchmark. Prefer bisection and measurement over log-heavy inspection. Validate the fix against the original scenario and a focused regression guard when the project has an appropriate performance-test seam.
