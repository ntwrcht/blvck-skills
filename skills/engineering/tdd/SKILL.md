---
name: tdd
description: >
  Test-driven development with a red-green-refactor loop. Use when the user
  asks for TDD, test-first development, red-green-refactor, or wants a feature
  or bug fix implemented one behavior at a time through failing tests,
  minimal implementation, and refactoring.
---

# Test-Driven Development

Use a vertical red-green-refactor loop: one behavior, one failing test, one
minimal implementation, then repeat. Tests should verify behavior through public
interfaces, not implementation details.

## Operating Stance

- Behavior first: name tests after what callers or users can observe.
- Public interface only: avoid testing private methods or internal structure.
- Integration-style by default: exercise real code paths unless a system boundary
  makes that impractical.
- One slice at a time: do not write all tests first and all implementation after.
- Refactor only while green: never clean up while tests are failing.

## Workflow

### 1. Frame the Behavior

Before coding, identify the public interface and the first behavior to prove.
If the interface, priority, or risk is unclear, ask the user:

> What should the public interface look like? Which behaviors matter most?

For small or obvious changes, infer from the codebase and continue. Use the
project's domain vocabulary in test names and respect ADRs or local conventions
around the code being touched.

### 2. Red

Write one test for one observable behavior.

Checklist:

- The test fails for the expected reason.
- The test describes behavior, not implementation.
- The test uses the public interface.
- The test would survive an internal refactor.

### 3. Green

Write the smallest code change that makes the current test pass.

Rules:

- Do not anticipate future tests.
- Do not add speculative branches, types, or configuration.
- Keep mocks at system boundaries only.
- Run the focused test until it passes.

### 4. Repeat

Add the next behavior only after the previous test is green. Each test should
respond to what the last cycle revealed.

Avoid horizontal slicing:

```text
Wrong: test1, test2, test3 -> impl1, impl2, impl3
Right: test1 -> impl1 -> test2 -> impl2 -> test3 -> impl3
```

### 5. Refactor

After all intended behavior is green, simplify the design and rerun tests after
each meaningful refactor. Prefer deep modules: small interfaces with complexity
hidden inside.

## References

Load only the reference needed for the current decision:

- [tests.md](tests.md): good and bad behavior tests.
- [mocking.md](mocking.md): when to mock and how to design mockable boundaries.
- [interface-design.md](interface-design.md): interface choices that make tests natural.
- [deep-modules.md](deep-modules.md): small interfaces with deep implementations.
- [refactoring.md](refactoring.md): cleanup candidates after green.
