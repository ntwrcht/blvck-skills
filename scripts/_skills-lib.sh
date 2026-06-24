#!/usr/bin/env bash
# =============================================================================
# _skills-lib.sh — Shared helpers for skill management scripts
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
COMMANDS_DIR="$REPO_ROOT/commands"
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

# Skills too stack/domain-specific for a global install
GLOBAL_EXCLUDE_SKILLS=(
  "angular-engineer"
  "strapi-engineer"
  "python-engineer"
  "ga4-measurement"
  "technical-trading-strategy"
)

DIRECT_INSTALL_TARGETS=(
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
)

GEMINI_LEGACY_SKILLS_DIR="$HOME/.gemini/skills"
GEMINI_EXTENSION_NAME="agent-skills"
GEMINI_EXTENSION_DIR="$HOME/.gemini/extensions/$GEMINI_EXTENSION_NAME"
GEMINI_EXTENSION_SKILLS_DIR="$GEMINI_EXTENSION_DIR/skills"

FZF_AVAILABLE=0
command -v fzf >/dev/null 2>&1 && FZF_AVAILABLE=1

# ── Logging ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "  ${BLUE}→${NC}  $1"; }
log_success() { echo -e "  ${GREEN}✓${NC}  $1"; }
log_warn()    { echo -e "  ${YELLOW}⚠${NC}  $1"; }
log_error()   { echo -e "  ${RED}✗${NC}  $1"; }
log_section() { echo -e "\n${CYAN}▸ $1${NC}"; }

# ── Helpers ───────────────────────────────────────────────────────────────────

get_shared_refs() {
  local skill_name="$1"
  case "$skill_name" in
    angular-engineer) echo "context-template.md git-workflow.md" ;;
    strapi-engineer)  echo "context-template.md git-workflow.md" ;;
    ga4-measurement)  echo "context-template.md" ;;
    security-audit)   echo "context-template.md" ;;
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

command_name_from_dir() {
  basename "$1"
}

list_shippable_command_dirs() {
  local bucket
  local command_dir

  for bucket in "${SHIPPABLE_BUCKETS[@]}"; do
    [ -d "$COMMANDS_DIR/$bucket" ] || continue

    for command_dir in "$COMMANDS_DIR/$bucket"/*/; do
      [ -d "$command_dir" ] || continue
      [ -f "$command_dir/command.md" ] || continue
      printf '%s\n' "${command_dir%/}"
    done
  done
}

_is_in_list() {
  local needle="$1"; shift
  local item
  for item in "$@"; do [ "$item" = "$needle" ] && return 0; done
  return 1
}

# list_skills_for_preset <preset>
#   preset: global | project-pm | project-dev
# Prints skill dirs belonging to the named preset.
list_skills_for_preset() {
  local preset="$1" skill_dir skill_name

  while IFS= read -r skill_dir; do
    skill_name="$(skill_name_from_dir "$skill_dir")"
    case "$preset" in
      global)
        _is_in_list "$skill_name" "${GLOBAL_EXCLUDE_SKILLS[@]}" && continue
        printf '%s\n' "$skill_dir"
        ;;
      project-pm)
        [[ "$skill_dir" == */productivity/* ]] && printf '%s\n' "$skill_dir"
        ;;
      project-dev)
        printf '%s\n' "$skill_dir"
        ;;
    esac
  done < <(list_shippable_skill_dirs)
}
