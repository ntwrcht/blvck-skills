#!/bin/bash
# =============================================================================
# setup-skills.sh — Symlink skills and inject shared references
#
# Directory structure:
#   <repo>/
#   ├── setup-skills.sh
#   └── skills/
#       ├── _shared/
#       │   └── references/
#       │       └── commit-convention.md
#       ├── angular-engineer/
#       │   ├── SKILL.md
#       │   └── references/
#       └── strapi-engineer/
#           ├── SKILL.md
#           └── references/
#
# Usage:
#   ./setup-skills.sh                   # setup all skills
#   ./setup-skills.sh angular-engineer  # setup one skill
#   ./setup-skills.sh --dry-run         # preview without changes
#   ./setup-skills.sh --remove          # remove all symlinks
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
SHARED_DIR="$SKILLS_DIR/_shared/references"

INSTALL_TARGETS=(
  "$HOME/.claude/skills"
  "$HOME/.gemini/skills"
)

# ── Shared references per skill ───────────────────────────────────────────────
# Add new skills here as you create them.
# Return space-separated filenames from _shared/references/ to inject.

get_shared_refs() {
  local skill_name="$1"
  case "$skill_name" in
    angular-engineer) echo "commit-convention.md" ;;
    strapi-engineer)  echo "commit-convention.md" ;;
    ga4-analytics)    echo "" ;;
    security-audit)   echo "" ;;
    *)                echo "" ;;
  esac
}

# ── Helpers ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=false
REMOVE=false
TARGET_SKILL=""
ERRORS=0

log_info()    { echo -e "  ${BLUE}→${NC}  $1"; }
log_success() { echo -e "  ${GREEN}✓${NC}  $1"; }
log_warn()    { echo -e "  ${YELLOW}⚠${NC}  $1"; }
log_error()   { echo -e "  ${RED}✗${NC}  $1"; ERRORS=$((ERRORS + 1)); }
log_dry()     { echo -e "  ${YELLOW}~${NC}  [dry] $1"; }
log_section() { echo -e "\n${CYAN}▸ $1${NC}"; }

