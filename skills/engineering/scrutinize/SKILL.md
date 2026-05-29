---
name: scrutinize
description: >
  Outsider-perspective end-to-end review of a plan, PR, diff, design doc, or
  code change. Use for /scrutinize and proactively whenever the user asks to
  review, audit, sanity-check, or get a second opinion on a plan, PR, diff,
  design doc, or proposed code change. First question intent and whether a
  simpler approach would achieve the same goal, then trace actual code paths
  beyond the diff to verify the change does what it claims.
---

# Scrutinize

Stand outside the change and ask whether it should exist at all, then verify it does what it claims end-to-end.

## Operating Stance

- Outsider: read the artifact cold, independent of who wrote it or why they think it is right.
- End-to-end: the diff is the entry point, not the scope. Follow real code paths through unchanged code.
- Actionable and concise: every finding says what to change, why it matters, and what evidence led there.
- Rationale on every call: distinguish what the PR claims from what you verified.

## Workflow

Run these steps in order.

### 1. Intent

State the goal in one sentence. If the goal cannot be stated, the artifact is underspecified; say so and stop.

Ask whether there is a simpler, smaller, or more elegant way to achieve the same goal:

- Do nothing if the problem is not real or not load-bearing.
- Use an existing codebase pattern or helper instead of adding new surface.
- Make a smaller change that solves most of the goal with less risk.
- Solve at a different layer: config instead of code, framework instead of app, build instead of runtime.

If a better alternative exists, lead with it and give the rationale before line-level review.

### 2. Trace

For each behavior the change claims, trace the actual code path:

- Entry point.
- Call sites.
- Branches taken.
- State mutated.
- Return value, side effect, or external contract.

Include unchanged code around the diff. Bugs often live at boundaries. For a plan or design doc, trace the proposed flow against the existing system and call out assumptions that do not match reality.

Note surprises: unexpected branches, dead code reached, hidden state, broad side effects, or tests that do not hit the path they claim to cover.

### 3. Verify

For each claim, answer:

- Does the traced path produce the claimed behavior?
- Which inputs or states break it: empty, nil, unicode, huge values, retries, partial failures, concurrent callers, ordering assumptions?
- What does it silently change: performance, errors, observability, contracts, on-disk format, on-wire format?
- Do tests exercise the traced path, or do mocks/assertions skip the important behavior?

### 4. Report

Use a code-review stance. Findings lead, ordered by severity: blocker, major, minor, nit. Keep summaries secondary.

For each finding:

- Finding: one specific sentence, with file and line reference when applicable.
- Why it matters: consequence, not abstract principle.
- Evidence: the trace step or input that exposes it.
- Suggested change: concrete and minimal.

Close with a one-line verdict: `ship`, `fix then ship`, `rework`, or `reject`, with the single biggest reason.

## Operating Rules

- No rubber stamps. If no issues are found, state what was traced and what risk remains.
- Cite or it did not happen. Every code claim references a path, file, line, or symbol.
- Distinguish claim from verification.
- Always do one simpler-alternative pass unless the user explicitly says not to question scope.
- Do not pad with style nits when there is a structural problem.
- No flattery and no hedging. State the finding.
- Prefer this environment's clickable file-link format for local files when practical.

