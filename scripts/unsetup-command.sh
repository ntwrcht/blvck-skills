#!/usr/bin/env bash
# =============================================================================
# unsetup-command.sh — Remove the blvck-skills shortcut command
#
# Usage:
#   ./scripts/unsetup-command.sh
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

COMMAND_NAME="blvck-skills"
COMMAND_LINK_PATH="$HOME/.local/bin/$COMMAND_NAME"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║      Command Unsetup Script          ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Command: $COMMAND_NAME"
echo "  Link:    $COMMAND_LINK_PATH"
echo ""

if [ ! -e "$COMMAND_LINK_PATH" ] && [ ! -L "$COMMAND_LINK_PATH" ]; then
  log_info "Already removed: $COMMAND_LINK_PATH"
  exit 0
fi

if [ ! -L "$COMMAND_LINK_PATH" ]; then
  log_warn "Skipping $COMMAND_LINK_PATH — exists and is not a symlink"
  exit 0
fi

rm "$COMMAND_LINK_PATH"
log_success "Removed: $COMMAND_LINK_PATH"
log_info "If you added ~/.local/bin to PATH only for this command, remove that line from your shell profile manually."
echo ""
