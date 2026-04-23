#!/usr/bin/env bash
# Detects Angular project context and outputs a pre-filled .context.md draft.
# Run from the Angular project root: bash <path>/detect-project.sh
# The output is printed to stdout — redirect or paste into .context.md.

set -euo pipefail

ROOT="${1:-.}"
PKG="$ROOT/package.json"
NG_JSON="$ROOT/angular.json"
TS_JSON="$ROOT/tsconfig.json"

# ── helpers ──────────────────────────────────────────────────────────────────

json_field() {
  # $1 = file, $2 = jq filter
  [[ -f "$1" ]] && python3 -c "
import json,sys
try:
  d=json.load(open('$1'))
  v=$2
  print(v if v is not None else '___')
except:
  print('___')
" 2>/dev/null || echo "___"
}

has_dep() {
  # Returns "yes" if package name $1 appears in deps or devDeps
  [[ -f "$PKG" ]] && python3 -c "
import json,sys
d=json.load(open('$PKG'))
deps={**d.get('dependencies',{}),**d.get('devDependencies',{})}
print('yes' if '$1' in deps else 'no')
" 2>/dev/null || echo "no"
}

dep_version() {
  # Strips semver range prefix (^~>=) from dep version string
  [[ -f "$PKG" ]] && python3 -c "
import json,re
d=json.load(open('$PKG'))
deps={**d.get('dependencies',{}),**d.get('devDependencies',{})}
v=deps.get('$1','___')
print(re.sub(r'^[\^~>=]+','',v) if v!='___' else '___')
" 2>/dev/null || echo "___"
}

# ── Angular version ───────────────────────────────────────────────────────────

NG_VERSION=$(dep_version "@angular/core")

# ── Module style ──────────────────────────────────────────────────────────────
# ng17+ defaults to standalone; older projects use NgModule unless opted in.
# Heuristic: look for standalone: true in any app component, else check version.

MODULE_STYLE="NgModule"
if [[ -f "$PKG" ]]; then
  if grep -r --include="*.ts" -l "standalone: true" "$ROOT/src" 2>/dev/null | grep -q .; then
    MODULE_STYLE="standalone"
  elif [[ "$NG_VERSION" != "___" ]]; then
    MAJOR=$(echo "$NG_VERSION" | cut -d. -f1)
    [[ "$MAJOR" -ge 17 ]] 2>/dev/null && MODULE_STYLE="standalone (default ng17+)"
  fi
fi

# ── Design system ─────────────────────────────────────────────────────────────

DESIGN_SYSTEM="unknown"
if [[ $(has_dep "@angular/material") == "yes" ]]; then
  MAT_VER=$(dep_version "@angular/material")
  DESIGN_SYSTEM="Angular Material $MAT_VER"
elif [[ $(has_dep "bootstrap") == "yes" ]]; then
  BS_VER=$(dep_version "bootstrap")
  DESIGN_SYSTEM="Bootstrap $BS_VER"
elif [[ $(has_dep "tailwindcss") == "yes" ]]; then
  TW_VER=$(dep_version "tailwindcss")
  DESIGN_SYSTEM="Tailwind CSS $TW_VER"
elif [[ $(has_dep "ng-zorro-antd") == "yes" ]]; then
  DESIGN_SYSTEM="NG-ZORRO (Ant Design)"
elif [[ $(has_dep "primeng") == "yes" ]]; then
  DESIGN_SYSTEM="PrimeNG $(dep_version primeng)"
fi

# ── Test runner ───────────────────────────────────────────────────────────────

TEST_RUNNER="Karma + Jasmine (default)"
if [[ $(has_dep "jest") == "yes" || $(has_dep "@jest/core") == "yes" || $(has_dep "jest-preset-angular") == "yes" ]]; then
  TEST_RUNNER="Jest"
fi
if [[ $(has_dep "@playwright/test") == "yes" ]]; then
  E2E_RUNNER="Playwright"
elif [[ $(has_dep "cypress") == "yes" ]]; then
  E2E_RUNNER="Cypress"
else
  E2E_RUNNER="none detected"
fi

