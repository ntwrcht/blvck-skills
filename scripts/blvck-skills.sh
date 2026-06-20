#!/usr/bin/env bash
# =============================================================================
# blvck-skills.sh — Entry point for the blvck-skills command
#
# Usage:
#   blvck-skills
# =============================================================================

set -euo pipefail

script_source="${BASH_SOURCE[0]}"
while [ -L "$script_source" ]; do
  script_dir="$(cd -P "$(dirname "$script_source")" && pwd)"
  script_source="$(readlink "$script_source")"
  case "$script_source" in
    /*) ;;
    *) script_source="$script_dir/$script_source" ;;
  esac
done
script_dir="$(cd -P "$(dirname "$script_source")" && pwd)"

source "$script_dir/_skills-lib.sh"

read_prompt() {
  local var_name="$1" prompt prompt_answer
  shift
  prompt="$1"
  printf '%s' "$prompt" >&2
  if ! IFS= read -r prompt_answer; then
    echo "" >&2
    exit 0
  fi
  printf -v "$var_name" '%s' "$prompt_answer"
}

echo ""
echo "╔══════════════════════════════════════╗"
echo "║           blvck-skills               ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Repo: $REPO_ROOT"
echo ""
echo "  1) Install skills / slash commands"
echo "  2) Uninstall skills / slash commands"
echo ""

while true; do
  read_prompt answer "Choose an action [1]: "
  [ -n "$answer" ] || answer="1"
  case "$answer" in
    1|install)   exec "$script_dir/install-skills.sh" ;;
    2|uninstall) exec "$script_dir/uninstall-skills.sh" ;;
    *) echo "  Enter 1 to install or 2 to uninstall." ;;
  esac
done
