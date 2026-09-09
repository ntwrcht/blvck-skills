#!/usr/bin/env bash
# Detects TiDB project context and prints pre-filled .context/ domain drafts.
# Run from the project root: bash <path>/detect-project.sh [root]
# Output goes to stdout; a summary goes to stderr. Review, fill the ___ blanks,
# then split into .context/ files. Nothing here connects to a database: the
# live facts (VERSION(), TiFlash, txn mode) are printed as probes to run.

set -euo pipefail

ROOT="${1:-.}"
PKG="$ROOT/package.json"

# ── helpers ──────────────────────────────────────────────────────────────────

has_dep() {
  [[ -f "$PKG" ]] && python3 -c "
import json
d=json.load(open('$PKG'))
deps={**d.get('dependencies',{}),**d.get('devDependencies',{})}
print('yes' if '$1' in deps else 'no')
" 2>/dev/null || echo "no"
}

dep_version() {
  [[ -f "$PKG" ]] && python3 -c "
import json,re
d=json.load(open('$PKG'))
deps={**d.get('dependencies',{}),**d.get('devDependencies',{})}
v=deps.get('$1','___')
print(re.sub(r'^[\^~>=]+','',v) if v!='___' else '___')
" 2>/dev/null || echo "___"
}

py_has() {
  # $1 = package name; checks requirements*.txt, pyproject.toml, Pipfile
  grep -rqiE "^\s*$1([=<>~\[ ]|$)|\"$1[\">=<~ ]|'$1['>=<~ ]" \
    "$ROOT"/requirements*.txt "$ROOT/pyproject.toml" "$ROOT/Pipfile" 2>/dev/null && echo "yes" || echo "no"
}

grep_count() {
  # $1 = regex, rest = files/dirs; counts matching lines, 0 when nothing exists
  local pattern="$1"; shift
  local n=0
  for target in "$@"; do
    [[ -e "$target" ]] || continue
    n=$((n + $(grep -rhoiE "$pattern" "$target" 2>/dev/null | wc -l | tr -d ' ')))
  done
  echo "$n"
}

# ── Drivers and ORMs ─────────────────────────────────────────────────────────

DRIVERS=""
add_driver() { DRIVERS="${DRIVERS:+$DRIVERS, }$1"; }

[[ $(has_dep mysql2) == yes ]]                 && add_driver "mysql2 $(dep_version mysql2)"
[[ $(has_dep mysql) == yes ]]                  && add_driver "mysql (mysqljs, legacy callback API) $(dep_version mysql)"
[[ $(has_dep @tidbcloud/serverless) == yes ]]  && add_driver "@tidbcloud/serverless (HTTP) $(dep_version @tidbcloud/serverless)"
[[ $(has_dep @tidbcloud/kysely) == yes ]]      && add_driver "@tidbcloud/kysely $(dep_version @tidbcloud/kysely)"
[[ $(has_dep @tidbcloud/prisma-adapter) == yes ]] && add_driver "@tidbcloud/prisma-adapter $(dep_version @tidbcloud/prisma-adapter)"
[[ $(has_dep kysely) == yes ]]                 && add_driver "kysely $(dep_version kysely)"
[[ $(has_dep prisma) == yes || $(has_dep @prisma/client) == yes ]] && add_driver "prisma $(dep_version prisma)"
[[ $(has_dep drizzle-orm) == yes ]]            && add_driver "drizzle-orm $(dep_version drizzle-orm)"
[[ $(has_dep typeorm) == yes ]]                && add_driver "typeorm $(dep_version typeorm)"
[[ $(has_dep sequelize) == yes ]]              && add_driver "sequelize $(dep_version sequelize)"
[[ $(py_has pytidb) == yes ]]                  && add_driver "pytidb"
[[ $(py_has sqlalchemy) == yes ]]              && add_driver "sqlalchemy"
[[ $(py_has pymysql) == yes ]]                 && add_driver "pymysql"
[[ $(py_has mysqlclient) == yes ]]             && add_driver "mysqlclient"
[[ $(py_has alembic) == yes ]]                 && add_driver "alembic"
if [[ -f "$ROOT/go.mod" ]]; then
  grep -q 'go-sql-driver/mysql' "$ROOT/go.mod" && add_driver "go-sql-driver/mysql"
  grep -q 'gorm.io/driver/mysql' "$ROOT/go.mod" && add_driver "gorm mysql"
