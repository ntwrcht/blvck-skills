---
name: debug
description: "Debugs failures and performance regressions as an evidence loop — establish a red signal, trace the fail path, falsify ranked hypotheses, then fix with a regression test. Use when a failing test or command already reproduces the bug every run, or when the failure is flaky, production-only, a crash, a hang, data corruption, or a slowdown that needs a harness built before the cause can be chased."
---

# Debug

Run debugging as an evidence loop: get a red signal, trace, falsify, then fix.

## When to Use

Use this skill for any live bug investigation: a failing test, an unexpected error, a bug report with steps, a flaky suite, a production-only symptom, a crash, a hang, data corruption, or a performance regression.

Use the relevant language, framework, or domain skill alongside this one when implementation patterns matter. After the bug is fixed and validated, use `post-mortem` for the engineering writeup.

## When Not to Use

- The user only wants a code review, design review, or plan critique. Use `scrutinize`.
- The root cause and validated fix are already known. Implement or document instead.
- The user asks for pure test-first development of new behavior. Use `tdd`.
- The request is a simple known-error lookup or one-command fix where a full investigation loop would add noise.

## Artifacts

- Produces: debug ledger at the `debug-ledger` key path — see `references/artifact-paths.md` (default `.context/debug-ledger.md`, on request), plus the fix and its regression test
- Consumes: `.context/debug-ledger.md` (if present), `.context/project.md`, `.context/engineering.md`, `.context/post-mortem.md`, `.context/learning.md`

## Required Mantra

Recite once at the start of the first debugging response unless the user says to skip it:

> **Mantra:**
> 1. **First is reproducibility.** Can the issue be reproduced reliably?
> 2. **Know the fail path.** Debugger first; then source trace + knob enumeration; then in-code instrumentation.
> 3. **Question your hypothesis.** What would disprove it?
> 4. **Every run is a breadcrumb.** Cross-reference all of them.

## Pick a branch

One question decides where the work starts, and it is answerable before any investigation:

> **Is there already a command that shows the failure every time you run it?**

Answer it by running the repro twice, not by judging how hard the bug looks. An intermittent pass means the signal is not real yet.

- **Yes** — a failing test, a `curl`, a CLI invocation, a script someone handed you. The red signal exists, so skip loop construction and spend the effort on the cause. **Start at Step 2.**
- **No** — the failure is intermittent, production-only, or needs a harness, a bisection, or a trace replay to surface. The first job is building that signal. **Start at Step 1.**

Both branches converge from Step 3 on. A wrong branch choice costs one step, not the investigation: if a repro that looked reliable turns out to be intermittent, drop back to Step 1 and build the loop.

## Workflow

Before step 1 or step 2, load relevant context: `.context/INDEX.md` when present, then `.context/project.md`, `.context/engineering.md`, `.context/post-mortem.md`, `.context/learning.md`, and `.context/adr/`. Keep it quick — `post-mortem.md` and `learning.md` are the ones that most often save an investigation, because the bug may already be a known pattern. The signal is still the priority.

1. **Build the feedback loop.** *(No-signal branch only.)* Prefer a failing test, HTTP script, CLI fixture, browser script, trace replay, throwaway harness, fuzz loop, bisection harness, or differential loop. Use `scripts/hitl-loop.template.sh` only when a human action is unavoidable. Confirm the loop meets all four criteria before advancing:
   - [ ] Red-capable — asserts the user's exact symptom, not just "didn't crash"
   - [ ] Deterministic — same verdict every run (nondeterministic bugs: pinned high reproduction rate)
   - [ ] Fast — seconds, not minutes
   - [ ] Agent-runnable — no human step required except via `scripts/hitl-loop.template.sh`

   No loop meeting all four criteria → no Step 3. Load `references/feedback-loops.md` for loop-construction tactics, nondeterministic-bug handling, and the human-in-the-loop fallback.
