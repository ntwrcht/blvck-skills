---
name: tdd
description: "Develop behavior through red-green-refactor test slices that exercise public interfaces and real code paths. Use when adding features, fixing bugs with regression tests, shaping APIs through examples, or refactoring while preserving observable behavior."
---

# Test-Driven Development

Work in vertical behavior slices: one failing test, one minimal implementation, one refactor pass while green.

## When to Use

Use this skill when the user asks for TDD, red-green-refactor, regression tests before a bug fix, API behavior examples, or implementation driven by observable behavior.

Use `debug-mantra` first when the failure mechanism is unknown. Use `scrutinize` for review-only work where no implementation is requested.

## Core Rule

Tests should describe what callers or users observe through public interfaces. Avoid locking tests to private methods, incidental structure, or implementation order.

## Workflow

1. **Frame the first behavior.** Identify the public interface, expected observable outcome, and first risk to prove. For obvious changes, infer from local code and continue.
2. **Red.** Write one focused test for one behavior. Run it and confirm it fails for the expected reason.
3. **Green.** Make the smallest production change that passes the current test. Avoid speculative branches, abstractions, configuration, or future behavior.
4. **Repeat vertically.** Add the next test only after the previous slice is green. Let each cycle respond to what the last one revealed.
5. **Refactor while green.** Simplify names, structure, duplication, and boundaries. Rerun focused tests after each meaningful refactor, then broaden the test run.
6. **Report the loop.** Summarize behaviors added, tests written, implementation changed, and validation run.

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
