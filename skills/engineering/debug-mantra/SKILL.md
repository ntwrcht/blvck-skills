---
name: debug-mantra
description: "Debug failures with a disciplined repro, fail-path trace, hypothesis falsification, and experiment ledger. Use when investigating bugs, flaky tests, crashes, regressions, hangs, or unexplained behavior before proposing a fix."
---

# Debug Mantra

Run debugging as an evidence loop: reproduce, trace, falsify, then fix.

## When to Use

Use this skill for active debugging: failing tests, production defects, flaky behavior, crashes, hangs, performance regressions, data corruption, or any bug report where the cause is not already proven.

Use the relevant language or framework skill alongside this one when implementation patterns matter. After the bug is fixed and validated, use `post-mortem` for the engineering writeup.

## When Not to Use

- The user only wants a code review, design review, or plan critique. Use `scrutinize`.
- The root cause and validated fix are already known. Implement or document instead.
- The user asks for pure test-first development of new behavior. Use `tdd`.

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
