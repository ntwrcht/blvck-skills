---
name: debug-mantra
description: >
  Four-mantra debugging discipline: reproduce, trace the fail path, falsify the
  hypothesis, and cross-reference every breadcrumb. Use for /debug-mantra and
  proactively whenever debugging starts: user reports a bug, says something is
  broken, throwing, failing, asks to debug, diagnose, investigate an issue, or
  pastes a stack trace, failing test, or error log. Recite the mantra block
  verbatim at the start of the debugging session unless the user says to skip it,
  then apply the four steps in order before proposing a fix.
---

# Debug Mantra

Four-step discipline for any debug session. Recite verbatim once, then apply the steps in order.

## Required Recital

Recite this block verbatim as the first thing in your first response for a debugging session:

> **Mantra:**
> 1. **First is reproducibility.** Can the issue be reproduced reliably?
> 2. **Know the fail path.** Debugger first; then source trace + knob enumeration; then in-code instrumentation.
> 3. **Question your hypothesis.** What would disprove it?
> 4. **Every run is a breadcrumb.** Cross-reference all of them.

If the user says "skip the mantra", skip the recital but still apply the workflow silently.

## Workflow

### 1. Reproduce Reliably

Build a runnable repro before anything else.

- Reliable repro: capture exact steps, inputs, and environment as a runnable artifact such as a failing test, curl script, CLI invocation, or replay harness.
- Flaky repro: raise the failure rate first with loops, stress, parallel runs, narrowed timing windows, or injected sleeps. A 50% flake is debuggable; a 1% flake is not.
- No repro: stop and say so explicitly. Ask for environment access, captured artifacts such as HAR/log/core dumps, or permission to instrument. Do not hypothesize yet.

Target a fast, deterministic pass/fail signal: 1-5 seconds where practical. Pin time, seed randomness, freeze network access, and isolate filesystem state when relevant.

### 2. Know the Fail Path

Once reproducible, find where the code breaks and what stops it from breaking. Escalate in this order:

1. Attach a debugger if the environment supports it. Step to the failure site before turning knobs.
2. If a debugger is unavailable or cannot reach the bug, trace the source path end-to-end and enumerate every knob that can influence the outcome: config flags, environment variables, feature toggles, branch conditions, input shape, timing, concurrency, and build options. Flip one axis at a time.
3. If outside knobs do not move the failure, add in-code instrumentation at suspected fail sites. Use a unique prefix such as `[DBG-a4f2]` so cleanup is one grep.

### 3. Falsify the Hypothesis

When a candidate root cause appears, scrutinize it before testing a fix.

- Generate 3-5 ranked hypotheses, not one.
- For each serious candidate, ask whether it explains the symptom end-to-end.
- Define the simplest proof and the cleanest disproof.
- Run the disproof first. If the hypothesis survives, it is stronger. If it fails, discard it.

### 4. Treat Every Run as a Breadcrumb

Maintain a running ledger of experiments in the session. Each entry records what changed, what happened, and what it ruled in or out.

When a new hypothesis appears, cross-check it against the full ledger. If any prior run contradicts it, the hypothesis is wrong or incomplete. Design the single next experiment whose outcome would make the conclusion certain.

## Operating Rules

- Recite the mantra block once per debugging session, in the first response only.
- Do not re-recite mid-session.
- Apply the four steps in order.
- Do not propose a fix before a reliable repro exists.
- Do not start testing hypotheses before the fail path has been narrowed.
- Do not commit to a hypothesis before trying to disprove it.
- Do not declare a hypothesis correct until it fits every prior breadcrumb.
- If you catch yourself proposing a fix without a reliable repro, stop and return to reproduction.
- The mantra is a constraint carried by the agent, not advice to deliver back to the user beyond the required recital.

## Optional Context Artifact

Default to keeping the experiment ledger in chat. If the user asks to persist, hand off, or reuse the debugging context, write or update `.context/debug-ledger.md` in the current workspace.

Use a named file such as `.context/debug-ledger-<ticket-or-topic>.md` when the current context is tied to a specific ticket, PR, incident, or topic and the default file already appears unrelated.

Do not create files by default. If no clear workspace exists, keep the ledger in chat unless the user provides a path.
