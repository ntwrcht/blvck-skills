#!/usr/bin/env bash
# =============================================================================
# setup-command.sh — Create the blvck-skills shortcut command
#
# Usage:
#   ./scripts/setup-command.sh
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
COMMAND_LINK_DIR="$HOME/.local/bin"
COMMAND_LINK_PATH="$COMMAND_LINK_DIR/$COMMAND_NAME"
INSTALLER_PATH="$REPO_ROOT/scripts/blvck-skills.sh"

confirm() {
  local prompt="$1"
  local answer
  printf '%s' "$prompt"
  IFS= read -r answer
  case "$answer" in
    ""|y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

echo ""
echo "╔══════════════════════════════════════╗"
echo "║        Command Setup Script          ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Command: $COMMAND_NAME"
echo "  Link:    $COMMAND_LINK_PATH"
echo "  Target:  $INSTALLER_PATH"
echo ""

if ! confirm "Create or update $COMMAND_NAME command? [Y/n]: "; then
  log_warn "Command setup cancelled."
  exit 0
fi

mkdir -p "$COMMAND_LINK_DIR"

if [ -L "$COMMAND_LINK_PATH" ]; then
  rm "$COMMAND_LINK_PATH"
elif [ -e "$COMMAND_LINK_PATH" ]; then
  log_error "$COMMAND_LINK_PATH exists and is not a symlink"
  log_info "Move or remove it before running this script again."
  exit 1
fi

ln -s "$INSTALLER_PATH" "$COMMAND_LINK_PATH"
log_success "Created: $COMMAND_LINK_PATH"

case ":$PATH:" in
  *":$COMMAND_LINK_DIR:"*)
    log_success "$COMMAND_LINK_DIR is already on PATH"
    ;;
  *)
    log_warn "$COMMAND_LINK_DIR is not on PATH"
    log_info "Add this to your shell profile: export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

echo ""
log_info "After setup, run project installs with:"
echo "  cd /path/to/project"
echo "  $COMMAND_NAME"
echo ""