fi
[[ -z "$DRIVERS" ]] && DRIVERS="none detected"

# ── Migrations ───────────────────────────────────────────────────────────────

MIGRATION_DIR="none found"
for candidate in prisma/migrations migrations db/migrate db/migrations alembic/versions sql/migrations drizzle supabase/migrations; do
  if [[ -d "$ROOT/$candidate" ]]; then MIGRATION_DIR="$candidate"; break; fi
done

SQL_SCOPE=()
[[ "$MIGRATION_DIR" != "none found" ]] && SQL_SCOPE+=("$ROOT/$MIGRATION_DIR")
[[ -f "$ROOT/schema.sql" ]] && SQL_SCOPE+=("$ROOT/schema.sql")
[[ -f "$ROOT/prisma/schema.prisma" ]] && SQL_SCOPE+=("$ROOT/prisma/schema.prisma")

PRISMA_PROVIDER="___"
if [[ -f "$ROOT/prisma/schema.prisma" ]]; then
  PRISMA_PROVIDER=$(grep -E '^\s*provider\s*=' "$ROOT/prisma/schema.prisma" | grep -v prisma-client | head -1 | sed 's/.*=\s*//' | tr -d '" ')
  [[ -z "$PRISMA_PROVIDER" ]] && PRISMA_PROVIDER="___"
fi

RELATION_MODE="database (default)"
if [[ -f "$ROOT/prisma/schema.prisma" ]] && grep -qE 'relationMode\s*=\s*"prisma"' "$ROOT/prisma/schema.prisma"; then
  RELATION_MODE="prisma (foreign keys enforced in the client)"
fi

