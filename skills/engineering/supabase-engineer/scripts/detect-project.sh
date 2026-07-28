#!/usr/bin/env bash
# Detects Supabase project context and outputs pre-filled .context/ domain drafts.
# Run from the project root: bash <path>/detect-project.sh
# The output is printed to stdout — review and split into .context/ files.

set -euo pipefail

ROOT="${1:-.}"
PKG="$ROOT/package.json"
SUPA_DIR="$ROOT/supabase"
CONFIG="$SUPA_DIR/config.toml"

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

count_files() {
  # $1 = directory, $2 = glob pattern
  if [[ -d "$1" ]]; then
    find "$1" -maxdepth 1 -name "$2" -type f 2>/dev/null | wc -l | tr -d ' '
  else
    echo "0"
  fi
}

# ── Client libraries ──────────────────────────────────────────────────────────

SUPABASE_JS=$(dep_version "@supabase/supabase-js")
SSR_LIB="___"

if [[ $(has_dep "@supabase/ssr") == "yes" ]]; then
  SSR_LIB="@supabase/ssr $(dep_version @supabase/ssr)"
else
  LEGACY=$(first_dep "@supabase/auth-helpers-nextjs" "@supabase/auth-helpers-react" \
                     "@supabase/auth-helpers-sveltekit" "@supabase/auth-helpers-remix")
  if [[ -n "$LEGACY" ]]; then
    SSR_LIB="$LEGACY $(dep_version "$LEGACY")  # DEPRECATED — migrate to @supabase/ssr"
  elif [[ "$SUPABASE_JS" != "___" ]]; then
    SSR_LIB="none (client-only, or a custom cookie layer)"
  fi
fi

CLI_VERSION="___"
if [[ $(has_dep "supabase") == "yes" ]]; then
  CLI_VERSION="$(dep_version supabase) (devDependency)"
elif command -v supabase >/dev/null 2>&1; then
  CLI_VERSION="$(supabase --version 2>/dev/null | head -1) (global)"
fi

# ── Project layout ────────────────────────────────────────────────────────────

MIGRATION_COUNT=$(count_files "$SUPA_DIR/migrations" "*.sql")

SCHEMA_STYLE="hand-written migrations"
if [[ -d "$SUPA_DIR/schemas" ]]; then
  SCHEMA_FILES=$(count_files "$SUPA_DIR/schemas" "*.sql")
  SCHEMA_STYLE="declarative schemas ($SCHEMA_FILES file(s)) + generated migrations"
fi

SEED="none"
if [[ -f "$SUPA_DIR/seed.sql" ]]; then SEED="supabase/seed.sql"; fi

