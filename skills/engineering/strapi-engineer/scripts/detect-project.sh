#!/usr/bin/env bash
# Detects Strapi project context and outputs pre-filled .context/ domain drafts.
# Run from the Strapi project root: bash <path>/detect-project.sh
# The output is printed to stdout — review and split into .context/ files.

set -euo pipefail

ROOT="${1:-.}"
PKG="$ROOT/package.json"

# ── helpers ──────────────────────────────────────────────────────────────────

dep_version() {
  # Strips the semver range prefix (^~>=) from a dependency's version string
  if [[ -f "$PKG" ]]; then
    python3 -c "
import json,re
d=json.load(open('$PKG'))
deps={**d.get('dependencies',{}),**d.get('devDependencies',{})}
v=deps.get('$1','___')
print(re.sub(r'^[\^~>=]+','',v) if v!='___' else '___')
" 2>/dev/null || echo "___"
  else
    echo "___"
  fi
}

has_dep() {
  if [[ -f "$PKG" ]]; then
    python3 -c "
import json
d=json.load(open('$PKG'))
deps={**d.get('dependencies',{}),**d.get('devDependencies',{})}
print('yes' if '$1' in deps else 'no')
" 2>/dev/null || echo "no"
  else
    echo "no"
  fi
}

# ── Strapi version ───────────────────────────────────────────────────────────

STRAPI_VERSION=$(dep_version "@strapi/strapi")
MAJOR="${STRAPI_VERSION%%.*}"
case "$MAJOR" in
  5) DATA_API="documents API — strapi.documents('api::x.x')" ;;
  4) DATA_API="entityService — strapi.entityService" ;;
  *) DATA_API="___" ;;
esac

# ── TypeScript ───────────────────────────────────────────────────────────────

if [[ -f "$ROOT/tsconfig.json" ]]; then TYPESCRIPT="yes"; else TYPESCRIPT="no"; fi

# ── Package manager ──────────────────────────────────────────────────────────

if   [[ -f "$ROOT/pnpm-lock.yaml" ]];    then PKG_MANAGER="pnpm"
elif [[ -f "$ROOT/yarn.lock" ]];         then PKG_MANAGER="yarn"
elif [[ -f "$ROOT/package-lock.json" ]]; then PKG_MANAGER="npm"
elif [[ -f "$ROOT/bun.lockb" ]];         then PKG_MANAGER="bun"
else PKG_MANAGER="___"; fi

# ── Database ─────────────────────────────────────────────────────────────────

DATABASE="___"
for db in pg mysql2 better-sqlite3 sqlite3; do
  if [[ $(has_dep "$db") == yes ]]; then
    case "$db" in
      pg)                    DATABASE="postgres" ;;
      mysql2)                DATABASE="mysql" ;;
      better-sqlite3|sqlite3) DATABASE="sqlite" ;;
    esac
    break
  fi
done

# ── Content types ────────────────────────────────────────────────────────────
# Each content type is a schema.json under src/api/<name>/content-types/.

CONTENT_TYPES="___"
if [[ -d "$ROOT/src/api" ]]; then
  count=$(find "$ROOT/src/api" -name "schema.json" -path "*/content-types/*" 2>/dev/null | wc -l | tr -d ' ')
  CONTENT_TYPES="$count"
fi

# ── Draft/publish and i18n ───────────────────────────────────────────────────
# Both are per-content-type schema options, so any occurrence means the project
# uses the feature somewhere and generated code must account for it.

DRAFT_PUBLISH="no"
if [[ -d "$ROOT/src/api" ]] &&
   grep -rqE '"draftAndPublish"[[:space:]]*:[[:space:]]*true' "$ROOT/src/api" 2>/dev/null; then
  DRAFT_PUBLISH="yes"
fi

I18N="no"
if [[ $(has_dep "@strapi/plugin-i18n") == yes ]]; then
  I18N="plugin installed"
fi
if [[ -d "$ROOT/src/api" ]] &&
   grep -rqE '"i18n"' "$ROOT/src/api" 2>/dev/null; then
  I18N="enabled on content types"
fi

# ── GraphQL ──────────────────────────────────────────────────────────────────

GRAPHQL="no"
if [[ $(has_dep "@strapi/plugin-graphql") == yes ]]; then GRAPHQL="yes"; fi

# ── Auth ─────────────────────────────────────────────────────────────────────

AUTH="users-permissions (default)"
if [[ $(has_dep "@strapi/plugin-users-permissions") == no ]]; then AUTH="___"; fi
if [[ -d "$ROOT/src" ]] &&
   grep -rqE 'jsonwebtoken|passport|oidc' "$ROOT/src" 2>/dev/null; then
  AUTH="$AUTH + custom token handling"
fi

# ── Custom plugins and extensions ────────────────────────────────────────────

PLUGINS="none"
if [[ -d "$ROOT/src/plugins" ]]; then
  n=$(find "$ROOT/src/plugins" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  [[ "$n" != "0" ]] && PLUGINS="$n local plugin(s)"
fi

EXTENSIONS="none"
if [[ -d "$ROOT/src/extensions" ]]; then
  n=$(find "$ROOT/src/extensions" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  [[ "$n" != "0" ]] && EXTENSIONS="$n extension(s)"
fi

# ── Tests ────────────────────────────────────────────────────────────────────

TEST_RUNNER="___"
for t in jest vitest mocha; do
  if [[ $(has_dep "$t") == yes ]]; then TEST_RUNNER="$t"; break; fi
done
if [[ $(has_dep "supertest") == yes ]]; then TEST_RUNNER="$TEST_RUNNER + supertest"; fi

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

- Backend: Strapi $STRAPI_VERSION
- Database: $DATABASE
- TypeScript: $TYPESCRIPT
- Frontend: ___
- Infrastructure: ___

## Repo Structure

- Content types: $CONTENT_TYPES under src/api/
- Local plugins: $PLUGINS
- Extensions: $EXTENSIONS

[What lives where, and which APIs own which domain]

## Environment

- Package manager: $PKG_MANAGER

[Dev setup, env vars, local run commands]

## Glossary

| Term | Meaning |
|---|---|
| ___ | ___ |

---

# .context/engineering.md — draft generated by detect-project.sh

# Engineering Context

## Conventions

- Strapi version: $STRAPI_VERSION
- Data API: $DATA_API
- Draft/publish: $DRAFT_PUBLISH
- i18n: $I18N
- GraphQL: $GRAPHQL
- Auth: $AUTH
- TypeScript: $TYPESCRIPT

## Testing Strategy

- Test runner: $TEST_RUNNER

[Which layer tests target — controller, service, or policy]

## Framework Notes

[Version-specific rules, populate conventions, or non-obvious behaviours]

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
  echo "  Strapi:         $STRAPI_VERSION"
  echo "  Data API:       $DATA_API"
  echo "  Database:       $DATABASE"
  echo "  TypeScript:     $TYPESCRIPT"
  echo "  Package mgr:    $PKG_MANAGER"
  echo "  Content types:  $CONTENT_TYPES"
  echo "  Draft/publish:  $DRAFT_PUBLISH"
  echo "  i18n:           $I18N"
  echo "  GraphQL:        $GRAPHQL"
  echo "  Auth:           $AUTH"
  echo "  Plugins:        $PLUGINS"
  echo "  Extensions:     $EXTENSIONS"
  echo "  Test runner:    $TEST_RUNNER"
  echo "  Main branch:    $MAIN_BRANCH"
  echo "  Ticket prefix:  $TICKET_PREFIX"
  echo ""
  echo "Review the output above, fill in any ___ blanks, then save into .context/ domain files"
} >&2
