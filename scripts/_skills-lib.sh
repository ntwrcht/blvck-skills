#!/usr/bin/env bash
# =============================================================================
# _skills-lib.sh — Shared helpers for skill management scripts
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
SHARED_DIR="$SKILLS_DIR/_shared/references"

ALL_BUCKETS=(
  "engineering"
  "productivity"
  "misc"
  "personal"
  "in-progress"
  "deprecated"
)

SHIPPABLE_BUCKETS=(
  "engineering"
  "productivity"
  "misc"
)

# Curated minimal bundles — custom mode exposes all 25+ skills
BUNDLE_PROJECT_PM_SKILLS=(
  "grill-me" "grilling" "write-a-prd" "write-a-story"
  "prototype" "stakeholder-update" "management-talk" "handoff" "caveman"
)

BUNDLE_PROJECT_DEV_SKILLS=(
  "grill-with-docs" "grilling" "write-a-story" "handoff"
  "triage" "tdd" "debug-mantra" "diagnose"
  "domain-modeling" "prototype" "scrutinize" "security-audit" "git-guardrails"
)

# Personal-bucket skills the local installer offers even though they stay out
# of the shipped catalog (README + plugin.json). Kept local on purpose, e.g.
# release-rollup pairs with the shipped release-scan but isn't promoted.
LOCAL_EXTRA_SKILLS=(
  "release-rollup"
)

DIRECT_INSTALL_TARGETS=(
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
)

GEMINI_LEGACY_SKILLS_DIR="$HOME/.gemini/skills"
GEMINI_EXTENSION_NAME="blvck-skills"
GEMINI_EXTENSION_DIR="$HOME/.gemini/extensions/$GEMINI_EXTENSION_NAME"
GEMINI_EXTENSION_SKILLS_DIR="$GEMINI_EXTENSION_DIR/skills"

# ── Logging ───────────────────────────────────────────────────────────────────

GREEN='\033[38;5;82m'
YELLOW='\033[38;5;214m'
RED='\033[38;5;196m'
CYAN='\033[38;5;51m'
GRAY='\033[38;5;240m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

log_info()    { printf "  ${GRAY}·${NC}  %s\n" "$1"; }
log_success() { printf "  ${GREEN}✓${NC}  %s\n" "$1"; }
log_warn()    { printf "  ${YELLOW}⚠${NC}  %s\n" "$1"; }
log_error()   { printf "  ${RED}✗${NC}  %s\n" "$1"; }
log_section() { printf "\n  ${BOLD}${CYAN}%s${NC}\n\n" "$1"; }

# ── Helpers ───────────────────────────────────────────────────────────────────

get_shared_refs() {
  local skill_name="$1"
  case "$skill_name" in
    angular-engineer)             echo "git-workflow.md artifact-paths.md" ;;
    strapi-engineer)              echo "context-template.md git-workflow.md artifact-paths.md" ;;
    ga4-measurement)              echo "context-template.md artifact-paths.md" ;;
    security-audit)               echo "context-template.md artifact-paths.md" ;;
    python-engineer)              echo "artifact-paths.md" ;;
    write-a-prd)                  echo "artifact-paths.md" ;;
    write-a-story)                echo "artifact-paths.md" ;;
    brainstorming)                echo "artifact-paths.md" ;;
    grilling)                     echo "artifact-paths.md" ;;
    debug-mantra)                 echo "artifact-paths.md" ;;
    diagnose)                     echo "artifact-paths.md" ;;
    domain-modeling)              echo "artifact-paths.md" ;;
    post-mortem)                  echo "artifact-paths.md" ;;
    scrutinize)                   echo "artifact-paths.md" ;;
    subagent-driven-development)  echo "artifact-paths.md" ;;
    management-talk)              echo "artifact-paths.md" ;;
    stakeholder-update)           echo "artifact-paths.md" ;;
    tdd)                          echo "artifact-paths.md" ;;
    triage)                       echo "artifact-paths.md" ;;
    setup-context)                echo "artifact-paths.md" ;;
    *)                echo "" ;;
  esac
}

skill_name_from_dir() {
  basename "$1"
}

list_skill_dirs() {
  local bucket
  local skill_dir

  for bucket in "${ALL_BUCKETS[@]}"; do
    [ -d "$SKILLS_DIR/$bucket" ] || continue

    for skill_dir in "$SKILLS_DIR/$bucket"/*/; do
      [ -d "$skill_dir" ] || continue
      [ -f "$skill_dir/SKILL.md" ] || continue
      printf '%s\n' "${skill_dir%/}"
    done
  done
}

list_shippable_skill_dirs() {
  local bucket
  local skill_dir

  for bucket in "${SHIPPABLE_BUCKETS[@]}"; do
    [ -d "$SKILLS_DIR/$bucket" ] || continue

    for skill_dir in "$SKILLS_DIR/$bucket"/*/; do
      [ -d "$skill_dir" ] || continue
      [ -f "$skill_dir/SKILL.md" ] || continue
      printf '%s\n' "${skill_dir%/}"
    done
  done
}

_is_in_list() {
  local needle="$1"; shift
  local item
  for item in "$@"; do [ "$item" = "$needle" ] && return 0; done
  return 1
}

# list_installable_skill_dirs
#   Every shippable skill, plus any non-shippable skill whitelisted in
#   LOCAL_EXTRA_SKILLS. Used by the local installer so hand-picked personal
#   skills can be installed without entering the public catalog.
list_installable_skill_dirs() {
  local bucket skill_dir skill_name

  list_shippable_skill_dirs

  for bucket in "${ALL_BUCKETS[@]}"; do
    _is_in_list "$bucket" "${SHIPPABLE_BUCKETS[@]}" && continue
    [ -d "$SKILLS_DIR/$bucket" ] || continue

    for skill_dir in "$SKILLS_DIR/$bucket"/*/; do
      [ -d "$skill_dir" ] || continue
      [ -f "$skill_dir/SKILL.md" ] || continue
      skill_name="$(skill_name_from_dir "${skill_dir%/}")"
      _is_in_list "$skill_name" "${LOCAL_EXTRA_SKILLS[@]}" &&
        printf '%s\n' "${skill_dir%/}"
    done
  done
}

# list_skills_for_preset <preset>
#   preset: project-pm | project-dev
# Prints skill dirs that belong to the curated bundle for that preset.
list_skills_for_preset() {
  local preset="$1" skill_dir skill_name bundle=()

  case "$preset" in
    project-pm)  bundle=("${BUNDLE_PROJECT_PM_SKILLS[@]}") ;;
    project-dev) bundle=("${BUNDLE_PROJECT_DEV_SKILLS[@]}") ;;
    *) return 1 ;;
  esac

  while IFS= read -r skill_dir; do
    skill_name="$(skill_name_from_dir "$skill_dir")"
    _is_in_list "$skill_name" "${bundle[@]}" && printf '%s\n' "$skill_dir"
  done < <(list_shippable_skill_dirs)
}
