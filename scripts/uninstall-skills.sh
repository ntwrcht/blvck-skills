#!/usr/bin/env bash
# =============================================================================
# uninstall-skills.sh — Interactive uninstaller for agent skills and commands
#
# Global uninstalls remove symlinks from CLI config directories.
# Project uninstalls remove copies from project-local CLI directories.
#
# Usage:
#   ./scripts/uninstall-skills.sh
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

MARKER_FILE=".agent-skills-install.json"
PROJECT_MANIFEST=".agent-skills-install.json"

CLI_NAMES=("Claude" "Codex" "Gemini")
CLI_IDS=("claude" "codex" "gemini")

SELECTED_CLI_IDS=()
SELECTED_SCOPE=""
PROJECT_ROOT=""
UNINSTALL_SKILLS=1
UNINSTALL_COMMANDS=0
SELECTED_SKILL_NAMES=()
SELECTED_COMMAND_NAMES=()

removed=0
skipped=0
not_found=0

# ── Helpers ───────────────────────────────────────────────────────────────────

absolute_path() {
  (cd "$1" 2>/dev/null && pwd -P)
}

read_prompt() {
  local var_name="$1" prompt prompt_answer
  shift
  prompt="$1"
  printf '%s' "$prompt" >&2
  if ! IFS= read -r prompt_answer; then
    echo "" >&2
    printf '  No input received; cancelling uninstall.\n' >&2
    exit 0
  fi
  printf -v "$var_name" '%s' "$prompt_answer"
}

confirm() {
  local answer
  read_prompt answer "$1"
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

contains_value() {
  local needle="$1"
  shift
  local value
  for value in "$@"; do
    [ "$value" = "$needle" ] && return 0
  done
  return 1
}

append_unique() {
  local value="$1"
  local array_name="$2"
  eval "contains_value \"\$value\" \"\${${array_name}[@]:-}\"" && return 0
  eval "${array_name}+=(\"\$value\")"
}

expand_selection_tokens() {
  local input="$1"
  local max="$2"
  local token start end i

  input="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]' | tr ',' ' ')"
  for token in $input; do
    if [ "$token" = "all" ]; then
      i=1
      while [ "$i" -le "$max" ]; do
        printf '%s\n' "$i"
        i=$((i + 1))
      done
      continue
    fi

    case "$token" in
      *-*)
        start="${token%-*}"
        end="${token#*-}"
        case "$start" in ""|*[!0-9]*) return 1 ;; esac
        case "$end"   in ""|*[!0-9]*) return 1 ;; esac
        [ "$start" -le "$end" ] || return 1
        i="$start"
        while [ "$i" -le "$end" ]; do
          [ "$i" -ge 1 ] && [ "$i" -le "$max" ] || return 1
          printf '%s\n' "$i"
          i=$((i + 1))
        done
        ;;
      *)
        case "$token" in *[!0-9]*) return 1 ;; esac
        [ "$token" -ge 1 ] && [ "$token" -le "$max" ] || return 1
        printf '%s\n' "$token"
        ;;
    esac
  done
}

# ── Target dir helpers (mirrors install-skills.sh) ───────────────────────────

cli_target_dir() {
  local cli_id="$1"
  local scope="$2"
  local root="$3"

  if [ "$scope" = "global" ]; then
    case "$cli_id" in
      claude) printf '%s\n' "$HOME/.claude/skills" ;;
      codex)  printf '%s\n' "$HOME/.codex/skills" ;;
      gemini) printf '%s\n' "$GEMINI_EXTENSION_SKILLS_DIR" ;;
    esac
  else
    case "$cli_id" in
      claude) printf '%s\n' "$root/.claude/skills" ;;
      codex)  printf '%s\n' "$root/.codex/skills" ;;
      gemini) printf '%s\n' "$root/.gemini/extensions/$GEMINI_EXTENSION_NAME/skills" ;;
    esac
  fi
}

command_target_dir() {
  local cli_id="$1"
  local scope="$2"
  local root="$3"

  if [ "$scope" = "global" ]; then
    case "$cli_id" in
      claude) printf '%s\n' "$HOME/.claude/commands" ;;
      codex)  printf '%s\n' "$HOME/.codex/commands" ;;
      gemini) printf '%s\n' "$HOME/.gemini/commands" ;;
    esac
  else
    case "$cli_id" in
      claude) printf '%s\n' "$root/.claude/commands" ;;
      codex)  printf '%s\n' "$root/.codex/commands" ;;
      gemini) printf '%s\n' "$root/.gemini/commands" ;;
    esac
  fi
}

