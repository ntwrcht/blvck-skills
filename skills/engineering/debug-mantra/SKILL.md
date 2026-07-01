---
name: debug-mantra
description: "Debug failures with a compact repro, fail-path trace, hypothesis falsification, and breadcrumb ledger. Use when investigating a bug or failure needs lightweight structure before proposing a fix."
---

# Debug Mantra

Run debugging as an evidence loop: reproduce, trace, falsify, then fix.

## When to Use

Use this skill for active debugging that needs lightweight structure: failing tests, local defects, unexpected errors, and bug reports where the cause is not already proven.

Use `diagnose` for heavier investigations: hard bugs, performance regressions, flaky failures, crashes, hangs, production-only symptoms, multi-service failures, or cases that need minimisation, bisection, trace replay, or human-in-the-loop reproduction. Use the relevant language or framework skill alongside this one when implementation patterns matter. After the bug is fixed and validated, use `post-mortem` for the engineering writeup.

## When Not to Use

- The user only wants a code review, design review, or plan critique. Use `scrutinize`.
- The root cause and validated fix are already known. Implement or document instead.
- The user asks for pure test-first development of new behavior. Use `tdd`.

## Artifacts

- Produces: debug ledger at the `debug-ledger` key path — see `references/artifact-paths.md` (default `.context/debug-ledger.md`, on request)
- Consumes: `.context/project.md`, `.context/engineering.md`

## Required Mantra

Recite once at the start of the first debugging response unless the user says to skip it:

> **Mantra:**
> 1. **First is reproducibility.** Can the issue be reproduced reliably?
> 2. **Know the fail path.** Debugger first; then source trace + knob enumeration; then in-code instrumentation.
> 3. **Question your hypothesis.** What would disprove it?
> 4. **Every run is a breadcrumb.** Cross-reference all of them.

## Workflow

1. **Reproduce.** Turn the report into a fast pass/fail signal: failing test, CLI command, curl script, replay harness, loop, stress run, or captured artifact. If there is no repro, stop and ask for access, logs, dumps, HAR files, inputs, or permission to instrument.
2. **Trace the fail path.** Prefer a debugger when available. Otherwise trace source from entry point to failure and enumerate knobs: config, environment, feature flags, inputs, timing, concurrency, build options, external services, and cached state.
3. **Instrument only after tracing.** Add targeted logs or probes at suspected boundaries. Use a unique prefix such as `[DBG-a4f2]` so cleanup is one grep.
4. **Rank hypotheses.** Keep 3-5 candidates. For each serious candidate, state what would prove it and what would disprove it. Run the disproof first when possible.
5. **Maintain a breadcrumb ledger.** Record each run as: change, observation, and what it ruled in or out. Cross-check every new theory against earlier runs.
6. **Fix only after evidence converges.** The fix must explain the original symptom, the fail path, and the ledger. Validate against the original repro before broadening tests.

## Operating Rules

- Do not propose a fix before a reliable repro or a concrete missing-repro blocker.
- Do not skip fail-path tracing and jump from symptom to patch.
- Do not keep a hypothesis that contradicts a prior run.
- Change one axis at a time unless a combined test is explicitly needed.
- Keep user-facing updates tied to evidence: what was tried, what happened, and what it means.
- Remove temporary instrumentation before finishing unless the user asks to keep it.

## Optional Artifact

Default to a chat ledger. If the user asks to persist or hand off context, write `.context/debug-ledger.md` or `.context/debug-ledger-<ticket-or-topic>.md` when a ticket, PR, incident, or topic is clear. Ask before overwriting unrelated context.

## Next Step

Do not close the debugging session until the user confirms the bug is fixed and the fix has been validated.

- **If approved:** the bug is fixed and validated — recommend `post-mortem` for the writeup, especially when the bug was significant or user-facing.
- **If not approved:** stay in this skill's own loop and keep gathering evidence, or escalate to `diagnose` if hypothesis-driven debugging isn't converging — do not proceed to `post-mortem` until approval is explicit.
