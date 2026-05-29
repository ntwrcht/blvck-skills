#!/usr/bin/env bash
# =============================================================================
# validate-skill-descriptions.sh — Check public skill descriptions stay neutral
#
# Usage:
#   ./scripts/validate-skill-descriptions.sh
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_skills-lib.sh"

BANNED_PATTERN='ALWAYS use|MUST use|Use when|Trigger when|Trigger on|proactively whenever|Do NOT attempt|no exceptions'
FAILED=0

check_text() {
  local label="$1"
  local text="$2"

  if printf '%s\n' "$text" | grep -Eiq "$BANNED_PATTERN"; then
    log_error "$label contains activation-heavy wording"
    printf '%s\n' "$text" | grep -Ein "$BANNED_PATTERN" || true
    FAILED=1
  fi
}

extract_frontmatter() {
  local file="$1"

  awk '
    NR == 1 && $0 == "---" { in_fm = 1; print; next }
    in_fm && $0 == "---" { print; exit }
    in_fm { print }
  ' "$file"
}

log_section "Checking README inventory descriptions"
check_text "README.md" "$(sed -n '/## .*Available Skills/,/## .*Getting Started/p' "$REPO_ROOT/README.md")"

for bucket_readme in \
  "$SKILLS_DIR/engineering/README.md" \
  "$SKILLS_DIR/productivity/README.md" \
  "$SKILLS_DIR/misc/README.md"; do
  [ -f "$bucket_readme" ] || continue
  check_text "${bucket_readme#$REPO_ROOT/}" "$(cat "$bucket_readme")"
done

log_section "Checking shippable SKILL.md frontmatter"
while IFS= read -r skill_dir; do
  skill_file="$skill_dir/SKILL.md"
  check_text "${skill_file#$REPO_ROOT/} frontmatter" "$(extract_frontmatter "$skill_file")"
done < <(list_shippable_skill_dirs)

if [ "$FAILED" -ne 0 ]; then
  cat <<'EOF'

Public skill descriptions should be neutral inventory text.
Move trigger rules such as "Use when", "ALWAYS use", or "Trigger when" into the
body of the relevant SKILL.md under a "When to Use" section.
EOF
  exit 1
fi

log_success "Skill descriptions are neutral"
