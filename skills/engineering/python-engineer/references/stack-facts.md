# Python Stack Facts

The Python-specific facts a task must establish before generating code. The shared skeleton for reading, repairing, or skipping `.context/` is `references/project-context.md`; this file is what it points at.

## Recorded In Context

`.context/engineering.md` holds the Python version floor, package manager, source layout, linter, formatter, type checker and strictness, test runner, async posture, and data-access conventions when the project records them there. Ask before generating code when either the Python version floor or the type-checker strictness is blank and the current task depends on it.

## Facts That Change Generated Code

Establish these before writing anything non-trivial. Each one silently changes what correct code looks like.

| Fact | Where to find it | Why it matters |
|---|---|---|
| Python version floor | `requires-python` in `pyproject.toml`, CI matrix | Decides `match`, `X \| Y` unions, `tomllib`, `ExceptionGroup`, generics syntax |
| Package manager | The lockfile — `uv.lock`, `poetry.lock`, `pdm.lock`, `Pipfile.lock` | Decides how a dependency is added and how the test command is invoked |
| Source layout | `src/` present or not | `src` layout keeps the package off `sys.path` during tests, so imports differ |
| Type-checker strictness | `[tool.mypy]`/`[tool.pyright]` in `pyproject.toml` | Under strict, an unannotated helper or a bare `Any` fails the build |

A project pinned to Python 3.9 rejects code that a 3.12 project takes without comment, and the failure appears in CI rather than at the keyboard. Read the floor first.

## Stale When

Offer to update the relevant `.context/` domain file when the user mentions or the repo shows:

- A Python version floor moving, especially onto 3.10 (`match`, `X | Y`) or 3.11 (`tomllib`, `ExceptionGroup`)
- Migration between package managers, or pip to a lockfile-based tool
- A move from flat layout to `src` layout
- Adoption or replacement of the linter, formatter, or type checker — especially Ruff replacing Flake8, isort, or Black
- Type checking turning strict, or a per-module override being added
- A sync codebase adopting async, or a framework change that forces it
- Test runner migration, or a change in where tests may reach

## Ask For

The bundled detector (`scripts/detect-project.sh`) inspects `pyproject.toml`, `setup.cfg`, `requirements*.txt`, lockfiles, the source layout, the test directory, declared dependencies, and git history. If it cannot run, ask for:

- Python version floor
- Package manager and lockfile
- Source layout: `src` or flat
- Linter, formatter, and type checker, and whether strict mode is on
- Test runner, test directory, and whether async tests are supported
- Web framework, if any, and whether the codebase is sync or async
- Data-access library and migration tool
- Main branch name
- Ticket prefix, if commit or PR output is needed

## Read Anyway

Still read `pyproject.toml` for `requires-python` and check whether `src/` exists — those two reads cost nothing and prevent the most common category of wrong-version code.
