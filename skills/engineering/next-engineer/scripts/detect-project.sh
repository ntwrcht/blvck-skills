#!/usr/bin/env bash
# Detects Next.js project context and outputs pre-filled .context/ domain drafts.
# Run from the Next.js project root: bash <path>/detect-project.sh
# The output is printed to stdout — review and split into .context/ files.

set -euo pipefail

ROOT="${1:-.}"
PKG="$ROOT/package.json"
TS_JSON="$ROOT/tsconfig.json"

# ── helpers ──────────────────────────────────────────────────────────────────

has_dep() {
  # Returns "yes" if package name $1 appears in deps or devDeps
  [[ -f "$PKG" ]] && python3 -c "
import json
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

first_dep() {
  # Echoes the first package name from the argument list that is present
  for name in "$@"; do
    if [[ $(has_dep "$name") == "yes" ]]; then
      echo "$name"
      return
    fi
  done
  echo ""
}

# ── Next.js version ───────────────────────────────────────────────────────────

NEXT_VERSION=$(dep_version "next")
REACT_VERSION=$(dep_version "react")

NEXT_MAJOR=""
if [[ "$NEXT_VERSION" != "___" ]]; then
  NEXT_MAJOR=$(echo "$NEXT_VERSION" | cut -d. -f1)
fi

# ── Router style ──────────────────────────────────────────────────────────────
# app/ and pages/ may live at the repo root or under src/.

APP_DIR=""
PAGES_DIR=""
for base in "$ROOT" "$ROOT/src"; do
  [[ -d "$base/app" ]] && APP_DIR="${APP_DIR:-$base/app}"
  [[ -d "$base/pages" ]] && PAGES_DIR="${PAGES_DIR:-$base/pages}"
done

if [[ -n "$APP_DIR" && -n "$PAGES_DIR" ]]; then
  ROUTER="hybrid (App Router + Pages Router)"
elif [[ -n "$APP_DIR" ]]; then
  ROUTER="App Router"
elif [[ -n "$PAGES_DIR" ]]; then
  ROUTER="Pages Router"
else
  ROUTER="___"
fi

SRC_DIR="no"
if [[ -d "$ROOT/src" ]]; then SRC_DIR="yes"; fi

# ── next.config ───────────────────────────────────────────────────────────────

NEXT_CONFIG=""
for ext in ts mjs js cjs; do
  if [[ -f "$ROOT/next.config.$ext" ]]; then
    NEXT_CONFIG="next.config.$ext"
    break
  fi
done

# Caching model: Cache Components is opt-in via cacheComponents (Next 16+),
# or the older experimental dynamicIO / ppr flags.
CACHE_MODEL="legacy (implicit fetch + route config)"
if [[ -n "$NEXT_CONFIG" ]]; then
  if grep -qE '^[^/]*cacheComponents\s*:\s*true' "$ROOT/$NEXT_CONFIG" 2>/dev/null; then
    CACHE_MODEL="Cache Components ('use cache', PPR by default)"
  elif grep -qE 'dynamicIO\s*:\s*true' "$ROOT/$NEXT_CONFIG" 2>/dev/null; then
    CACHE_MODEL="experimental dynamicIO (renamed cacheComponents in Next 16)"
  elif grep -qE '\bppr\s*:' "$ROOT/$NEXT_CONFIG" 2>/dev/null; then
    CACHE_MODEL="legacy + experimental PPR"
  fi
fi

OUTPUT_MODE="default (server)"
if [[ -n "$NEXT_CONFIG" ]]; then
  grep -qE "output\s*:\s*['\"]standalone" "$ROOT/$NEXT_CONFIG" 2>/dev/null && OUTPUT_MODE="standalone"
  grep -qE "output\s*:\s*['\"]export" "$ROOT/$NEXT_CONFIG" 2>/dev/null && OUTPUT_MODE="static export"
fi

REACT_COMPILER="off"
if [[ -n "$NEXT_CONFIG" ]] && grep -qE 'reactCompiler\s*:\s*true' "$ROOT/$NEXT_CONFIG" 2>/dev/null; then
  REACT_COMPILER="on"
fi

# ── Bundler ───────────────────────────────────────────────────────────────────
# Turbopack is the default from Next 16; earlier versions opt in via --turbo.

BUNDLER="webpack"
if [[ -n "$NEXT_MAJOR" ]] && [[ "$NEXT_MAJOR" -ge 16 ]] 2>/dev/null; then
  BUNDLER="Turbopack (default in Next 16)"
  if [[ -f "$PKG" ]] && grep -qE '"(dev|build)"\s*:\s*"[^"]*--webpack' "$PKG" 2>/dev/null; then
    BUNDLER="webpack (explicit --webpack opt-out)"
  fi
elif [[ -f "$PKG" ]] && grep -qE '"dev"\s*:\s*"[^"]*--turbo' "$PKG" 2>/dev/null; then
  BUNDLER="Turbopack (opt-in via --turbo)"
fi

# ── Proxy / middleware ────────────────────────────────────────────────────────

REQUEST_INTERCEPT="none detected"
for base in "$ROOT" "$ROOT/src"; do
  for ext in ts js; do
    [[ -f "$base/proxy.$ext" ]] && REQUEST_INTERCEPT="proxy.$ext (Next 16+)"
    [[ -f "$base/middleware.$ext" && "$REQUEST_INTERCEPT" == "none detected" ]] \
      && REQUEST_INTERCEPT="middleware.$ext (deprecated in Next 16)"
  done
done

# ── Styling ───────────────────────────────────────────────────────────────────

STYLING="CSS Modules / plain CSS"
if [[ $(has_dep "tailwindcss") == "yes" ]]; then
  STYLING="Tailwind CSS $(dep_version tailwindcss)"
elif [[ $(has_dep "styled-components") == "yes" ]]; then
  STYLING="styled-components (needs 'use client' + registry)"
elif [[ $(has_dep "@emotion/react") == "yes" ]]; then
  STYLING="Emotion (needs 'use client' + registry)"
elif [[ $(has_dep "@vanilla-extract/css") == "yes" ]]; then
  STYLING="vanilla-extract"
elif [[ $(has_dep "sass") == "yes" ]]; then
  STYLING="Sass / SCSS"
fi

COMPONENT_LIB="none detected"
if [[ -d "$ROOT/components/ui" || -d "$ROOT/src/components/ui" ]] \
   && [[ -f "$ROOT/components.json" ]]; then
  COMPONENT_LIB="shadcn/ui (source-copied into the repo)"
elif [[ $(has_dep "@mui/material") == "yes" ]]; then
  COMPONENT_LIB="MUI $(dep_version @mui/material)"
elif [[ $(has_dep "@chakra-ui/react") == "yes" ]]; then
  COMPONENT_LIB="Chakra UI"
elif [[ $(has_dep "@mantine/core") == "yes" ]]; then
  COMPONENT_LIB="Mantine"
elif [[ $(has_dep "antd") == "yes" ]]; then
  COMPONENT_LIB="Ant Design"
fi

DARK_MODE="___"
if [[ $(has_dep "next-themes") == "yes" ]]; then DARK_MODE="next-themes"; fi

# ── Data layer ────────────────────────────────────────────────────────────────

ORM="none detected"
if [[ $(has_dep "@prisma/client") == "yes" ]]; then
  ORM="Prisma $(dep_version @prisma/client)"
elif [[ $(has_dep "drizzle-orm") == "yes" ]]; then
  ORM="Drizzle $(dep_version drizzle-orm)"
elif [[ $(has_dep "@supabase/supabase-js") == "yes" ]]; then
  ORM="Supabase client"
elif [[ $(has_dep "mongoose") == "yes" ]]; then
  ORM="Mongoose"
elif [[ $(has_dep "typeorm") == "yes" ]]; then
  ORM="TypeORM"
elif [[ $(has_dep "kysely") == "yes" ]]; then
  ORM="Kysely"
fi

VALIDATION=$(first_dep "zod" "valibot" "yup" "@sinclair/typebox")
[[ -z "$VALIDATION" ]] && VALIDATION="none detected"

SERVER_ONLY="not used"
if grep -rq --include="*.ts" --include="*.tsx" "server-only" "$ROOT/app" "$ROOT/src" "$ROOT/lib" 2>/dev/null; then
  SERVER_ONLY="in use"
fi

# ── Client state / data ───────────────────────────────────────────────────────

CLIENT_STATE=$(first_dep "zustand" "jotai" "@reduxjs/toolkit" "valtio" "nuqs")
[[ -z "$CLIENT_STATE" ]] && CLIENT_STATE="React state / URL params"

CLIENT_DATA=$(first_dep "@tanstack/react-query" "swr")
[[ -z "$CLIENT_DATA" ]] && CLIENT_DATA="none (Server Components)"

FORMS=$(first_dep "react-hook-form" "formik" "@tanstack/react-form")
[[ -z "$FORMS" ]] && FORMS="Server Actions + useActionState"

# ── Auth ──────────────────────────────────────────────────────────────────────

AUTH="custom / none detected"
for candidate in "next-auth" "@auth/core" "@clerk/nextjs" "better-auth" \
                 "@supabase/ssr" "@workos-inc/node" "@auth0/nextjs-auth0" \
                 "@kinde-oss/kinde-auth-nextjs" "@stackframe/stack"; do
  if [[ $(has_dep "$candidate") == "yes" ]]; then
    AUTH="$candidate $(dep_version "$candidate")"
    break
  fi
done

# ── Testing ───────────────────────────────────────────────────────────────────

TEST_RUNNER="none detected"
if [[ $(has_dep "vitest") == "yes" ]]; then
  TEST_RUNNER="Vitest $(dep_version vitest)"
elif [[ $(has_dep "jest") == "yes" ]]; then
  TEST_RUNNER="Jest $(dep_version jest)"
fi

if [[ $(has_dep "@testing-library/react") == "yes" ]]; then
  TEST_RUNNER="$TEST_RUNNER + React Testing Library"
fi

if [[ $(has_dep "@playwright/test") == "yes" ]]; then
  E2E_RUNNER="Playwright $(dep_version @playwright/test)"
elif [[ $(has_dep "cypress") == "yes" ]]; then
  E2E_RUNNER="Cypress $(dep_version cypress)"
else
  E2E_RUNNER="none detected"
fi

# ── Lint ──────────────────────────────────────────────────────────────────────

LINTER="none detected"
if [[ $(has_dep "@biomejs/biome") == "yes" ]]; then
  LINTER="Biome"
elif [[ $(has_dep "eslint") == "yes" ]]; then
  LINTER="ESLint $(dep_version eslint)"
  for flat in eslint.config.mjs eslint.config.js eslint.config.ts; do
    [[ -f "$ROOT/$flat" ]] && LINTER="$LINTER (flat config)"
  done
fi

# ── TypeScript strictness ─────────────────────────────────────────────────────

STRICT="___"
if [[ -f "$TS_JSON" ]]; then
  STRICT=$(python3 -c "
import json,re
raw=open('$TS_JSON').read()
raw=re.sub(r'//.*',  '', raw)
raw=re.sub(r'/\*.*?\*/', '', raw, flags=re.S)
raw=re.sub(r',(\s*[}\]])', r'\1', raw)
d=json.loads(raw)
print('true' if d.get('compilerOptions',{}).get('strict') else 'false')
" 2>/dev/null || echo "___")
fi

# ── Monorepo ──────────────────────────────────────────────────────────────────

MONOREPO="single package"
if [[ -f "$ROOT/turbo.json" ]]; then
  MONOREPO="Turborepo  # see references/monorepo-turborepo.md"
elif [[ -f "$ROOT/nx.json" ]]; then
  MONOREPO="Nx  # see references/monorepo-turborepo.md"
elif [[ -f "$ROOT/pnpm-workspace.yaml" ]]; then
  MONOREPO="pnpm workspaces  # see references/monorepo-turborepo.md"
fi

PKG_MANAGER="npm"
if [[ -f "$ROOT/pnpm-lock.yaml" ]]; then PKG_MANAGER="pnpm"; fi
if [[ -f "$ROOT/yarn.lock" ]]; then PKG_MANAGER="yarn"; fi
if [[ -f "$ROOT/bun.lockb" || -f "$ROOT/bun.lock" ]]; then PKG_MANAGER="bun"; fi

# ── Deployment ────────────────────────────────────────────────────────────────

DEPLOY_TARGETS=()
if [[ -f "$ROOT/vercel.json" || -d "$ROOT/.vercel" ]]; then
  DEPLOY_TARGETS+=("Vercel")
fi
if [[ -f "$ROOT/Dockerfile" ]]; then
  DEPLOY_TARGETS+=("Docker")
fi
if [[ ${#DEPLOY_TARGETS[@]} -eq 0 ]]; then
  if [[ "$OUTPUT_MODE" == "standalone" ]]; then
    DEPLOY="self-hosted (standalone output)"
  elif [[ "$OUTPUT_MODE" == "static export" ]]; then
    DEPLOY="static host (export)"
  else
    DEPLOY="___"
  fi
else
  DEPLOY="${DEPLOY_TARGETS[0]}"
  for target in "${DEPLOY_TARGETS[@]:1}"; do
    DEPLOY="$DEPLOY / $target"
  done
fi

# ── Git: main branch & ticket prefix ─────────────────────────────────────────

MAIN_BRANCH="main"
if git -C "$ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
  REMOTE_HEAD=$(git -C "$ROOT" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||') || true
  if [[ -n "$REMOTE_HEAD" ]]; then
    MAIN_BRANCH="$REMOTE_HEAD"
  else
    MAIN_BRANCH=$(git -C "$ROOT" config init.defaultBranch 2>/dev/null || echo "main")
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

# ── Output ────────────────────────────────────────────────────────────────────

cat <<EOF
# .context/project.md — draft generated by detect-project.sh

# Project Context

## Stack

- Frontend: Next.js $NEXT_VERSION (React $REACT_VERSION)
- Repo shape: $MONOREPO
- Package manager: $PKG_MANAGER
- Database/ORM: $ORM
- Auth: $AUTH
- Deployment: $DEPLOY
- Infrastructure: ___
- CDN/WAF: ___

## Repo Structure

- Router: $ROUTER
- \`src/\` directory: $SRC_DIR
- Config file: ${NEXT_CONFIG:-___}
- Request interception: $REQUEST_INTERCEPT

[Folder layout and what lives where]

## Environment

[Dev setup, env vars, local run commands]

Note: \`NEXT_PUBLIC_*\` variables are inlined at build time and are permanently public.

## Glossary

| Term | Meaning |
|---|---|
| ___ | ___ |

---

# .context/engineering.md — draft generated by detect-project.sh

# Engineering Context

## Conventions

- Next.js version: $NEXT_VERSION
- Router: $ROUTER
- Caching model: $CACHE_MODEL
- Bundler: $BUNDLER
- Output mode: $OUTPUT_MODE
- React Compiler: $REACT_COMPILER
- Strict TypeScript: $STRICT
- Linter: $LINTER

## UI

- Styling: $STYLING
- Component library: $COMPONENT_LIB
- Dark mode: $DARK_MODE

## Data and State

- ORM / data client: $ORM
- Validation: $VALIDATION
- \`server-only\` guard: $SERVER_ONLY
- Client state: $CLIENT_STATE
- Client data fetching: $CLIENT_DATA
- Forms: $FORMS

## Testing Strategy

- Unit test runner: $TEST_RUNNER
- E2E runner: $E2E_RUNNER

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

echo "" >&2
echo "=== Detection summary ===" >&2
echo "  Next.js:       $NEXT_VERSION (React $REACT_VERSION)" >&2
echo "  Router:        $ROUTER" >&2
echo "  Caching model: $CACHE_MODEL" >&2
echo "  Bundler:       $BUNDLER" >&2
echo "  Interception:  $REQUEST_INTERCEPT" >&2
echo "  Styling:       $STYLING" >&2
echo "  Components:    $COMPONENT_LIB" >&2
echo "  ORM:           $ORM" >&2
echo "  Auth:          $AUTH" >&2
echo "  Client state:  $CLIENT_STATE" >&2
echo "  Strict TS:     $STRICT" >&2
echo "  Test runner:   $TEST_RUNNER / e2e: $E2E_RUNNER" >&2
echo "  Repo shape:    $MONOREPO ($PKG_MANAGER)" >&2
echo "  Main branch:   $MAIN_BRANCH" >&2
echo "  Ticket prefix: $TICKET_PREFIX" >&2
echo "" >&2

if [[ "$NEXT_VERSION" == "___" ]]; then
  echo "  WARNING: 'next' not found in package.json — is this a Next.js project root?" >&2
  echo "" >&2
fi

echo "Review the output above, fill in any ___ blanks, then save into .context/ domain files" >&2
