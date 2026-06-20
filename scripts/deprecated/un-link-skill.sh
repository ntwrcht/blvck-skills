#!/usr/bin/env bash
# =============================================================================
# un-link-skill.sh — Remove provider symlinks for every shippable skill
#
# Shippable buckets:
#   engineering/
#   productivity/
#   misc/
#
# Targets:
#   ~/.claude/skills
#   ~/.codex/skills
#   ~/.gemini/extensions/agent-skills
#
# Usage:
#   ./scripts/un-link-skill.sh
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_skills-lib.sh"

removed=0
skipped=0
legacy_removed=0

echo ""
echo "╔══════════════════════════════════════╗"
echo "║        Skills Unlink Script          ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Repo:    $REPO_ROOT"
echo "  Skills:  $SKILLS_DIR"
for target in "${DIRECT_INSTALL_TARGETS[@]}"; do
  echo "  Target:  $target"
done
echo "  Target:  $GEMINI_EXTENSION_DIR"

while IFS= read -r skill_dir; do
  skill_name="$(skill_name_from_dir "$skill_dir")"
  log_section "Removing: $skill_name"

  for target_dir in "${DIRECT_INSTALL_TARGETS[@]}"; do
    link="$target_dir/$skill_name"

    if [ ! -e "$link" ] && [ ! -L "$link" ]; then
      continue
    fi

    if [ ! -L "$link" ]; then
      log_warn "Skipping $link — exists and is not a symlink"
      skipped=$((skipped + 1))
      continue
    fi

    rm "$link"
    log_success "Removed: $link"
    removed=$((removed + 1))
  done

  gemini_link="$GEMINI_EXTENSION_SKILLS_DIR/$skill_name"
  if [ -L "$gemini_link" ]; then
    rm "$gemini_link"
    log_success "Removed: $gemini_link"
    removed=$((removed + 1))
  elif [ -e "$gemini_link" ]; then
    log_warn "Skipping $gemini_link — exists and is not a symlink"
    skipped=$((skipped + 1))
  fi

  legacy_link="$GEMINI_LEGACY_SKILLS_DIR/$skill_name"
  if [ -L "$legacy_link" ]; then
    rm "$legacy_link"
    log_success "Removed legacy Gemini link: $legacy_link"
    legacy_removed=$((legacy_removed + 1))
  elif [ -e "$legacy_link" ]; then
    log_warn "Skipping legacy Gemini path $legacy_link — exists and is not a symlink"
    skipped=$((skipped + 1))
  fi
done < <(list_shippable_skill_dirs)

echo ""
echo "────────────────────────────────────────"
log_info "Done — $removed symlink(s) removed, $skipped skipped"
log_info "Legacy Gemini links removed — $legacy_removed"
echo ""
