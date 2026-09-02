# Python Project Context

Use this reference when project code changes are needed and `.context/INDEX.md`, `.context/project.md`, or `.context/engineering.md` is missing, stale, or too incomplete to choose Python patterns safely.

## Existing Context

If `.context/INDEX.md` exists, read it first to see which domain files are available. Then read only the files needed for the Python task:

- `.context/project.md` for stack, repo layout, environment, and vocabulary.
- `.context/engineering.md` for Python version floor, package manager, source layout, linter, formatter, type checker and strictness, test runner, async posture, and data-access conventions when the project records them there.
- `.context/git-workflow.md` when branch names, commits, or PR text are involved.
- `.context/security.md`, `.context/learning.md`, or `.context/adr/` when the task touches those concerns.

Ask before generating code when either the Python version floor or the type-checker strictness is blank and the current task depends on it.

## Four Facts That Change Generated Code

Establish these before writing anything non-trivial. Each one silently changes what correct code looks like.

| Fact | Where to find it | Why it matters |
|---|---|---|
| Python version floor | `requires-python` in `pyproject.toml`, CI matrix | Decides `match`, `X \| Y` unions, `tomllib`, `ExceptionGroup`, generics syntax |
| Package manager | The lockfile — `uv.lock`, `poetry.lock`, `pdm.lock`, `Pipfile.lock` | Decides how a dependency is added and how the test command is invoked |
| Source layout | `src/` present or not | `src` layout keeps the package off `sys.path` during tests, so imports differ |
| Type-checker strictness | `[tool.mypy]`/`[tool.pyright]` in `pyproject.toml` | Under strict, an unannotated helper or a bare `Any` fails the build |

A project pinned to Python 3.9 rejects code that a 3.12 project takes without comment, and the failure appears in CI rather than at the keyboard. Read the floor first.

## Stale Context

Offer to update the relevant `.context/` domain file when the user mentions or the repo shows:

- A Python version floor moving, especially onto 3.10 (`match`, `X | Y`) or 3.11 (`tomllib`, `ExceptionGroup`)
- Migration between package managers, or pip to a lockfile-based tool
- A move from flat layout to `src` layout
- Adoption or replacement of the linter, formatter, or type checker — especially Ruff replacing Flake8, isort, or Black
- Type checking turning strict, or a per-module override being added
- A sync codebase adopting async, or a framework change that forces it
- Test runner migration, or a change in where tests may reach

## Missing Context

Run the detector from the skill directory:

```bash
bash <skill-dir>/scripts/detect-project.sh .
```

The script inspects `pyproject.toml`, `setup.cfg`, `requirements*.txt`, lockfiles, the source layout, the test directory, declared dependencies, and git history, then prints draft content for `.context/project.md`, `.context/engineering.md`, and `.context/git-workflow.md`.

If the detector cannot run, ask for the missing values that affect the work:

- Python version floor
- Package manager and lockfile
- Source layout: `src` or flat
- Linter, formatter, and type checker, and whether strict mode is on
- Test runner, test directory, and whether async tests are supported
- Web framework, if any, and whether the codebase is sync or async
- Data-access library and migration tool
- Main branch name
- Ticket prefix, if commit or PR output is needed

## Files to Create

When context files are missing and the user accepts context setup, tell them to run `/setup-context`. It scaffolds:

- `.context/INDEX.md`: available context domains
- `.context/project.md`: stack, repo layout, environment, and vocabulary
- `.context/engineering.md`: Python and testing conventions
- `.context/git-workflow.md`: branch, commit, and release conventions

Create provider stubs only if they do not already exist:

- `CLAUDE.md`
- `AGENTS.md`
- `GEMINI.md`
- `.cursorrules`
- `.github/copilot-instructions.md`
- `.windsurfrules`

## If the User Says to Skip Context

Proceed with reasonable assumptions, state those assumptions briefly, and avoid broad structural changes that depend on unknown project conventions. Still read `pyproject.toml` for `requires-python` and check whether `src/` exists — those two reads cost nothing and prevent the most common category of wrong-version code.
