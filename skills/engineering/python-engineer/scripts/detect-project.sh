#!/usr/bin/env bash
# Detects Python project context and outputs pre-filled .context/ domain drafts.
# Run from the Python project root: bash <path>/detect-project.sh
# The output is printed to stdout — review and split into .context/ files.

set -euo pipefail

ROOT="${1:-.}"
PYPROJECT="$ROOT/pyproject.toml"

# ── helpers ──────────────────────────────────────────────────────────────────

toml_get() {
  # $1 = dotted table path, $2 = key. Reads pyproject.toml without extra deps.
  [[ -f "$PYPROJECT" ]] || { echo "___"; return; }
  python3 - "$PYPROJECT" "$1" "$2" <<'PY' 2>/dev/null || echo "___"
import sys
try:
    import tomllib
except ModuleNotFoundError:                      # Python 3.10 and earlier
    try:
        import tomli as tomllib
    except ModuleNotFoundError:
        print("___"); raise SystemExit
path, table, key = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path, "rb") as fh:
        d = tomllib.load(fh)
    for part in filter(None, table.split(".")):
        d = d[part]
    v = d[key]
except Exception:
    print("___"); raise SystemExit
print(", ".join(map(str, v)) if isinstance(v, list) else v)
PY
}

# Searches every declared dependency source for a package name.
has_dep() {
  local needle="$1"
  {
    [[ -f "$PYPROJECT" ]] && cat "$PYPROJECT" || true
    for f in "$ROOT"/requirements*.txt "$ROOT/setup.cfg" "$ROOT/setup.py" \
             "$ROOT/Pipfile" "$ROOT/environment.yml"; do
      [[ -f "$f" ]] && cat "$f" || true
    done
  } 2>/dev/null | grep -qiE "(^|[^a-z0-9_.-])${needle}([^a-z0-9_.-]|$)" && echo yes || echo no
}

first_present() {
  # Echoes the first argument naming an existing file, else ___
  for f in "$@"; do
    if [[ -e "$ROOT/$f" ]]; then echo "$f"; return; fi
  done
  echo "___"
}

# ── Packaging and toolchain ──────────────────────────────────────────────────

PY_REQUIRES=$(toml_get "project" "requires-python")
PROJECT_NAME=$(toml_get "project" "name")
BUILD_BACKEND=$(toml_get "build-system" "build-backend")

LOCKFILE=$(first_present "uv.lock" "poetry.lock" "pdm.lock" "Pipfile.lock" "requirements.lock")
case "$LOCKFILE" in
  uv.lock)          PKG_MANAGER="uv" ;;
  poetry.lock)      PKG_MANAGER="poetry" ;;
  pdm.lock)         PKG_MANAGER="pdm" ;;
  Pipfile.lock)     PKG_MANAGER="pipenv" ;;
  requirements.lock) PKG_MANAGER="pip-tools" ;;
  *) if   [[ -f "$ROOT/requirements.txt" ]]; then PKG_MANAGER="pip + requirements.txt"
     elif [[ -f "$PYPROJECT" ]];            then PKG_MANAGER="pip + pyproject.toml"
     else PKG_MANAGER="___"; fi ;;
esac

# ── Source layout ────────────────────────────────────────────────────────────
# src/ layout keeps the package off sys.path during test runs; flat does not.

if   [[ -d "$ROOT/src" ]];              then LAYOUT="src layout (src/<package>/)"
elif [[ -f "$ROOT/setup.py" || -f "$PYPROJECT" || -f "$ROOT/setup.cfg" ]]; then LAYOUT="flat layout (<package>/ at repo root)"
else LAYOUT="___"; fi

# ── Linter, formatter, type checker ──────────────────────────────────────────

LINTER="___"
if   [[ $(has_dep "ruff")   == yes ]]; then LINTER="ruff"
elif [[ $(has_dep "flake8") == yes ]]; then LINTER="flake8"
elif [[ $(has_dep "pylint") == yes ]]; then LINTER="pylint"
fi

FORMATTER="___"
if [[ $(has_dep "black") == yes ]]; then
  FORMATTER="black"
elif [[ -f "$PYPROJECT" ]] && grep -q "ruff.format\|\[tool.ruff\]" "$PYPROJECT" 2>/dev/null; then
  FORMATTER="ruff format"
fi

TYPE_CHECKER="___"
for tc in mypy pyright ty pyrefly; do
  if [[ $(has_dep "$tc") == yes ]]; then TYPE_CHECKER="$tc"; break; fi
done

STRICT="___"
if [[ -f "$PYPROJECT" ]]; then
  grep -qE '^\s*strict\s*=\s*true' "$PYPROJECT" 2>/dev/null && STRICT="yes" || STRICT="no"
fi

# ── Tests ────────────────────────────────────────────────────────────────────

TEST_RUNNER="___"
if   [[ $(has_dep "pytest") == yes ]]; then TEST_RUNNER="pytest"
elif [[ -d "$ROOT/tests" ]];           then TEST_RUNNER="unittest (no pytest declared)"
fi

TEST_DIR=$(first_present "tests" "test" "src/tests")

ASYNC_TESTS="no"
if [[ $(has_dep "pytest-asyncio") == yes || $(has_dep "anyio") == yes ]]; then ASYNC_TESTS="yes"; fi

# ── Frameworks and data access ───────────────────────────────────────────────

