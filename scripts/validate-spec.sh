#!/usr/bin/env bash
# =============================================================================
# validate-spec.sh — Validate every shippable skill with the official
# Agent Skills reference validator.
#
# Runs `agentskills validate` (package: skills-ref, Apache-2.0, published to
# PyPI by Anthropic). This is the authoritative implementation of
# https://agentskills.io/specification, so it catches things our own regexes
# would miss — notably unknown or misspelled frontmatter fields.
#
# NOTE: the PyPI package `skills-ref` provides the `agentskills` executable.
# An unrelated npm package also uses the name `skills-ref`; do not use it.
#
# Two Claude Code fields are tolerated (see TOLERATED_FIELDS below). Everything
# else the spec rejects is a hard failure here.
#
# Usage:
#   ./scripts/validate-spec.sh
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_skills-lib.sh"

SKILLS_REF_VERSION="0.1.1"

# Claude Code reads these at the top level of the frontmatter, so they cannot be
# nested under the spec's `metadata` escape hatch without breaking behavior:
#   disable-model-invocation — makes a skill user-invocable only
#   argument-hint            — the slash-command argument hint
# They are deliberate deltas from the spec's field list, not mistakes.
TOLERATED_FIELDS="argument-hint disable-model-invocation"

FAILED=0
TOLERATED=0
PASSED=0

if ! command -v uvx >/dev/null 2>&1; then
  log_error "uvx not found — install uv: https://docs.astral.sh/uv/getting-started/installation/"
  exit 1
fi

run_validate() {
  uvx --quiet --from "skills-ref==$SKILLS_REF_VERSION" agentskills validate "$1" 2>&1
}

# True when every complaint is an unexpected-field error naming only tolerated fields.
only_tolerated_fields() {
  local output="$1" complaints field_lists field

  complaints="$(printf '%s\n' "$output" | grep -E '^\s+- ' || true)"
  [ -n "$complaints" ] || return 1

  # Any complaint that is not an unexpected-field error disqualifies.
  if printf '%s\n' "$complaints" | grep -qv 'Unexpected fields in frontmatter:'; then
    return 1
  fi

  field_lists="$(
    printf '%s\n' "$complaints" |
      sed -n 's/.*Unexpected fields in frontmatter: \(.*\)\. Only.*/\1/p' |
      tr ',' '\n' | tr -d ' '
  )"
  [ -n "$field_lists" ] || return 1

  while IFS= read -r field; do
    [ -n "$field" ] || continue
    _is_in_list "$field" $TOLERATED_FIELDS || return 1
  done <<< "$field_lists"

  return 0
}

log_section "Validating against the Agent Skills spec (skills-ref $SKILLS_REF_VERSION)"

while IFS= read -r skill_dir; do
  rel="${skill_dir#"$REPO_ROOT"/}"

  set +e
  output="$(run_validate "$skill_dir")"
  code=$?
  set -e

  if [ "$code" -eq 0 ]; then
    PASSED=$((PASSED + 1))
  elif only_tolerated_fields "$output"; then
    TOLERATED=$((TOLERATED + 1))
  else
    log_error "$rel"
    printf '%s\n' "$output" | grep -E '^\s+- ' || printf '%s\n' "$output"
    FAILED=$((FAILED + 1))
  fi
done < <(list_shippable_skill_dirs)

log_info "$PASSED fully spec-clean, $TOLERATED with tolerated Claude Code fields"

if [ "$FAILED" -ne 0 ]; then
  cat <<EOF

$FAILED skill(s) violate the Agent Skills spec beyond the tolerated Claude Code
fields ($TOLERATED_FIELDS).

Spec: https://agentskills.io/specification
EOF
  exit 1
fi

log_success "All shippable skills conform to the Agent Skills spec"
