#!/usr/bin/env bash
# =============================================================================
# list-skills.sh — List every SKILL.md in the repository with bucket labels
#
# Usage:
#   ./scripts/list-skills.sh
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_skills-lib.sh"

list_skill_dirs | while IFS= read -r skill_dir; do
  skill_path="${skill_dir#$SKILLS_DIR/}"
  bucket="${skill_path%%/*}"
  printf '[%s] %s\n' "$bucket" "${skill_dir#$REPO_ROOT/}/SKILL.md"
done
