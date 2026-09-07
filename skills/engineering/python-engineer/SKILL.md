---
name: python-engineer
description: "Builds, modifies, reviews, and debugs Python projects with architecture, packaging, typing, testing, linting, async, data access, and reliability guidance. Use when working on Python application code, libraries, CLIs, services, tooling, refactors, test strategy, or code review."
---

# Python Engineer

Guide Python engineering work with senior judgment: read the project first,
choose boring maintainable designs, preserve local conventions, and validate the
changed behavior.

## When to Use

Use this skill for Python application or library work: project structure, API
design, implementation, refactoring, debugging, code review, type hints, tests,
linting, packaging, async/concurrency, CLIs, web services, data processing,
database access, and architecture decisions.

Use a narrower skill when the request is mainly generic debugging, security
audit, TDD process, stakeholder writing, or a framework-specific workflow where
Python design judgment is only incidental.
When the open question is a module's interface, depth, or seam placement rather
than anything Python-specific, use `codebase-design` — this skill brings the
Python conventions, that one brings the design.

## Artifacts

- Produces: code changes
- Consumes: stories at the `story` key path (if present) — see `references/artifact-paths.md` (default `docs/stories/<slug>.md`), `.context/project.md`, `.context/engineering.md`, `.context/git-workflow.md`, `.context/security.md`, `.context/learning.md`

## Core Rule

Prefer the repository's existing package manager, layout, formatter, linter,
type checker, test runner, dependency style, logging approach, and error
patterns over generic Python examples.

## Quick Path

Answer directly for conceptual questions, explanations, single-line fixes, or
small snippets. Do not run the full project-context workflow unless you are
generating, modifying, reviewing, or debugging project code.

## Workflow

1. Inspect local context before changing code. Read `.context/INDEX.md` when
   present, then load relevant domain files such as `.context/project.md`, `.context/engineering.md`,
   `.context/git-workflow.md`, `.context/security.md`, `.context/learning.md`,
   and `.context/adr/`, plus `pyproject.toml`, `setup.cfg`, `setup.py`,
   `requirements*.txt`, lockfiles, source layout, tests, and nearby
   implementation patterns. If context is missing and project code changes are
   needed, follow `references/project-context.md`.
2. Load only the reference files needed for the task from the Reference Map.
3. For structural or cross-module changes, state the problem shape, ownership
   boundary, key tradeoff, and validation plan before editing.
4. Make the smallest cohesive change that preserves existing behavior unless the
   user requested a behavior change.
5. Keep public interfaces typed, boring, and stable; narrow `Any` near the edge.
6. Put domain logic outside framework, database, HTTP, CLI, and subprocess
   boundaries where practical.
7. Add or update tests at the same boundary callers use, with mocks only around
   true external systems.
8. Validate with the repo's focused test, lint, format, typecheck, build, or
   runtime check when practical.

## Engineering Defaults

- Prefer explicit dependencies through constructors or functions over hidden
  module-level coupling.
- Use functions for stateless transformations and classes for meaningful state,
  resource lifecycle, protocols, domain concepts, or replaceable adapters.
- Keep serialization, validation, SQL, filesystem paths, subprocess commands,
  network calls, and secrets at clear boundaries.
- Make resource ownership explicit for files, clients, pools, tasks, and
  background workers.
- Add dependencies only when the standard library or current project stack would
  make the code meaningfully worse.

## Version Guide

| Version | Default shape | Common APIs |
|---|---|---|
| 3.9 | `typing` generics | `Dict`/`List` from `typing`, no `match`, no `X \| Y` in annotations |
| 3.10-3.11 | builtin generics | `match`, `X \| Y` unions, `dataclass(slots=True)`, `ExceptionGroup` and `tomllib` from 3.11 |
| 3.12 | inline type params | `type` aliases, PEP 695 generics, `@override`, `itertools.batched` |
| 3.13+ | same model, refined | free-threaded builds as an option, improved REPL and error messages |

Read `requires-python` before choosing any of these. Ask before defaulting when the floor is unclear and the choice affects generated code — the failure otherwise appears in CI, not at the keyboard.

## Output Shape

- Small fix: changed code plus one sentence explaining the issue.
- New feature or refactor: decision note, tests, implementation, validation.
- Code review: findings first with file and line references, then test gaps.
- Architecture question: options, recommendation, tradeoffs, and migration path.
- Tooling setup: chosen tools, config changes, and commands to run.

## Reference Map

Load only the reference needed for the current decision:

- `references/design-and-structure.md`: architecture, module boundaries,
  functions vs classes, data modeling, errors, or dependency choices.
- `references/typing-and-naming.md`: type hints, Protocols, TypedDict,
  dataclasses, naming conventions, or import hygiene.
- `references/linting-tooling.md`: Ruff, Black, pyright, mypy, pytest config,
  packaging metadata, or CI commands.
- `references/testing.md`: unit tests, integration tests, mocks/fakes, fixtures,
  regression tests, or async tests.
- `references/async-security-reliability.md`: asyncio, concurrency, resource
  cleanup, subprocesses, SQL, paths, secrets, retries, or timeouts.
- `references/project-context.md`: reading, repairing, or skipping `.context/` — the shared skeleton.
- `references/stack-facts.md`: the Python facts that change generated code, what makes context stale, and what to ask for when the detector cannot run.
## Next Step

Do not treat a change as done until the project's formatter, linter, type checker, and test suite pass on it.

- **If approved:** hand off to `tdd` when the change needs behavior tests it does not have, to `scrutinize` for an independent review of the diff, or to `security-audit` when it touches auth, secrets, subprocess calls, deserialization, or user input. When the change exposed a shallow module or a contested seam, hand off to `codebase-design` before building more on it.
- **If not approved:** revise in place. When a failure's cause is not obvious from the traceback, escalate to `debug` rather than guessing at fixes.