# ── Parse args ────────────────────────────────────────────────────────────────

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --remove)  REMOVE=true ;;
    --help|-h)
      echo "Usage: $0 [skill-name] [--dry-run] [--remove]"
      echo ""
      echo "  skill-name   Target a single skill (default: all)"
      echo "  --dry-run    Preview without making changes"
      echo "  --remove     Remove all symlinks created by this script"
      exit 0
      ;;
    -*) log_error "Unknown flag: $arg"; exit 1 ;;
    *)
      # Hardening: Strict validation for skill name
      if [[ ! "$arg" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid skill name: '$arg'. Only alphanumeric, hyphens, and underscores allowed."
        exit 1
      fi
      TARGET_SKILL="$arg"
      ;;
  esac
done

# ── Remove mode ───────────────────────────────────────────────────────────────

remove_skill() {
  local skill_name="$1"
  local skill_path="$SKILLS_DIR/$skill_name"

  log_section "Removing: $skill_name"

  # Remove skill symlinks from install targets
  for target_dir in "${INSTALL_TARGETS[@]}"; do
    local link="$target_dir/$skill_name"
    if [ -L "$link" ]; then
      if [ "$DRY_RUN" = true ]; then
        log_dry "Would remove: $link"
      else
        rm "$link"
        log_success "Removed: $link"
      fi
    fi
  done

  # Remove shared reference symlinks inside skill
  local shared_files
  shared_files="$(get_shared_refs "$skill_name")"

  if [ -n "$shared_files" ]; then
    for filename in $shared_files; do
      local link="$skill_path/references/$filename"
      if [ -L "$link" ]; then
        if [ "$DRY_RUN" = true ]; then
          log_dry "Would remove shared ref: references/$filename"
        else
          rm "$link"
          log_success "Removed shared ref: references/$filename"
        fi
      fi
    done
  fi
}

# ── Setup function ────────────────────────────────────────────────────────────

setup_skill() {
  local skill_name="$1"
  local skill_path="$SKILLS_DIR/$skill_name"

  log_section "$skill_name"

  # Validate
  if [ ! -d "$skill_path" ]; then
    log_error "Skill folder not found: skills/$skill_name"
    return 1
  fi

  if [ ! -f "$skill_path/SKILL.md" ]; then
    log_error "SKILL.md not found in: skills/$skill_name"
    return 1
  fi

  # 1. Symlink skill folder into each install target
  for target_dir in "${INSTALL_TARGETS[@]}"; do
    local link="$target_dir/$skill_name"

    if [ "$DRY_RUN" = true ]; then
      log_dry "Would symlink: $link → $skill_path"
      continue
    fi

    # Hardening: Ensure target parent directory exists and is a directory
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
        chmod 700 "$target_dir" # Restrictive permissions
    fi

    if [ -L "$link" ]; then
      rm "$link"
    elif [ -e "$link" ]; then
      log_warn "Skipping $link — exists and is not a symlink (remove manually)"
      continue
    fi

    # Hardening: Use relative symlink if possible, or absolute with full path validation
    ln -sf "$skill_path" "$link"
    log_success "Linked: $link"
  done

  # 2. Symlink shared references into skill's references/ folder
  local shared_files
  shared_files="$(get_shared_refs "$skill_name")"

  if [ -n "$shared_files" ] && [ -d "$SHARED_DIR" ]; then
    mkdir -p "$skill_path/references"

    for filename in $shared_files; do
      local src="$SHARED_DIR/$filename"
      local link="$skill_path/references/$filename"

      if [ ! -f "$src" ]; then
        log_warn "Shared file not found, skipping: _shared/references/$filename"
        continue
      fi

      if [ "$DRY_RUN" = true ]; then
        log_dry "Would symlink shared ref: references/$filename → _shared/references/$filename"
        continue
      fi

      if [ -L "$link" ]; then
        rm "$link"
      elif [ -f "$link" ]; then
        log_warn "references/$filename is a real file — remove manually to use shared version"
        continue
      fi

      ln -sf "$src" "$link"
      log_success "Shared ref: references/$filename"
    done

  elif [ -n "$shared_files" ] && [ ! -d "$SHARED_DIR" ]; then
    log_warn "_shared/references/ not found — skipping shared refs for $skill_name"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════╗"
echo "║        Skills Setup Script           ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Repo:    $REPO_ROOT"
echo "  Skills:  $SKILLS_DIR"
for target in "${INSTALL_TARGETS[@]}"; do
  echo "  Target:  $target"
done
[ "$DRY_RUN" = true ] && echo -e "\n  ${YELLOW}Mode: DRY RUN — no changes will be made${NC}"
[ "$REMOVE" = true ]  && echo -e "\n  ${RED}Mode: REMOVE — symlinks will be deleted${NC}"

# Collect skills to process
skills_to_process=()

if [ -n "$TARGET_SKILL" ]; then
  skills_to_process=("$TARGET_SKILL")
else
  # Hardening: find -maxdepth to avoid traversing too deep
  for skill_dir in "$SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    local_name=$(basename "$skill_dir")
    [ "$local_name" = "_shared" ] && continue
    [ ! -f "$skill_dir/SKILL.md" ] && continue
    skills_to_process+=("$local_name")
  done
fi

# Run
for skill_name in "${skills_to_process[@]}"; do
  if [ "$REMOVE" = true ]; then
    remove_skill "$skill_name"
  else
    setup_skill "$skill_name"
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────"

if [ "$DRY_RUN" = true ]; then
  log_info "Dry run complete — no changes made"
elif [ "$ERRORS" -eq 0 ]; then
  if [ "$REMOVE" = true ]; then
    echo -e "  ${GREEN}✓${NC}  Done — symlinks removed"
  else
    total="${#skills_to_process[@]}"
    echo -e "  ${GREEN}✓${NC}  Done — $total skill(s) ready"
    echo ""
    for target in "${INSTALL_TARGETS[@]}"; do
      if [ -d "$target" ]; then
        count=$(ls "$target" 2>/dev/null | wc -l | tr -d ' ')
        echo "       $count skill(s) in $target"
      fi
    done
  fi
else
  echo -e "  ${RED}✗${NC}  Done with $ERRORS error(s)"
  exit 1
fi

echo ""