WEB_FRAMEWORK="___"
for fw in fastapi django flask starlette litestar aiohttp; do
  if [[ $(has_dep "$fw") == yes ]]; then WEB_FRAMEWORK="$fw"; break; fi
done

DATA_ACCESS="___"
for db in sqlalchemy django tortoise-orm peewee psycopg asyncpg sqlmodel; do
  if [[ $(has_dep "$db") == yes ]]; then DATA_ACCESS="$db"; break; fi
done

MIGRATIONS="___"
if   [[ $(has_dep "alembic") == yes ]]; then MIGRATIONS="alembic"
elif [[ -d "$ROOT/migrations" ]];       then MIGRATIONS="migrations/ present"
fi

ASYNC_STACK="no"
if [[ $(has_dep "anyio") == yes || $(has_dep "trio") == yes ]] ||
   [[ "$WEB_FRAMEWORK" =~ ^(fastapi|starlette|litestar|aiohttp)$ ]]; then
  ASYNC_STACK="yes"
fi

VALIDATION="___"
for v in pydantic attrs marshmallow msgspec; do
  if [[ $(has_dep "$v") == yes ]]; then VALIDATION="$v"; break; fi
done

CLI_FRAMEWORK="___"
for c in typer click argparse; do
  if [[ $(has_dep "$c") == yes ]]; then CLI_FRAMEWORK="$c"; break; fi
done

# ── Git ──────────────────────────────────────────────────────────────────────

MAIN_BRANCH="___"
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  MAIN_BRANCH=$(git -C "$ROOT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)
  if [[ -z "$MAIN_BRANCH" ]]; then
    MAIN_BRANCH=$(git -C "$ROOT" branch --list main master 2>/dev/null | head -1 | tr -d ' *' || true)
  fi
  if [[ -z "$MAIN_BRANCH" ]]; then MAIN_BRANCH="___"; fi
fi

TICKET_PREFIX=$(git -C "$ROOT" log --oneline -50 2>/dev/null |
  grep -oE '\b[A-Z][A-Z0-9]+-[0-9]+' | cut -d- -f1 | sort | uniq -c | sort -rn | head -1 |
  awk '{print $2}' || true)
if [[ -z "$TICKET_PREFIX" ]]; then TICKET_PREFIX="___"; fi

# ── Output ───────────────────────────────────────────────────────────────────

cat <<EOF
# .context/project.md — draft generated by detect-project.sh

# Project Context

## Stack

- Language: Python ${PY_REQUIRES}
- Package: $PROJECT_NAME
- Web framework: $WEB_FRAMEWORK
- Data access: $DATA_ACCESS
- Migrations: $MIGRATIONS
- Infrastructure: ___

## Repo Structure

- Layout: $LAYOUT
- Tests: $TEST_DIR

[What lives where, and which modules own which concern]

## Environment

- Package manager: $PKG_MANAGER
- Lockfile: $LOCKFILE
- Build backend: $BUILD_BACKEND

[Dev setup, env vars, local run commands]

## Glossary

| Term | Meaning |
|---|---|
| ___ | ___ |

---

# .context/engineering.md — draft generated by detect-project.sh

# Engineering Context

## Conventions

- Python requires: $PY_REQUIRES
- Source layout: $LAYOUT
- Linter: $LINTER
- Formatter: $FORMATTER
- Type checker: $TYPE_CHECKER
- Strict typing: $STRICT
- Validation/serialization: $VALIDATION
- Async stack: $ASYNC_STACK
- CLI framework: $CLI_FRAMEWORK

## Testing Strategy

- Test runner: $TEST_RUNNER
- Test directory: $TEST_DIR
- Async test support: $ASYNC_TESTS

[Which boundary tests target, and what may be mocked]

## Framework Notes

[Version-specific rules or non-obvious behaviours]

---

# .context/git-workflow.md — draft generated by detect-project.sh

# Git Workflow

## Branch Naming

- Main branch: $MAIN_BRANCH
- Ticket prefix: $TICKET_PREFIX
- Strategy: ___

## Commit Convention

[Commit format and scope rules]

## Pull Requests

[PR template, reviewer rules, merge strategy]

## Protected Branches

[main, release/*, etc. and what protection applies]
EOF

# ── Summary to stderr (so it doesn't pollute the draft output) ───────────────

{
  echo ""
  echo "=== Detection summary ==="
  echo "  Python requires: $PY_REQUIRES"
  echo "  Package manager: $PKG_MANAGER  (lockfile: $LOCKFILE)"
  echo "  Layout:          $LAYOUT"
  echo "  Linter:          $LINTER"
  echo "  Formatter:       $FORMATTER"
  echo "  Type checker:    $TYPE_CHECKER  (strict: $STRICT)"
  echo "  Test runner:     $TEST_RUNNER   (dir: $TEST_DIR, async: $ASYNC_TESTS)"
  echo "  Web framework:   $WEB_FRAMEWORK"
  echo "  Data access:     $DATA_ACCESS   (migrations: $MIGRATIONS)"
  echo "  Async stack:     $ASYNC_STACK"
  echo "  Main branch:     $MAIN_BRANCH"
  echo "  Ticket prefix:   $TICKET_PREFIX"
  echo ""
  echo "Review the output above, fill in any ___ blanks, then save into .context/ domain files"
} >&2