FUNCTION_COUNT=0
FUNCTION_LIST=""
if [[ -d "$SUPA_DIR/functions" ]]; then
  while IFS= read -r fn; do
    base=$(basename "$fn")
    [[ "$base" == _* ]] && continue        # _shared and friends are not functions
    FUNCTION_COUNT=$((FUNCTION_COUNT + 1))
    FUNCTION_LIST="${FUNCTION_LIST:+$FUNCTION_LIST, }$base"
  done < <(find "$SUPA_DIR/functions" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
fi
[[ -z "$FUNCTION_LIST" ]] && FUNCTION_LIST="none"

PGTAP_TESTS=$(count_files "$SUPA_DIR/tests" "*.sql")

# ── config.toml ───────────────────────────────────────────────────────────────

EXPOSED_SCHEMAS="___"
DB_MAJOR="___"
SITE_URL="___"
if [[ -f "$CONFIG" ]]; then
  EXPOSED_SCHEMAS=$(grep -E '^\s*schemas\s*=' "$CONFIG" 2>/dev/null | head -1 \
    | sed 's/.*=\s*//' | tr -d '"' || echo "___")
  [[ -z "$EXPOSED_SCHEMAS" ]] && EXPOSED_SCHEMAS="___"

  DB_MAJOR=$(grep -E '^\s*major_version\s*=' "$CONFIG" 2>/dev/null | head -1 \
    | sed 's/.*=\s*//' | tr -d '" ' || echo "___")
  [[ -z "$DB_MAJOR" ]] && DB_MAJOR="___"

  SITE_URL=$(grep -E '^\s*site_url\s*=' "$CONFIG" 2>/dev/null | head -1 \
    | sed 's/.*=\s*//' | tr -d '"' || echo "___")
  [[ -z "$SITE_URL" ]] && SITE_URL="___"
fi

# Functions with JWT verification disabled — each is a public endpoint
UNVERIFIED_FNS="none"
if [[ -f "$CONFIG" ]]; then
  found=$(grep -B3 -E '^\s*verify_jwt\s*=\s*false' "$CONFIG" 2>/dev/null \
    | grep -oE '^\[functions\.[a-z0-9_-]+\]' | sed 's/\[functions\.//;s/\]//' | tr '\n' ' ' || true)
  [[ -n "$found" ]] && UNVERIFIED_FNS="$found"
fi

# ── Key naming ────────────────────────────────────────────────────────────────

KEY_STYLE="___"
ENV_FILES=""
for f in "$ROOT/.env" "$ROOT/.env.local" "$ROOT/.env.example" "$ROOT/.env.sample"; do
  [[ -f "$f" ]] && ENV_FILES="$ENV_FILES $f"
done

if [[ -n "$ENV_FILES" ]]; then
  # shellcheck disable=SC2086
  if grep -qhE 'sb_publishable_|PUBLISHABLE_KEY' $ENV_FILES 2>/dev/null; then
    KEY_STYLE="new format (sb_publishable_ / sb_secret_)"
  elif grep -qhE 'ANON_KEY|SERVICE_ROLE_KEY' $ENV_FILES 2>/dev/null; then
    KEY_STYLE="legacy JWT keys (anon / service_role) — deprecated end of 2026"
  fi
fi

# Secret key behind a public prefix is a live exposure, not a style note
SECRET_EXPOSED="no"
if [[ -n "$ENV_FILES" ]]; then
  # shellcheck disable=SC2086
  if grep -qhE '(NEXT_PUBLIC|VITE|PUBLIC|EXPO_PUBLIC)_[A-Z_]*(SERVICE_ROLE|SECRET)' $ENV_FILES 2>/dev/null; then
    SECRET_EXPOSED="YES — secret key behind a public env prefix"
  fi
fi

# ── Generated types ───────────────────────────────────────────────────────────

TYPES_FILE="none found"
for candidate in \
  "$ROOT/lib/database.types.ts" "$ROOT/src/lib/database.types.ts" \
  "$ROOT/types/database.types.ts" "$ROOT/src/types/database.types.ts" \
  "$ROOT/database.types.ts" "$ROOT/types/supabase.ts" "$ROOT/src/types/supabase.ts" \
  "$SUPA_DIR/database.types.ts"; do
  if [[ -f "$candidate" ]]; then
    TYPES_FILE="${candidate#"$ROOT"/}"
    break
  fi
done

# ── Framework ─────────────────────────────────────────────────────────────────

FRAMEWORK="none detected"
if [[ $(has_dep "next") == "yes" ]]; then
  FRAMEWORK="Next.js $(dep_version next)  # see the next-engineer skill for framework concerns"
elif [[ $(has_dep "@sveltejs/kit") == "yes" ]]; then
  FRAMEWORK="SvelteKit $(dep_version @sveltejs/kit)"
elif [[ $(has_dep "nuxt") == "yes" ]]; then
  FRAMEWORK="Nuxt $(dep_version nuxt)"
elif [[ $(has_dep "@remix-run/react") == "yes" ]]; then
  FRAMEWORK="Remix $(dep_version @remix-run/react)"
elif [[ $(has_dep "astro") == "yes" ]]; then
  FRAMEWORK="Astro $(dep_version astro)"
elif [[ $(has_dep "expo") == "yes" ]]; then
  FRAMEWORK="Expo $(dep_version expo)"
elif [[ $(has_dep "react") == "yes" ]]; then
  FRAMEWORK="React $(dep_version react)"
fi

# A second data layer alongside PostgREST changes where RLS applies
DIRECT_DB=$(first_dep "prisma" "drizzle-orm" "kysely" "pg" "postgres")
[[ -z "$DIRECT_DB" ]] && DIRECT_DB="none (PostgREST only)"

# ── Extensions referenced in migrations ───────────────────────────────────────

EXTENSIONS="none detected"
if [[ -d "$SUPA_DIR" ]]; then
  found=$(grep -rhoiE 'create extension (if not exists )?"?[a-z_]+"?' "$SUPA_DIR" 2>/dev/null \
    | sed -E 's/.*exists //i; s/.*extension //i' | tr -d '"' | sort -u | tr '\n' ' ' || true)
  [[ -n "$found" ]] && EXTENSIONS="$found"
fi

# ── RLS posture from migrations ───────────────────────────────────────────────

RLS_POSTURE="___"
if [[ -d "$SUPA_DIR" ]]; then
  tables=$(grep -rhoiE 'create table (if not exists )?(public\.)?[a-z_]+' "$SUPA_DIR" 2>/dev/null | wc -l | tr -d ' ')
  enables=$(grep -rhoiE 'enable row level security' "$SUPA_DIR" 2>/dev/null | wc -l | tr -d ' ')
  policies=$(grep -rhoiE 'create policy' "$SUPA_DIR" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$tables" != "0" ]]; then
    RLS_POSTURE="$tables create-table, $enables enable-RLS, $policies policies (verify against the live database)"
  fi
fi

# ── Testing ───────────────────────────────────────────────────────────────────

TEST_RUNNER="none detected"
if [[ $(has_dep "vitest") == "yes" ]]; then
  TEST_RUNNER="Vitest $(dep_version vitest)"
elif [[ $(has_dep "jest") == "yes" ]]; then
  TEST_RUNNER="Jest $(dep_version jest)"
fi

if [[ "$PGTAP_TESTS" != "0" ]]; then
  TEST_RUNNER="$TEST_RUNNER + pgTAP ($PGTAP_TESTS suite(s))"
fi

if [[ $(has_dep "@playwright/test") == "yes" ]]; then
  E2E_RUNNER="Playwright $(dep_version @playwright/test)"
elif [[ $(has_dep "cypress") == "yes" ]]; then
  E2E_RUNNER="Cypress $(dep_version cypress)"
else
  E2E_RUNNER="none detected"
fi

# ── Hosting ───────────────────────────────────────────────────────────────────

HOSTING="hosted (Supabase Cloud)"
if [[ -f "$ROOT/docker-compose.yml" ]] && grep -qE 'supabase/(postgres|gotrue|realtime|storage-api)' "$ROOT/docker-compose.yml" 2>/dev/null; then
  HOSTING="self-hosted (Docker Compose)  # see references/self-hosting.md"
fi

LINKED="not linked"
if [[ -f "$SUPA_DIR/.temp/project-ref" ]]; then
  LINKED="linked (supabase/.temp/project-ref present)"
fi

PKG_MANAGER="npm"
if [[ -f "$ROOT/pnpm-lock.yaml" ]]; then PKG_MANAGER="pnpm"; fi
if [[ -f "$ROOT/yarn.lock" ]]; then PKG_MANAGER="yarn"; fi
if [[ -f "$ROOT/bun.lockb" || -f "$ROOT/bun.lock" ]]; then PKG_MANAGER="bun"; fi

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

- Backend: Supabase ($HOSTING)
- Postgres major version: $DB_MAJOR
- Client: @supabase/supabase-js $SUPABASE_JS
- Server auth: $SSR_LIB
- Frontend: $FRAMEWORK
- Direct DB access alongside PostgREST: $DIRECT_DB
- Package manager: $PKG_MANAGER
- CLI: $CLI_VERSION
- Project link: $LINKED

## Repo Structure

- Migrations: $MIGRATION_COUNT file(s) in supabase/migrations/
- Schema style: $SCHEMA_STYLE
- Seed: $SEED
- Edge Functions ($FUNCTION_COUNT): $FUNCTION_LIST
- Generated types: $TYPES_FILE

[Folder layout and what lives where]

## Environment

- Key naming: $KEY_STYLE
- Site URL: $SITE_URL

Note: the secret (service_role) key bypasses RLS and must never carry a public
env prefix or reach a browser bundle.

## Glossary

| Term | Meaning |
|---|---|
| ___ | ___ |

---

# .context/engineering.md — draft generated by detect-project.sh

# Engineering Context

## Conventions

- Exposed schemas: $EXPOSED_SCHEMAS
- Schema style: $SCHEMA_STYLE
- Postgres extensions: $EXTENSIONS
- Edge Functions without JWT verification: $UNVERIFIED_FNS

## Security Posture

- RLS in migrations: $RLS_POSTURE
- Secret key exposed via a public prefix: $SECRET_EXPOSED

Verify RLS against the live database rather than trusting migration greps:

    select c.relname from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p') and not c.relrowsecurity;

## Testing Strategy

- Unit/integration runner: $TEST_RUNNER
- E2E runner: $E2E_RUNNER
- Policy tests: $PGTAP_TESTS pgTAP suite(s)

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
echo "  supabase-js:    $SUPABASE_JS" >&2
echo "  Server auth:    $SSR_LIB" >&2
echo "  CLI:            $CLI_VERSION" >&2
echo "  Hosting:        $HOSTING" >&2
echo "  Framework:      $FRAMEWORK" >&2
echo "  Direct DB:      $DIRECT_DB" >&2
echo "  Migrations:     $MIGRATION_COUNT" >&2
echo "  Schema style:   $SCHEMA_STYLE" >&2
echo "  Edge Functions: $FUNCTION_COUNT ($FUNCTION_LIST)" >&2
echo "  Unverified fns: $UNVERIFIED_FNS" >&2
echo "  Exposed schemas:$EXPOSED_SCHEMAS" >&2
echo "  Extensions:     $EXTENSIONS" >&2
echo "  Key naming:     $KEY_STYLE" >&2
echo "  Generated types:$TYPES_FILE" >&2
echo "  RLS in commits: $RLS_POSTURE" >&2
echo "  Test runner:    $TEST_RUNNER / e2e: $E2E_RUNNER" >&2
echo "  Main branch:    $MAIN_BRANCH" >&2
echo "  Ticket prefix:  $TICKET_PREFIX" >&2
echo "" >&2

if [[ "$SECRET_EXPOSED" != "no" ]]; then
  echo "  !! $SECRET_EXPOSED" >&2
  echo "     The secret key bypasses RLS. Rotate it and move it behind a" >&2
  echo "     server-only variable before doing anything else." >&2
  echo "" >&2
fi

if [[ "$SSR_LIB" == *"DEPRECATED"* ]]; then
  echo "  !  @supabase/auth-helpers is superseded by @supabase/ssr." >&2
  echo "     See references/client-setup.md before writing new auth code." >&2
  echo "" >&2
fi

if [[ "$SUPABASE_JS" == "___" && "$MIGRATION_COUNT" == "0" ]]; then
  echo "  WARNING: no supabase-js dependency and no migrations — is this a Supabase project root?" >&2
  echo "" >&2
fi

echo "Review the output above, fill in any ___ blanks, then save into .context/ domain files" >&2