# ── Strict mode ───────────────────────────────────────────────────────────────

STRICT="___"
if [[ -f "$TS_JSON" ]]; then
  STRICT=$(python3 -c "
import json
d=json.load(open('$TS_JSON'))
co=d.get('compilerOptions',{})
print('true' if co.get('strict') else 'false')
" 2>/dev/null || echo "___")
fi

# ── State management ──────────────────────────────────────────────────────────

STATE="BehaviorSubject / signals"
if [[ $(has_dep "@ngrx/store") == "yes" ]]; then
  STATE="NgRx Store $(dep_version @ngrx/store)"
elif [[ $(has_dep "@ngxs/store") == "yes" ]]; then
  STATE="NGXS"
fi

# ── SSR / Hydration ───────────────────────────────────────────────────────────

SSR="none"
if [[ $(has_dep "@angular/ssr") == "yes" || $(has_dep "@nguniversal/express-engine") == "yes" ]]; then
  SSR="Angular Universal / SSR"
fi

# ── Git: main branch & ticket prefix ─────────────────────────────────────────

MAIN_BRANCH="main"
if git -C "$ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
  # Try remote HEAD, fall back to local default branch name
  REMOTE_HEAD=$(git -C "$ROOT" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||') || true
  if [[ -n "$REMOTE_HEAD" ]]; then
    MAIN_BRANCH="$REMOTE_HEAD"
  else
    LOCAL_DEFAULT=$(git -C "$ROOT" config init.defaultBranch 2>/dev/null || echo "main")
    MAIN_BRANCH="$LOCAL_DEFAULT"
  fi
fi

# Guess ticket prefix from recent commit messages (e.g. PROJ-123)
TICKET_PREFIX="___"
if git -C "$ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
  TICKET_PREFIX=$(git -C "$ROOT" log --oneline -50 2>/dev/null \
    | grep -oE '\b[A-Z]{2,8}-[0-9]+\b' \
    | sed 's/-[0-9]*$//' \
    | sort | uniq -c | sort -rn \
    | awk 'NR==1{print $2}' || echo "___")
  [[ -z "$TICKET_PREFIX" ]] && TICKET_PREFIX="___"
fi

# ── NX ────────────────────────────────────────────────────────────────────────

NX=""
if [[ -f "$ROOT/nx.json" || $(has_dep "nx") == "yes" ]]; then
  NX="  # NX monorepo — see references/nx-workspace.md"
fi

# ── Output ────────────────────────────────────────────────────────────────────

cat <<EOF
# .context.md — auto-generated by detect-project.sh (review and fill ___ blanks)

name:        ___
type:        SaaS / API / mobile / internal
description: ___

# Stack
frontend:    Angular $NG_VERSION$NX
backend:     ___
database:    ___
infra:       ___
cdn_waf:     ___

# Git
main_branch:    $MAIN_BRANCH
strategy:       ___
ticket_prefix:  $TICKET_PREFIX

# Angular
version:        $NG_VERSION
module_style:   $MODULE_STYLE
design_system:  $DESIGN_SYSTEM
strict_ts:      $STRICT
state:          $STATE
ssr:            $SSR
test_runner:    $TEST_RUNNER
e2e_runner:     $E2E_RUNNER

# Team
size:           ___
methodology:    ___
sprint_length:  ___
pm_tool:        ___
EOF

# ── Summary to stderr (so it doesn't pollute the .context.md output) ─────────

echo "" >&2
echo "=== Detection summary ===" >&2
echo "  Angular:       $NG_VERSION" >&2
echo "  Module style:  $MODULE_STYLE" >&2
echo "  Design system: $DESIGN_SYSTEM" >&2
echo "  Strict TS:     $STRICT" >&2
echo "  State mgmt:    $STATE" >&2
echo "  SSR:           $SSR" >&2
echo "  Test runner:   $TEST_RUNNER / e2e: $E2E_RUNNER" >&2
echo "  Main branch:   $MAIN_BRANCH" >&2
echo "  Ticket prefix: $TICKET_PREFIX" >&2
echo "" >&2
echo "Review the output above, fill in any ___ blanks, then save as .context.md" >&2
