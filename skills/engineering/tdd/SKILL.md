---
name: tdd
description: "Develops behavior through red-green-refactor test slices that exercise public interfaces and real code paths. Use when adding features, fixing bugs with regression tests, shaping APIs through examples, or refactoring while preserving observable behavior."
---

# Test-Driven Development

Work in vertical behavior slices: one failing test, one minimal implementation, one refactor pass while green.

## When to Use

Use this skill when the user asks for TDD, red-green-refactor, regression tests before a bug fix, API behavior examples, or implementation driven by observable behavior.

Use `debug-mantra` first when the failure mechanism is unknown. Use `scrutinize` for review-only work where no implementation is requested.

## Artifacts

- Produces: tests + implementation
- Consumes: stories at the `story` key path (if present) — see `references/artifact-paths.md` (default `docs/stories/<slug>.md`), `.context/project.md`, `.context/engineering.md`, `.context/learning.md`, `.context/adr/`

## Philosophy

Tests verify behavior through public interfaces, not implementation details — code can change entirely; tests should not.

**Good tests** are integration-style: they exercise real code paths through public APIs and read like specifications. "User can checkout with valid cart" tells you exactly what capability exists and survives refactors because it does not care about internal structure.

**Bad tests** are coupled to implementation, tautological, or written in bulk before any code exists. See **Anti-Patterns** below for each one's tell.

## Seams: where tests go

A **seam** is the public boundary you test at — the interface where you observe behavior without reaching inside. Tests live at seams, never against internals.

**Test only at pre-agreed seams.** Before writing any test, write down the seams under test and confirm them with the user. No test is written at an unconfirmed seam.

You can't test everything. Agreeing the seams up front is how testing effort lands on the critical paths and complex logic instead of spreading evenly across every edge case. Ask: "What's the public interface, and which seams should we test?"

When the shape of that interface is itself in question — how deep the module is, where the seam belongs, what the interface should expose — use the `codebase-design` skill for the vocabulary. It is the shared source of the module, interface, depth, seam, adapter, leverage and locality terms, and it is reference to consult mid-slice, not a design session to run.

## Anti-Patterns

### Implementation-coupled

The test mocks internal collaborators, tests private methods, or verifies through a side channel — querying the database directly instead of going through the interface. **The tell:** the test breaks when you refactor, but behavior hasn't changed.

### Tautological

The assertion recomputes the expected value the way the code does — `expect(add(a, b)).toBe(a + b)`, a snapshot derived by hand the same way, a constant asserted equal to itself. It passes by construction, so it can never disagree with the code.

Expected values must come from an independent source of truth: a known-good literal, a worked example, the spec.

### Horizontal slicing

Do not write all tests first, then all implementation. This is horizontal slicing — treating RED as "write all tests" and GREEN as "write all code."

This produces unreliable tests:
- Tests written in bulk test imagined behavior, not actual behavior
- You end up testing the shape of things (data structures, function signatures) rather than user-facing behavior
- Tests become insensitive to real changes — they pass when behavior breaks, fail when behavior is fine

Correct approach — vertical slices via tracer bullets:

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
  ...
```

## Core Rule

Tests should describe what callers or users observe through public interfaces. Avoid locking tests to private methods, incidental structure, or implementation order.

## Checklist Per Cycle

Before moving to the next slice, confirm:

- [ ] Test sits at a seam the user confirmed
- [ ] Expected value comes from an independent source, not a recomputation
- [ ] Test describes behavior, not implementation
- [ ] Test uses public interface only
- [ ] Test would survive an internal refactor
- [ ] Code is minimal for this test
- [ ] No speculative features added

## Workflow

1. **Load relevant context.** Read `.context/INDEX.md` when present, then load useful domains such as `.context/project.md`, `.context/engineering.md`, `.context/learning.md`, and `.context/adr/`.
2. **Agree the seams, then the behaviors.** Write down the seams under test and confirm them with the user — no test is written at an unconfirmed seam. Then list the behaviors to test at those seams (not implementation steps) and get approval before writing any code. Ask: "What's the public interface, which seams should we test, and which behaviors matter most?"
3. **Tracer bullet.** Write one test that confirms one thing about the system end-to-end. Run it and confirm it fails for the expected reason. This proves the path works before you commit to the rest.
4. **Green.** Make the smallest production change that passes the current test. Avoid speculative branches, abstractions, configuration, or future behavior.
5. **Repeat vertically.** Add the next test only after the previous slice is green. Let each cycle respond to what the last one revealed.
6. **Refactor while green.** Simplify names, structure, duplication, and seams. Look for: extract duplication, deepen modules (move complexity behind simple interfaces — the `codebase-design` skill carries that vocabulary), apply SOLID principles where natural, consider what new code reveals about existing code. Rerun focused tests after each meaningful refactor, then broaden the test run.
7. **Report the loop.** Summarize behaviors added, tests written, implementation changed, and validation run.

## Testing Rules

- Write tests only at confirmed seams. An unconfirmed seam is an unwritten test.
- Take expected values from an independent source — a known-good literal, a worked example, the spec — never from a recomputation of what the code does.
- Prefer integration-style tests through real code paths unless a system boundary makes that impractical.
- Mock only external boundaries such as network, time, filesystem, randomness, or third-party services.
- Name tests after behavior, not implementation.
- Keep fixtures small and representative.
- A regression test should fail on the old bug and pass with the fix.
- Do not refactor while tests are red.

## Reference Map

Load only the reference needed for the current decision:

- [tests.md](tests.md): behavior test examples and anti-patterns.
- [mocking.md](mocking.md): boundary mocking guidance.
- [refactoring.md](refactoring.md): cleanup candidates after green.

## Next Step

Get explicit approval on the seams under test and which behaviors matter most before writing any code (see Workflow step 2) — this is the approval gate for this skill.

- **If approved and the planned slices are complete:** use `scrutinize` or `security-audit` for review, then hand off to shipping (`post-mortem`, `management-talk`). To move follow-up work onto the tracker, tell the user to run `/triage`.
- **If the plan isn't approved yet:** keep working the seam list and the behavior list with the user — do not start the tracer bullet until both are explicitly approved.
