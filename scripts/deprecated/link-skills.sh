#!/usr/bin/env bash
# =============================================================================
# link-skills.sh — Symlink shippable skills and inject shared references
#
# Shippable buckets:
#   engineering/
#   productivity/
#   misc/
#
# Targets:
#   ~/.claude/skills
#   ~/.codex/skills
#   ~/.gemini/extensions/blvck-skills
#
# Usage:
#   ./scripts/link-skills.sh
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_skills-lib.sh"

linked=0
skipped=0
legacy_removed=0
shared_linked=0
shared_skipped=0

echo ""
echo "╔══════════════════════════════════════╗"
echo "║        Skills Link Script            ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Repo:    $REPO_ROOT"
echo "  Skills:  $SKILLS_DIR"
for target in "${DIRECT_INSTALL_TARGETS[@]}"; do
  echo "  Target:  $target"
done
echo "  Target:  $GEMINI_EXTENSION_DIR"

mkdir -p "$GEMINI_EXTENSION_SKILLS_DIR"
chmod 700 "$GEMINI_EXTENSION_DIR" "$GEMINI_EXTENSION_SKILLS_DIR"

cat > "$GEMINI_EXTENSION_DIR/gemini-extension.json" <<JSON
{
  "name": "$GEMINI_EXTENSION_NAME",
  "version": "1.0.0",
  "description": "Local agent skills from blvck-skills."
}
JSON

while IFS= read -r skill_dir; do
  skill_name="$(skill_name_from_dir "$skill_dir")"
  log_section "$skill_name"

  for target_dir in "${DIRECT_INSTALL_TARGETS[@]}"; do
    mkdir -p "$target_dir"
    chmod 700 "$target_dir"

    link="$target_dir/$skill_name"

    if [ -L "$link" ]; then
      rm "$link"
    elif [ -e "$link" ]; then
      log_warn "Skipping $link — exists and is not a symlink"
      skipped=$((skipped + 1))
      continue
    fi

    ln -s "$skill_dir" "$link"
    log_success "Linked: $link"
    linked=$((linked + 1))
  done

  gemini_link="$GEMINI_EXTENSION_SKILLS_DIR/$skill_name"
  if [ -L "$gemini_link" ]; then
    rm "$gemini_link"
  elif [ -e "$gemini_link" ]; then
    log_warn "Skipping $gemini_link — exists and is not a symlink"
    skipped=$((skipped + 1))
    gemini_link=""
  fi

  if [ -n "$gemini_link" ]; then
    ln -s "$skill_dir" "$gemini_link"
    log_success "Linked: $gemini_link"
    linked=$((linked + 1))
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

  shared_files="$(get_shared_refs "$skill_name")"
  if [ -n "$shared_files" ]; then
    if [ ! -d "$SHARED_DIR" ]; then
      log_warn "_shared/references/ not found — skipping shared refs"
      continue
    fi

    mkdir -p "$skill_dir/references"

    for filename in $shared_files; do
      src="$SHARED_DIR/$filename"
      link="$skill_dir/references/$filename"

      if [ ! -f "$src" ]; then
        log_warn "Shared file not found, skipping: _shared/references/$filename"
        shared_skipped=$((shared_skipped + 1))
        continue
      fi

      if [ -L "$link" ]; then
        rm "$link"
      elif [ -e "$link" ]; then
        log_warn "Skipping references/$filename — exists and is not a symlink"
        shared_skipped=$((shared_skipped + 1))
        continue
      fi

      ln -s "$src" "$link"
      log_success "Shared ref: references/$filename"
      shared_linked=$((shared_linked + 1))
    done
  fi
done < <(list_shippable_skill_dirs)

echo ""
echo "────────────────────────────────────────"
log_info "Done — $linked link(s), $skipped skipped"
log_info "Legacy Gemini links removed — $legacy_removed"
log_info "Shared refs — $shared_linked link(s), $shared_skipped skipped"
echo ""