# ── Discover installed items ──────────────────────────────────────────────────

list_installed_skills() {
  local scope="$1"
  local root="$2"
  local cli_id target_dir skill_path skill_name
  local seen=()

  for cli_id in "${SELECTED_CLI_IDS[@]}"; do
    target_dir="$(cli_target_dir "$cli_id" "$scope" "$root")"
    [ -d "$target_dir" ] || continue

    for skill_path in "$target_dir"/*/; do
      [ -e "$skill_path" ] || [ -L "$skill_path" ] || continue
      skill_name="$(basename "${skill_path%/}")"
      contains_value "$skill_name" "${seen[@]:-}" && continue
      seen+=("$skill_name")
      printf '%s\n' "$skill_name"
    done
  done
}

list_installed_commands() {
  local scope="$1"
  local root="$2"
  local cli_id target_dir cmd_path cmd_name
  local seen=()

  for cli_id in "${SELECTED_CLI_IDS[@]}"; do
    target_dir="$(command_target_dir "$cli_id" "$scope" "$root")"
    [ -d "$target_dir" ] || continue

    for cmd_path in "$target_dir"/*.md "$target_dir"/*.toml; do
      [ -e "$cmd_path" ] || [ -L "$cmd_path" ] || continue
      cmd_name="$(basename "$cmd_path")"
      cmd_name="${cmd_name%.md}"
      cmd_name="${cmd_name%.toml}"
      contains_value "$cmd_name" "${seen[@]:-}" && continue
      seen+=("$cmd_name")
      printf '%s\n' "$cmd_name"
    done
  done
}

# ── UI steps ──────────────────────────────────────────────────────────────────

select_content() {
  local answer

  echo ""
  log_section "Choose Content"
  echo "  1) Skills"
  echo "  2) Slash commands"
  echo "  3) Both"
  echo ""

  while true; do
    read_prompt answer "Uninstall what? [3]: "
    [ -n "$answer" ] || answer="3"
    case "$answer" in
      1|skills)                    UNINSTALL_SKILLS=1; UNINSTALL_COMMANDS=0; return 0 ;;
      2|commands|slash|slash-commands) UNINSTALL_SKILLS=0; UNINSTALL_COMMANDS=1; return 0 ;;
      3|both|all)                  UNINSTALL_SKILLS=1; UNINSTALL_COMMANDS=1; return 0 ;;
      *) log_warn "Enter 1 for skills, 2 for commands, or 3 for both." ;;
    esac
  done
}

select_clis() {
  local answer index

  echo ""
  log_section "Choose CLIs"
  index=1
  while [ "$index" -le "${#CLI_NAMES[@]}" ]; do
    printf '  %s) %s\n' "$index" "${CLI_NAMES[$((index - 1))]}"
    index=$((index + 1))
  done
  echo "  all) Claude, Codex, and Gemini"
  echo ""

  while true; do
    read_prompt answer "Uninstall for which CLIs? [all]: "
    [ -n "$answer" ] || answer="all"

    SELECTED_CLI_IDS=()
    if indexes="$(expand_selection_tokens "$answer" "${#CLI_NAMES[@]}")"; then
      while IFS= read -r index; do
        [ -n "$index" ] || continue
        append_unique "${CLI_IDS[$((index - 1))]}" SELECTED_CLI_IDS
      done <<EOF
$indexes
EOF
      [ "${#SELECTED_CLI_IDS[@]}" -gt 0 ] && return 0
    fi

    log_warn "Enter numbers, ranges, comma-separated values, or all."
  done
}

select_scope() {
  local answer

  echo ""
  log_section "Choose Scope"
  echo "  1) Global config symlinks"
  echo "  2) Project-local copies"
  echo ""

  while true; do
    read_prompt answer "Uninstall scope? [1]: "
    [ -n "$answer" ] || answer="1"
    case "$answer" in
      1|global)  SELECTED_SCOPE="global"; return 0 ;;
      2|project) SELECTED_SCOPE="project"; return 0 ;;
      *) log_warn "Enter 1 for global or 2 for project." ;;
    esac
  done
}

select_project_root() {
  local default_root answer resolved

  default_root="$(pwd -P)"
  echo ""
  log_section "Choose Project"
  echo "  Default: $default_root"
  echo ""

  while true; do
    read_prompt answer "Project path [current directory]: "
    [ -n "$answer" ] || answer="$default_root"

    if [ ! -d "$answer" ]; then
      log_warn "Directory does not exist: $answer"
      continue
    fi

    resolved="$(absolute_path "$answer")"
    echo "  Project: $resolved"
    if confirm "Use this project path? [y/N]: "; then
      PROJECT_ROOT="$resolved"
      return 0
    fi
  done
}

select_skills_to_remove() {
  local scope="$1"
  local root="$2"
  local answer indexes index
  local AVAIL_NAMES=()

  while IFS= read -r name; do
    AVAIL_NAMES+=("$name")
  done < <(list_installed_skills "$scope" "$root")

  if [ "${#AVAIL_NAMES[@]}" -eq 0 ]; then
    log_warn "No installed skills found for the selected CLIs and scope."
    return 0
  fi

  echo ""
  log_section "Choose Skills to Remove"
  index=1
  while [ "$index" -le "${#AVAIL_NAMES[@]}" ]; do
    printf '  %2s) %s\n' "$index" "${AVAIL_NAMES[$((index - 1))]}"
    index=$((index + 1))
  done
  echo ""
  echo "  Examples: all, 1, 2-4, 1,3"
  echo ""

  while true; do
    read_prompt answer "Remove which skills? [all]: "
    [ -n "$answer" ] || answer="all"
    SELECTED_SKILL_NAMES=()

    if indexes="$(expand_selection_tokens "$answer" "${#AVAIL_NAMES[@]}")"; then
      while IFS= read -r index; do
        [ -n "$index" ] || continue
        append_unique "${AVAIL_NAMES[$((index - 1))]}" SELECTED_SKILL_NAMES
      done <<EOF
$indexes
EOF
      [ "${#SELECTED_SKILL_NAMES[@]}" -gt 0 ] && return 0
    fi

    log_warn "Enter all, skill numbers, or ranges."
  done
}

select_commands_to_remove() {
  local scope="$1"
  local root="$2"
  local answer indexes index
  local AVAIL_NAMES=()

  while IFS= read -r name; do
    AVAIL_NAMES+=("$name")
  done < <(list_installed_commands "$scope" "$root")

  if [ "${#AVAIL_NAMES[@]}" -eq 0 ]; then
    log_warn "No installed slash commands found for the selected CLIs and scope."
    return 0
  fi

  echo ""
  log_section "Choose Slash Commands to Remove"
  index=1
  while [ "$index" -le "${#AVAIL_NAMES[@]}" ]; do
    printf '  %2s) /%s\n' "$index" "${AVAIL_NAMES[$((index - 1))]}"
    index=$((index + 1))
  done
  echo ""
  echo "  Examples: all, 1, 2-4, 1,3"
  echo ""

  while true; do
    read_prompt answer "Remove which slash commands? [all]: "
    [ -n "$answer" ] || answer="all"
    SELECTED_COMMAND_NAMES=()

    if indexes="$(expand_selection_tokens "$answer" "${#AVAIL_NAMES[@]}")"; then
      while IFS= read -r index; do
        [ -n "$index" ] || continue
        append_unique "${AVAIL_NAMES[$((index - 1))]}" SELECTED_COMMAND_NAMES
      done <<EOF
$indexes
EOF
      [ "${#SELECTED_COMMAND_NAMES[@]}" -gt 0 ] && return 0
    fi

    log_warn "Enter all, command numbers, or ranges."
  done
}

print_plan() {
  local scope="$1"
  local cli_id target

  echo ""
  log_section "Uninstall Plan"
  echo "  Scope:  $scope"
  [ "$scope" = "project" ] && echo "  Project: $PROJECT_ROOT"
  echo ""

  if [ "$UNINSTALL_SKILLS" -eq 1 ] && [ "${#SELECTED_SKILL_NAMES[@]}" -gt 0 ]; then
    echo "  Skill targets:"
    for cli_id in "${SELECTED_CLI_IDS[@]}"; do
      target="$(cli_target_dir "$cli_id" "$scope" "$PROJECT_ROOT")"
      echo "  - $cli_id -> $target"
    done
    echo ""
    echo "  Skills to remove:"
    for name in "${SELECTED_SKILL_NAMES[@]}"; do
      echo "  - $name"
    done
    echo ""
  fi

  if [ "$UNINSTALL_COMMANDS" -eq 1 ] && [ "${#SELECTED_COMMAND_NAMES[@]}" -gt 0 ]; then
    echo "  Slash command targets:"
    for cli_id in "${SELECTED_CLI_IDS[@]}"; do
      target="$(command_target_dir "$cli_id" "$scope" "$PROJECT_ROOT")"
      echo "  - $cli_id -> $target"
    done
    echo ""
    echo "  Commands to remove:"
    for name in "${SELECTED_COMMAND_NAMES[@]}"; do
      echo "  - /$name"
    done
    echo ""
  fi
}

# ── Removal logic ─────────────────────────────────────────────────────────────

remove_global_skill() {
  local cli_id="$1"
  local skill_name="$2"
  local target_dir target legacy_target

  target_dir="$(cli_target_dir "$cli_id" "global" "")"
  target="$target_dir/$skill_name"

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    # Check Gemini legacy path
    if [ "$cli_id" = "gemini" ]; then
      legacy_target="$GEMINI_LEGACY_SKILLS_DIR/$skill_name"
      if [ -L "$legacy_target" ]; then
        rm "$legacy_target"
        log_success "Removed $cli_id (legacy): $legacy_target"
        removed=$((removed + 1))
        return 0
      fi
    fi
    not_found=$((not_found + 1))
    return 0
  fi

  if [ ! -L "$target" ]; then
    log_warn "Skipping $target — not a symlink (manually managed)"
    skipped=$((skipped + 1))
    return 0
  fi

  rm "$target"
  removed=$((removed + 1))
  log_success "Removed $cli_id: $target"

  # Also clean Gemini legacy path if present
  if [ "$cli_id" = "gemini" ]; then
    legacy_target="$GEMINI_LEGACY_SKILLS_DIR/$skill_name"
    if [ -L "$legacy_target" ]; then
      rm "$legacy_target"
      log_success "Removed $cli_id (legacy): $legacy_target"
      removed=$((removed + 1))
    fi
  fi
}

remove_project_skill() {
  local cli_id="$1"
  local skill_name="$2"
  local target_dir target

  target_dir="$(cli_target_dir "$cli_id" "project" "$PROJECT_ROOT")"
  target="$target_dir/$skill_name"

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    not_found=$((not_found + 1))
    return 0
  fi

  if [ -L "$target" ]; then
    rm "$target"
    log_success "Removed $cli_id: $target"
    removed=$((removed + 1))
    return 0
  fi

  if [ ! -d "$target" ]; then
    log_warn "Skipping $target — unexpected type"
    skipped=$((skipped + 1))
    return 0
  fi

  if [ ! -f "$target/$MARKER_FILE" ]; then
    log_warn "Skipping $target — not installer-owned (no marker file)"
    skipped=$((skipped + 1))
    return 0
  fi

  rm -rf "$target"
  log_success "Removed $cli_id: $target"
  removed=$((removed + 1))
}

remove_global_command() {
  local cli_id="$1"
  local command_name="$2"
  local target_dir target marker_path

  target_dir="$(command_target_dir "$cli_id" "global" "")"
  case "$cli_id" in
    gemini) target="$target_dir/$command_name.toml" ;;
    *)      target="$target_dir/$command_name.md" ;;
  esac
  marker_path="${target%.*}$MARKER_FILE"

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    not_found=$((not_found + 1))
    return 0
  fi

  if [ -L "$target" ]; then
    rm "$target"
    log_success "Removed $cli_id command: $target"
    removed=$((removed + 1))
    return 0
  fi

  if [ -f "$marker_path" ]; then
    rm -f "$target" "$marker_path"
    log_success "Removed $cli_id command: $target"
    removed=$((removed + 1))
    return 0
  fi

  log_warn "Skipping $target — not a symlink or installer-owned file"
  skipped=$((skipped + 1))
}

remove_project_command() {
  local cli_id="$1"
  local command_name="$2"
  local target_dir target marker_path

  target_dir="$(command_target_dir "$cli_id" "project" "$PROJECT_ROOT")"
  case "$cli_id" in
    gemini) target="$target_dir/$command_name.toml" ;;
    *)      target="$target_dir/$command_name.md" ;;
  esac
  marker_path="${target%.*}$MARKER_FILE"

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    not_found=$((not_found + 1))
    return 0
  fi

  if [ -L "$target" ]; then
    rm "$target"
    rm -f "$marker_path"
    log_success "Removed $cli_id command: $target"
    removed=$((removed + 1))
    return 0
  fi

  if [ ! -f "$marker_path" ]; then
    log_warn "Skipping $target — not installer-owned (no marker file)"
    skipped=$((skipped + 1))
    return 0
  fi

  rm -f "$target" "$marker_path"
  log_success "Removed $cli_id command: $target"
  removed=$((removed + 1))
}

update_project_manifest() {
  local manifest_path="$PROJECT_ROOT/$PROJECT_MANIFEST"
  [ -f "$manifest_path" ] || return 0

  local cli_id target_dir has_items=0

  for cli_id in claude codex gemini; do
    target_dir="$(cli_target_dir "$cli_id" "project" "$PROJECT_ROOT")"
    if [ -d "$target_dir" ] && [ -n "$(ls -A "$target_dir" 2>/dev/null)" ]; then
      has_items=1
      break
    fi
    target_dir="$(command_target_dir "$cli_id" "project" "$PROJECT_ROOT")"
    if [ -d "$target_dir" ] && [ -n "$(ls -A "$target_dir" 2>/dev/null)" ]; then
      has_items=1
      break
    fi
  done

  if [ "$has_items" -eq 0 ]; then
    rm -f "$manifest_path"
    log_info "Removed project manifest (nothing left installed): $manifest_path"
  else
    log_info "Project manifest retained (other installed items remain): $manifest_path"
  fi
}

run_uninstall() {
  local scope="$1"
  local cli_id name

  if [ "$UNINSTALL_SKILLS" -eq 1 ]; then
    for name in "${SELECTED_SKILL_NAMES[@]:-}"; do
      [ -n "$name" ] || continue
      for cli_id in "${SELECTED_CLI_IDS[@]}"; do
        if [ "$scope" = "global" ]; then
          remove_global_skill "$cli_id" "$name"
        else
          remove_project_skill "$cli_id" "$name"
        fi
      done
    done
  fi

  if [ "$UNINSTALL_COMMANDS" -eq 1 ]; then
    for name in "${SELECTED_COMMAND_NAMES[@]:-}"; do
      [ -n "$name" ] || continue
      for cli_id in "${SELECTED_CLI_IDS[@]}"; do
        if [ "$scope" = "global" ]; then
          remove_global_command "$cli_id" "$name"
        else
          remove_project_command "$cli_id" "$name"
        fi
      done
    done
  fi

  [ "$scope" = "project" ] && update_project_manifest
}

main() {
  local scope

  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║      Agent Content Uninstaller       ║"
  echo "╚══════════════════════════════════════╝"
  echo ""
  echo "  Repo:     $REPO_ROOT"
  echo "  Skills:   $SKILLS_DIR"
  echo "  Commands: $COMMANDS_DIR"

  select_content
  select_clis
  select_scope
  scope="$SELECTED_SCOPE"
  [ "$scope" = "project" ] && select_project_root

  [ "$UNINSTALL_SKILLS"   -eq 1 ] && select_skills_to_remove   "$scope" "${PROJECT_ROOT:-}"
  [ "$UNINSTALL_COMMANDS" -eq 1 ] && select_commands_to_remove "$scope" "${PROJECT_ROOT:-}"

  if [ "${#SELECTED_SKILL_NAMES[@]}" -eq 0 ] && [ "${#SELECTED_COMMAND_NAMES[@]}" -eq 0 ]; then
    log_warn "Nothing selected for removal."
    exit 0
  fi

  print_plan "$scope"

  if ! confirm "Proceed with uninstall? [y/N]: "; then
    log_warn "Uninstall cancelled."
    exit 0
  fi

  echo ""
  run_uninstall "$scope"

  echo ""
  echo "────────────────────────────────────────"
  log_info "Done — $removed removed, $skipped skipped, $not_found not found"
  echo ""
}

main "$@"
