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

**Bad tests** are coupled to implementation. They mock internal collaborators, test private methods, or verify through external means (querying a database directly instead of using the interface). Warning sign: the test breaks when you refactor, but observable behavior has not changed.

## Anti-Pattern: Horizontal Slices

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

- [ ] Test describes behavior, not implementation
- [ ] Test uses public interface only
- [ ] Test would survive an internal refactor
- [ ] Code is minimal for this test
- [ ] No speculative features added

## Workflow

1. **Load relevant context.** Read `.context/INDEX.md` when present, then load useful domains such as `.context/project.md`, `.context/engineering.md`, `.context/learning.md`, and `.context/adr/`.
2. **Plan and confirm.** Identify the public interface and list the behaviors to test (not implementation steps). Confirm with the user which behaviors matter most and get approval on the plan before writing any code. Ask: "What should the public interface look like? Which behaviors are most important to test?"
3. **Tracer bullet.** Write one test that confirms one thing about the system end-to-end. Run it and confirm it fails for the expected reason. This proves the path works before you commit to the rest.
4. **Green.** Make the smallest production change that passes the current test. Avoid speculative branches, abstractions, configuration, or future behavior.
5. **Repeat vertically.** Add the next test only after the previous slice is green. Let each cycle respond to what the last one revealed.
6. **Refactor while green.** Simplify names, structure, duplication, and boundaries. Look for: extract duplication, deepen modules (move complexity behind simple interfaces), apply SOLID principles where natural, consider what new code reveals about existing code. Rerun focused tests after each meaningful refactor, then broaden the test run.
7. **Report the loop.** Summarize behaviors added, tests written, implementation changed, and validation run.

## Testing Rules

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
- [interface-design.md](interface-design.md): API shapes that make tests natural.
- [deep-modules.md](deep-modules.md): small interfaces with deep implementations.
- [refactoring.md](refactoring.md): cleanup candidates after green.

## Next Step

Get explicit approval on which behaviors matter most before writing any code (see Workflow step 2) — this is the approval gate for this skill.

- **If approved and the planned slices are complete:** use `scrutinize` or `security-audit` for review, then hand off to shipping (`triage`, `post-mortem`, `management-talk`).
- **If the plan isn't approved yet:** get explicit approval on which behaviors matter most before writing any code — do not start the tracer bullet until that approval is explicit.