2. **Trace the fail path.** *(Signal branch only.)* Prefer a debugger when available. Otherwise trace source from entry point to failure and enumerate knobs: config, environment, feature flags, inputs, timing, concurrency, build options, external services, and cached state. If there is no repro after all, stop and go to Step 1, or ask for access, logs, dumps, HAR files, or permission to instrument.
3. **Confirm the symptom, then minimise.** Run the signal until the user's exact symptom appears — not a nearby failure. Wrong bug, wrong fix. Capture the error, wrong output, timing, or failure rate so later runs can prove the fix. Then shrink the input, scenario, service graph, timing window, or data fixture while preserving the same failure mode. Done when every remaining element is load-bearing: removing any one makes the signal go green.
4. **Rank hypotheses.** Generate 3-5 falsifiable candidates before testing anything. State each prediction as: "If X is the cause, then changing Y will make the bug disappear or changing Z will make it worse." Run the disproof first when possible. Show the ranked list to the user before testing — they often re-rank it instantly or have already ruled some out. Proceed if unavailable.
5. **Instrument.** Only after tracing, and only against a hypothesis: map every probe to one. Prefer debugger or REPL inspection, then targeted logs at distinguishing boundaries. Tag temporary logs with a unique prefix such as `[DBG-a4f2]` so cleanup is one grep.
6. **Maintain a breadcrumb ledger.** Record each run as: change, observation, and what it ruled in or out. Cross-check every new theory against earlier runs; drop any hypothesis that contradicts one.
7. **Fix with a regression test.** Fix only after the evidence converges — the fix must explain the original symptom, the fail path, and the ledger. Write the regression test before the fix when a correct seam exists. The seam must exercise the real bug pattern as it occurs at the call site; if no correct seam exists, document that architectural gap. If the fix does not hold, do not stack another on top — see **When Fixes Keep Failing**.
8. **Verify and clean up.** Re-run the original signal, run the regression test, remove all tagged instrumentation, delete throwaway prototypes, and state the hypothesis that proved correct in the commit, PR, or handoff note. Then ask: what would have prevented this bug? If the answer points to an architectural gap — no good test seam, tangled callers, hidden coupling — surface it in the handoff note or as a follow-up task.

## Operating Rules

- Do not propose a fix before a reliable signal or a concrete missing-repro blocker.
- Do not skip fail-path tracing and jump from symptom to patch.
- Change one axis at a time unless a combined test is explicitly needed.
- Keep user-facing updates tied to evidence: what was tried, what happened, and what it means.
- Remove temporary instrumentation before finishing unless the user asks to keep it.

## When Fixes Keep Failing

Count the fix attempts. The count is the signal, not the frustration.

- **Under 3 failed fixes:** return to step 4. Re-rank hypotheses with what the failed fix taught you — a fix that failed is evidence, and it usually eliminates a hypothesis.
- **At 3 failed fixes:** stop fixing and question the architecture. Three failures is rarely three wrong guesses; it usually means the bug is a property of the design rather than a defect in one place.

The tell is what each fix produces: if every attempt reveals new shared state, new coupling, or a new symptom somewhere else, the pattern itself is the problem. Say so, show the three attempts and what each revealed, and put the architectural question to the user before attempting a fourth fix. That is not a failed hypothesis — it is a wrong structure, and another fix will not find it.

## Red Flags

These thoughts mean the loop has been abandoned. Stop and return to the step named.

- "Quick fix now, investigate later" → step 1 or 2
- "Just try changing X and see" → step 4, with a written hypothesis
- "It's probably X, let me fix that" → step 4; a guess is not a ranked hypothesis
- "I'll change these three things and run the tests" → step 5, one variable at a time
- "I don't fully understand it, but this might work" → step 3
- Proposing a fix before the signal reproduces the symptom → step 1
- Listing fixes before tracing where the bad value originates → step 2
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

## Optional Artifact

Default to a chat ledger. If the user asks to persist or hand off context, write `.context/debug-ledger.md` or `.context/debug-ledger-<ticket-or-topic>.md` when a ticket, PR, incident, or topic is clear. Ask before overwriting unrelated context.

## Reference Map

- `references/feedback-loops.md`: loop-construction tactics, nondeterministic-bug handling, and the human-in-the-loop fallback.
- `references/artifact-paths.md`: where the debug ledger and other pipeline artifacts get written.
- `scripts/hitl-loop.template.sh`: the harness to use when a human action in the loop is unavoidable.

## Next Step

Do not close the investigation until the user confirms the bug is fixed and the fix and regression test are validated.

- **If approved:** hand off to `post-mortem` for the writeup, especially when the bug was significant or user-facing.
- **If not approved:** stay in this skill's loop and keep gathering evidence — don't hand off with an unvalidated fix. When the premise breaks and a repro that looked reliable turns out to be intermittent, drop back to Step 1 and build the signal properly.
