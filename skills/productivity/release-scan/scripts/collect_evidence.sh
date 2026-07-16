#!/usr/bin/env bash
# collect_evidence.sh <old_tag> <new_tag> [repo_path]
#
# Emits a deterministic markdown evidence pack for one repository between two refs.
# Every engineer running this on any repo gets the same sections in the same order,
# which is what makes the resulting reports comparable.
#
# Deliberately does NOT interpret anything. Classification is the model's job.

set -uo pipefail

OLD="${1:-}"
NEW="${2:-}"
REPO="${3:-.}"

if [[ -z "$OLD" || -z "$NEW" ]]; then
  echo "usage: collect_evidence.sh <old_tag> <new_tag> [repo_path]" >&2
  exit 2
fi

cd "$REPO" || { echo "ERROR: cannot cd to $REPO" >&2; exit 2; }

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: $REPO is not a git repository" >&2
  exit 2
fi

for ref in "$OLD" "$NEW"; do
  if ! git rev-parse --verify "$ref^{commit}" >/dev/null 2>&1; then
    echo "ERROR: ref '$ref' not found. Try: git fetch --tags --force" >&2
    exit 3
  fi
done

RANGE="$OLD..$NEW"
SERVICE="$(basename "$(git rev-parse --show-toplevel)")"

section() { printf '\n\n## %s\n\n' "$1"; }

# Marks empty sections explicitly. A bare heading is ambiguous — it reads the same
# whether the command found nothing or the command broke. The report claims every
# statement traces to evidence, so "no evidence" has to be legible as a result.
emit() {
  local out
  out="$(cat)"
  if [[ -n "$out" ]]; then printf '%s\n' "$out"; else printf '_none_\n'; fi
}

# ---------------------------------------------------------------- header
cat <<EOF
# Evidence Pack

- service (repo dir): $SERVICE
- remote: $(git config --get remote.origin.url 2>/dev/null || echo "n/a")
- range: $RANGE
- old commit: $(git rev-parse --short "$OLD^{commit}")  ($(git log -1 --format=%ci "$OLD^{commit}"))
- new commit: $(git rev-parse --short "$NEW^{commit}")  ($(git log -1 --format=%ci "$NEW^{commit}"))
- commits in range: $(git rev-list --count "$RANGE" 2>/dev/null || echo "?")
- files changed: $(git diff --name-only "$RANGE" | wc -l | tr -d ' ')
- authors: $(git log "$RANGE" --format='%an' | sort -u | paste -sd', ' -)
EOF

# ---------------------------------------------------------------- commits
section "Commit subjects"
git log "$RANGE" --no-merges --pretty='- %h %s' | emit

section "Merge commits (PR titles)"
git log "$RANGE" --merges --pretty='- %h %s' | head -100 | emit

section "Issue keys referenced"
# Broad key pattern; look these up in Jira to build the real changelog.
git log "$RANGE" --pretty='%s%n%b' \
  | grep -ohE '\b[A-Z][A-Z0-9]+-[0-9]+\b' \
  | sort -u \
  | sed 's/^/- /' | emit

# ---------------------------------------------------------------- shape of change
section "Diff stat by directory (triage signal)"
git diff --name-only "$RANGE" \
  | awk -F/ '{ if (NF>1) print $1"/"$2; else print $1 }' \
  | sort | uniq -c | sort -rn | head -40 | emit

section "Full diff stat"
git diff --stat "$RANGE" | tail -60 | emit

# ---------------------------------------------------------------- high-signal paths
section "Added / deleted / renamed files (excluding tests)"
git diff --name-status --find-renames "$RANGE" \
  | grep -vEi '(_test\.|\.test\.|\.spec\.|/tests?/|/__tests__/|/testdata/)' \
  | grep -E '^(A|D|R)' | head -80 | emit

section "Migration / schema files touched"
git diff --name-status "$RANGE" \
  | grep -iE 'migrat|schema|\.sql|liquibase|flyway|alembic|index' | head -60 | emit

section "API / route / contract files touched"
git diff --name-status "$RANGE" \
  | grep -iE 'openapi|swagger|\.proto$|(^|[[:space:]/])(api|routes?|handlers?|controllers?|endpoints?|grpc)/' \
  | head -80 | emit

# ---------------------------------------------------------------- config surface
section "Config keys / env vars ADDED (lines added in diff)"
# Covers Go os.Getenv/viper, Node process.env, and generic YAML/env declarations.
git diff "$RANGE" -- . ':(exclude)*_test.go' ':(exclude)*.test.*' \
  | grep '^+' | grep -v '^+++' \
  | grep -ohE 'os\.Getenv\("[A-Za-z0-9_]+"\)|viper\.Get[A-Za-z]*\("[A-Za-z0-9_.]+"\)|process\.env\.[A-Za-z0-9_]+|env\.[A-Z][A-Z0-9_]+' \
  | sort -u | sed 's/^/- /' | head -60 | emit

section "Config keys / env vars REMOVED (lines removed in diff)"
git diff "$RANGE" -- . ':(exclude)*_test.go' ':(exclude)*.test.*' \
  | grep '^-' | grep -v '^---' \
  | grep -ohE 'os\.Getenv\("[A-Za-z0-9_]+"\)|viper\.Get[A-Za-z]*\("[A-Za-z0-9_.]+"\)|process\.env\.[A-Za-z0-9_]+|env\.[A-Z][A-Z0-9_]+' \
  | sort -u | sed 's/^/- /' | head -60 | emit

section "Env / config file diffs"
git diff "$RANGE" -- '*.env*' '*config*.yaml' '*config*.yml' '*config*.json' '*settings*' \
  ':(exclude)*node_modules*' | head -200 | emit

# ---------------------------------------------------------------- runtime
section "Dockerfile diff"
git diff "$RANGE" -- '*Dockerfile*' | head -120 | emit

section "Deployment manifest diff (k8s / helm / compose)"
git diff "$RANGE" -- 'k8s/**' 'deploy/**' 'chart*/**' 'helm/**' '*values*.yaml' '*docker-compose*' \
  | head -200 | emit

# ---------------------------------------------------------------- dependencies
section "Dependency manifest diff"
git diff "$RANGE" -- go.mod package.json requirements.txt pyproject.toml Cargo.toml pom.xml build.gradle \
  | head -200 | emit

section "Outbound hosts newly referenced (firewall allowlist candidates)"
git diff "$RANGE" | grep '^+' | grep -v '^+++' \
  | grep -ohE 'https?://[a-zA-Z0-9.-]+' | sort -u | sed 's/^/- /' | head -40 | emit

printf '\n\n---\nEND OF EVIDENCE PACK\n'