if [[ ${#SQL_SCOPE[@]} -gt 0 ]]; then
  AUTO_RANDOM=$(grep_count 'AUTO_RANDOM' "${SQL_SCOPE[@]}")
  AUTO_INC=$(grep_count 'AUTO_INCREMENT|autoincrement\(\)' "${SQL_SCOPE[@]}")
  TTL_ATTR=$(grep_count '\bTTL\s*=' "${SQL_SCOPE[@]}")
  VECTOR_COLS=$(grep_count '\bVECTOR\s*\(' "${SQL_SCOPE[@]}")
  FULLTEXT=$(grep_count 'FULLTEXT' "${SQL_SCOPE[@]}")
  FOREIGN_KEYS=$(grep_count 'FOREIGN KEY|@relation' "${SQL_SCOPE[@]}")
  PARTITIONS=$(grep_count 'PARTITION BY' "${SQL_SCOPE[@]}")
  UNSUPPORTED=$(grep_count 'CREATE (PROCEDURE|FUNCTION|TRIGGER|EVENT)|OPTIMIZE TABLE|MATCH\s*\(.*\)\s*AGAINST|GEOMETRY|SPATIAL' "${SQL_SCOPE[@]}")
  JSON_COLS=$(grep_count '\bJSON\b' "${SQL_SCOPE[@]}")
else
  AUTO_RANDOM=0; AUTO_INC=0; TTL_ATTR=0; VECTOR_COLS=0; FULLTEXT=0; FOREIGN_KEYS=0; PARTITIONS=0; UNSUPPORTED=0; JSON_COLS=0
fi

PK_STYLE="___"
if [[ "$AUTO_RANDOM" -gt 0 && "$AUTO_INC" -gt 0 ]]; then PK_STYLE="mixed: $AUTO_RANDOM AUTO_RANDOM, $AUTO_INC AUTO_INCREMENT"
elif [[ "$AUTO_RANDOM" -gt 0 ]]; then PK_STYLE="AUTO_RANDOM ($AUTO_RANDOM)"
elif [[ "$AUTO_INC" -gt 0 ]]; then PK_STYLE="AUTO_INCREMENT ($AUTO_INC)  # check write-heavy tables for hotspots"
fi

# ── Environment ──────────────────────────────────────────────────────────────

ENV_FILES=""
for f in "$ROOT/.env" "$ROOT/.env.local" "$ROOT/.env.example" "$ROOT/.env.sample" "$ROOT/.env.development"; do
  [[ -f "$f" ]] && ENV_FILES="$ENV_FILES $f"
done

DEPLOYMENT="___"
CONN_STYLE="___"
TLS_HINT="___"
PUBLIC_LEAK="no"
if [[ -n "$ENV_FILES" ]]; then
  # shellcheck disable=SC2086
  if grep -qhE 'tidbcloud\.com' $ENV_FILES 2>/dev/null; then
    DEPLOYMENT="TiDB Cloud (gateway host present)"
    # shellcheck disable=SC2086
    grep -qhE 'gateway[0-9]+\.[a-z0-9-]+\.(prod|dev|staging)\.(shared\.)?(aws|alicloud)' $ENV_FILES 2>/dev/null && DEPLOYMENT="TiDB Cloud Starter/Essential or Dedicated public endpoint"
  elif grep -qhE 'zero\.tidbapi\.com|tidbapi' $ENV_FILES 2>/dev/null; then
    DEPLOYMENT="TiDB Cloud Zero (disposable)"
  elif grep -qhE ':4000' $ENV_FILES 2>/dev/null; then
    DEPLOYMENT="TiDB on port 4000 (self-managed or tunnelled)"
  fi
  # shellcheck disable=SC2086
  if grep -qhE '^\s*DATABASE_URL=' $ENV_FILES 2>/dev/null; then CONN_STYLE="DATABASE_URL"; fi
  # shellcheck disable=SC2086
  if grep -qhE '^\s*TIDB_(HOST|USER|USERNAME)=' $ENV_FILES 2>/dev/null; then CONN_STYLE="${CONN_STYLE:+$CONN_STYLE + }TIDB_* parts"; fi
  [[ "$CONN_STYLE" == "" ]] && CONN_STYLE="___"
  # shellcheck disable=SC2086
  if grep -qhE 'sslaccept=strict|ssl_verify_identity|VERIFY_IDENTITY|TIDB_ENABLE_SSL=true|TIDB_CA_PATH' $ENV_FILES 2>/dev/null; then
    TLS_HINT="verification configured"
  elif [[ "$DEPLOYMENT" == TiDB\ Cloud* ]]; then
    TLS_HINT="NOT FOUND in env files; TiDB Cloud public endpoints require it"
  fi
  # shellcheck disable=SC2086
  if grep -qhE '(NEXT_PUBLIC|VITE|PUBLIC|EXPO_PUBLIC)_[A-Z_]*(DATABASE_URL|TIDB_PASSWORD|DB_PASS)' $ENV_FILES 2>/dev/null; then
    PUBLIC_LEAK="YES: database credential behind a public env prefix"
  fi
fi

# ── Framework and runtime ────────────────────────────────────────────────────

FRAMEWORK="none detected"
if [[ $(has_dep next) == yes ]]; then FRAMEWORK="Next.js $(dep_version next)  # see references/nextjs.md and the next-engineer skill"
elif [[ $(has_dep express) == yes ]]; then FRAMEWORK="Express $(dep_version express)"
elif [[ $(has_dep fastify) == yes ]]; then FRAMEWORK="Fastify $(dep_version fastify)"
elif [[ $(has_dep hono) == yes ]]; then FRAMEWORK="Hono $(dep_version hono)"
elif [[ $(has_dep @nestjs/core) == yes ]]; then FRAMEWORK="NestJS $(dep_version @nestjs/core)"
elif [[ $(py_has fastapi) == yes ]]; then FRAMEWORK="FastAPI"
elif [[ $(py_has django) == yes ]]; then FRAMEWORK="Django"
elif [[ $(py_has flask) == yes ]]; then FRAMEWORK="Flask"
fi

EDGE_ROUTES=0
if [[ -d "$ROOT/app" ]]; then
  EDGE_ROUTES=$(grep -rlE "runtime\s*=\s*['\"]edge['\"]" "$ROOT/app" 2>/dev/null | wc -l | tr -d ' ')
fi

HOSTING="___"
[[ -f "$ROOT/vercel.json" || -d "$ROOT/.vercel" ]] && HOSTING="Vercel"
[[ -f "$ROOT/wrangler.toml" || -f "$ROOT/wrangler.json" ]] && HOSTING="Cloudflare Workers"
[[ -f "$ROOT/netlify.toml" ]] && HOSTING="Netlify"
[[ -f "$ROOT/Dockerfile" && "$HOSTING" == "___" ]] && HOSTING="container"

PKG_MANAGER="npm"
[[ -f "$ROOT/pnpm-lock.yaml" ]] && PKG_MANAGER="pnpm"
[[ -f "$ROOT/yarn.lock" ]] && PKG_MANAGER="yarn"
[[ -f "$ROOT/bun.lockb" || -f "$ROOT/bun.lock" ]] && PKG_MANAGER="bun"
[[ -f "$ROOT/uv.lock" ]] && PKG_MANAGER="uv"
[[ -f "$ROOT/poetry.lock" ]] && PKG_MANAGER="poetry"

# ── Tests ────────────────────────────────────────────────────────────────────

TEST_RUNNER="none detected"
[[ $(has_dep vitest) == yes ]] && TEST_RUNNER="Vitest $(dep_version vitest)"
[[ $(has_dep jest) == yes ]] && TEST_RUNNER="Jest $(dep_version jest)"
[[ $(py_has pytest) == yes ]] && TEST_RUNNER="pytest"

TEST_DB="___"
if [[ -f "$ROOT/docker-compose.yml" || -f "$ROOT/compose.yml" ]]; then
  compose_file="$ROOT/docker-compose.yml"; [[ -f "$compose_file" ]] || compose_file="$ROOT/compose.yml"
  if grep -qE 'pingcap/tidb' "$compose_file"; then TEST_DB="TiDB in Docker Compose"
  elif grep -qE 'image:\s*mysql|mariadb' "$compose_file"; then TEST_DB="MySQL in Docker Compose  # DDL that passes here can still fail on TiDB"
  fi
fi
[[ -f "$ROOT/.github/workflows" ]] || true
if grep -rqE 'tiup playground|pingcap/tidb' "$ROOT/.github" 2>/dev/null; then TEST_DB="TiDB in CI ($TEST_DB)"; fi

# ── Git ──────────────────────────────────────────────────────────────────────

MAIN_BRANCH="main"
if git -C "$ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
  REMOTE_HEAD=$(git -C "$ROOT" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||') || true
  if [[ -n "$REMOTE_HEAD" ]]; then MAIN_BRANCH="$REMOTE_HEAD"
  else MAIN_BRANCH=$(git -C "$ROOT" config init.defaultBranch 2>/dev/null || echo "main"); fi
fi

TICKET_PREFIX="___"
if git -C "$ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
  TICKET_PREFIX=$(git -C "$ROOT" log --oneline -50 2>/dev/null \
    | grep -oE '\b[A-Z]{2,8}-[0-9]+\b' | sed 's/-[0-9]*$//' \
    | sort | uniq -c | sort -rn | awk 'NR==1{print $2}' || echo "___")
  [[ -z "$TICKET_PREFIX" ]] && TICKET_PREFIX="___"
fi

# ── Output ───────────────────────────────────────────────────────────────────

cat <<EOF
# .context/project.md — draft generated by detect-project.sh

# Project Context

## Stack

- Database: TiDB ($DEPLOYMENT)
- TiDB version: ___  (run: SELECT VERSION();)
- TiFlash: ___  (run: SELECT table_schema, table_name FROM information_schema.tiflash_replica;)
- Drivers / ORMs: $DRIVERS
- Framework: $FRAMEWORK
- Hosting: $HOSTING
- Package manager: $PKG_MANAGER

## Repo Structure

- Migrations: $MIGRATION_DIR
- Prisma provider: $PRISMA_PROVIDER
- Edge-runtime route files: $EDGE_ROUTES

[Folder layout and what lives where]

## Environment

- Connection style: $CONN_STYLE
- TLS verification: $TLS_HINT

## Glossary

| Term | Meaning |
|---|---|
| ___ | ___ |

---

# .context/engineering.md — draft generated by detect-project.sh

# Engineering Context

## TiDB Facts

- Transaction mode: ___  (run: SELECT @@tidb_txn_mode;)
- Primary key convention: $PK_STYLE
- TTL attributes in schema: $TTL_ATTR
- JSON columns: $JSON_COLS
- Vector columns: $VECTOR_COLS
- Full-text references: $FULLTEXT  (confirm these are TiDB FTS, not MySQL MATCH ... AGAINST)
- Partitioned tables: $PARTITIONS
- Foreign key references: $FOREIGN_KEYS  (Prisma relationMode: $RELATION_MODE)
- MySQL-only constructs found: $UNSUPPORTED  (procedures, triggers, events, OPTIMIZE TABLE, MATCH AGAINST, GEOMETRY)

## Conventions

- Migration tool: $MIGRATION_DIR
- Who enforces referential integrity: ___

## Testing Strategy

- Runner: $TEST_RUNNER
- Test database: $TEST_DB

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
EOF

# ── Summary to stderr ────────────────────────────────────────────────────────

{
  echo ""
  echo "=== Detection summary ==="
  echo "  Deployment:      $DEPLOYMENT"
  echo "  Drivers/ORMs:    $DRIVERS"
  echo "  Framework:       $FRAMEWORK / hosting: $HOSTING"
  echo "  Migrations:      $MIGRATION_DIR"
  echo "  PK style:        $PK_STYLE"
  echo "  TLS:             $TLS_HINT"
  echo "  Test DB:         $TEST_DB"
  echo "  Main branch:     $MAIN_BRANCH / ticket prefix: $TICKET_PREFIX"
  echo ""
  if [[ "$PUBLIC_LEAK" != "no" ]]; then
    echo "  !! $PUBLIC_LEAK"
    echo "     Rotate the credential and move it behind a server-only variable first."
    echo ""
  fi
  if [[ "$TLS_HINT" == NOT\ FOUND* ]]; then
    echo "  !  TiDB Cloud host found but no TLS verification setting. See references/tls-connections.md."
    echo ""
  fi
  if [[ "$UNSUPPORTED" -gt 0 ]]; then
    echo "  !  $UNSUPPORTED MySQL-only construct(s) in schema files. See references/mysql-compatibility.md."
    echo ""
  fi
  if [[ "$EDGE_ROUTES" -gt 0 && "$DRIVERS" == *mysql2* && "$DRIVERS" != *serverless* ]]; then
    echo "  !  Edge-runtime routes plus a TCP driver. See references/nextjs.md."
    echo ""
  fi
  if [[ "$DRIVERS" == "none detected" && "$MIGRATION_DIR" == "none found" ]]; then
    echo "  WARNING: no database driver and no migrations found. Is this the project root?"
    echo ""
  fi
  echo "Review the output above, fill in any ___ blanks, run the two SQL probes, then save into .context/ domain files"
} >&2
