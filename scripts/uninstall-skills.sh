#!/usr/bin/env bash
# =============================================================================
# uninstall-skills.sh — Interactive uninstaller for agent skills
#
# Removes copies from project-local CLI directories.
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

# --- Boxed prompt styling for this uninstaller's interactive flow ---
ui_intro() {
  printf "\n${CYAN}┌${NC}  ${BOLD}%s${NC}\n${CYAN}│${NC}\n" "$1"
}

ui_step() {
  printf "${CYAN}│${NC}\n${CYAN}◇${NC}  ${BOLD}%s${NC}\n" "$1"
}

ui_line() {
  printf "${CYAN}│${NC}  %b\n" "$1"
}

ui_answer() {
  printf "${CYAN}│${NC}  ${GRAY}→${NC}  %b\n" "$1"
}

ui_outro() {
  printf "${CYAN}│${NC}\n${CYAN}└${NC}  %s\n\n" "$1"
}

# Always leave the terminal in a sane state, even on Ctrl-C or a mid-menu error.
trap 'stty sane < /dev/tty 2>/dev/null; tput cnorm 2>/dev/null' EXIT

ui_tty_available() {
  { : < /dev/tty; } 2>/dev/null
}

ui_read_key() {
  local key rest
  IFS= read -rsn1 key < /dev/tty
  if [ "$key" = "$(printf '\033')" ]; then
    IFS= read -rsn2 -t 1 rest < /dev/tty 2>/dev/null || rest=""
    key="${key}${rest}"
  fi
  printf '%s' "$key"
}

# Radio-button style single-select. Usage: ui_radio_select "Title" "opt 1" "opt 2" ...
# Sets UI_RADIO_INDEX (1-based) to the chosen option.
ui_radio_select() {
  local title="$1"
  shift
  local -a options
  options=("$@")
  local count="${#options[@]}"
  local cur=0 i key opt

  ui_step "$title"
  printf "${CYAN}│${NC}  ${GRAY}↑/↓ move · enter confirm${NC}\n"

  stty -echo -icanon time 0 min 1 < /dev/tty 2>/dev/null
  tput civis 2>/dev/null

  while true; do
    i=0
    for opt in "${options[@]}"; do
      if [ "$i" -eq "$cur" ]; then
        printf "${CYAN}│${NC}  ${CYAN}●${NC}  ${BOLD}%s${NC}\n" "$opt"
      else
        printf "${CYAN}│${NC}  ${GRAY}○${NC}  %s\n" "$opt"
      fi
      i=$((i + 1))
    done

    key="$(ui_read_key)"
    case "$key" in
      $'\x1b'"[A") cur=$(( (cur - 1 + count) % count )) ;;
      $'\x1b'"[B") cur=$(( (cur + 1) % count )) ;;
      "") break ;;
    esac
    tput cuu "$count" 2>/dev/null
  done

  tput cnorm 2>/dev/null
  stty sane < /dev/tty 2>/dev/null

  UI_RADIO_INDEX=$((cur + 1))
  ui_answer "${options[$cur]}"
}

# Checkbox style multi-select. Usage: ui_checkbox_select "Title" "opt 1" "opt 2" ...
# Sets UI_CHECK_RESULT (array of 1-based indices) to the chosen options.
ui_checkbox_select() {
  local title="$1"
  shift
  local -a options
  options=("$@")
  local count="${#options[@]}"
  local cur=0 i key opt box any_unchecked
  local -a checked
  i=0
  while [ "$i" -lt "$count" ]; do
    checked[$i]=0
    i=$((i + 1))
  done

  ui_step "$title"
  printf "${CYAN}│${NC}  ${GRAY}↑/↓ move · space toggle · a select all · enter confirm${NC}\n"

  stty -echo -icanon time 0 min 1 < /dev/tty 2>/dev/null
  tput civis 2>/dev/null

  while true; do
    i=0
    for opt in "${options[@]}"; do
      if [ "${checked[$i]}" -eq 1 ]; then
        box="${CYAN}◼${NC}"
      else
        box="${GRAY}◻${NC}"
      fi
      if [ "$i" -eq "$cur" ]; then
        printf "${CYAN}│${NC}  %b  ${BOLD}%s${NC}\n" "$box" "$opt"
      else
        printf "${CYAN}│${NC}  %b  %s\n" "$box" "$opt"
      fi
      i=$((i + 1))
    done

    key="$(ui_read_key)"
    case "$key" in
      $'\x1b'"[A") cur=$(( (cur - 1 + count) % count )) ;;
      $'\x1b'"[B") cur=$(( (cur + 1) % count )) ;;
      " ")
        if [ "${checked[$cur]}" -eq 1 ]; then
          checked[$cur]=0
        else
          checked[$cur]=1
        fi
        ;;
      a|A)
        any_unchecked=0
        i=0
        while [ "$i" -lt "$count" ]; do
          [ "${checked[$i]}" -eq 0 ] && any_unchecked=1
          i=$((i + 1))
        done
        i=0
        while [ "$i" -lt "$count" ]; do
          checked[$i]=$any_unchecked
          i=$((i + 1))
        done
        ;;
      "") break ;;
    esac
    tput cuu "$count" 2>/dev/null
  done

  tput cnorm 2>/dev/null
  stty sane < /dev/tty 2>/dev/null

  UI_CHECK_RESULT=()
  i=0
  for opt in "${options[@]}"; do
    [ "${checked[$i]}" -eq 1 ] && UI_CHECK_RESULT+=("$((i + 1))")
    i=$((i + 1))
  done

  if [ "${#UI_CHECK_RESULT[@]}" -eq 0 ]; then
    ui_answer "none selected"
  else
    ui_answer "${#UI_CHECK_RESULT[@]} selected"
  fi
}

MARKER_FILE=".blvck-skills-install.json"
PROJECT_MANIFEST=".blvck-skills-install.json"
# Marker name used by installs made before the blvck-skills rename.
LEGACY_MARKER_FILE=".agent-skills-install.json"
LEGACY_PROJECT_MANIFEST=".agent-skills-install.json"

CLI_NAMES=("Claude" "Codex" "Gemini")
CLI_IDS=("claude" "codex" "gemini")

SELECTED_CLI_IDS=()
PROJECT_ROOT=""
SELECTED_SKILL_NAMES=()

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
  printf '%b' "$prompt" >&2
  if ! IFS= read -r prompt_answer; then
    echo "" >&2
    printf '  No input received; cancelling uninstall.\n' >&2
    exit 0
  fi
  printf -v "$var_name" '%s' "$prompt_answer"
}

confirm() {
  local title="$1"
  local answer

  if ui_tty_available; then
    ui_radio_select "$title" "Yes" "No"
    [ "$UI_RADIO_INDEX" -eq 1 ]
    return
  fi

  read_prompt answer "${CYAN}│${NC}  ${title} [y/N]: "
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
  local root="$2"

  case "$cli_id" in
    claude) printf '%s\n' "$root/.claude/skills" ;;
    codex)  printf '%s\n' "$root/.codex/skills" ;;
    gemini) printf '%s\n' "$root/.gemini/extensions/$GEMINI_EXTENSION_NAME/skills" ;;
  esac
}

# ── Discover installed items ──────────────────────────────────────────────────

list_installed_skills() {
  local root="$1"
  local cli_id target_dir skill_path skill_name
  local seen=()

  for cli_id in "${SELECTED_CLI_IDS[@]}"; do
    target_dir="$(cli_target_dir "$cli_id" "$root")"
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

# ── UI steps ──────────────────────────────────────────────────────────────────

select_clis() {
  local answer index

  if ui_tty_available; then
    ui_checkbox_select "Choose CLIs" "Claude" "Codex" "Gemini"
    SELECTED_CLI_IDS=()
    if [ "${#UI_CHECK_RESULT[@]}" -gt 0 ]; then
      for index in "${UI_CHECK_RESULT[@]}"; do
        append_unique "${CLI_IDS[$((index - 1))]}" SELECTED_CLI_IDS
      done
    fi
    if [ "${#SELECTED_CLI_IDS[@]}" -eq 0 ]; then
      SELECTED_CLI_IDS=("claude")
    fi
    return 0
  fi

  ui_step "Choose CLIs"
  index=1
  while [ "$index" -le "${#CLI_NAMES[@]}" ]; do
    ui_line "$(printf '%s) %s' "$index" "${CLI_NAMES[$((index - 1))]}")"
    index=$((index + 1))
  done
  ui_line "all) Claude, Codex, and Gemini"

  while true; do
    read_prompt answer "${CYAN}│${NC}  Uninstall for which CLIs? [all]: "
    [ -n "$answer" ] || answer="all"

    SELECTED_CLI_IDS=()
    if indexes="$(expand_selection_tokens "$answer" "${#CLI_NAMES[@]}")"; then
      while IFS= read -r index; do
        [ -n "$index" ] || continue
        append_unique "${CLI_IDS[$((index - 1))]}" SELECTED_CLI_IDS
      done <<EOF
$indexes
EOF
      if [ "${#SELECTED_CLI_IDS[@]}" -gt 0 ]; then
        ui_answer "${SELECTED_CLI_IDS[*]}"
        return 0
      fi
    fi

    log_warn "Enter numbers, ranges, comma-separated values, or all."
  done
}

select_project_root() {
  local default_root answer

  default_root="$(pwd -P)"
  ui_step "Project Path"

  while true; do
    read_prompt answer "${CYAN}│${NC}  Path [${default_root}]: "
    [ -n "$answer" ] || answer="$default_root"

    if [ -d "$answer" ]; then
      PROJECT_ROOT="$(absolute_path "$answer")"
      ui_answer "$PROJECT_ROOT"
      return 0
    fi

    log_warn "Directory not found: $answer"
  done
}

select_skills_to_remove() {
  local root="$1"
  local answer indexes index
  local AVAIL_NAMES=()

  while IFS= read -r name; do
    AVAIL_NAMES+=("$name")
  done < <(list_installed_skills "$root")

  if [ "${#AVAIL_NAMES[@]}" -eq 0 ]; then
    log_warn "No installed skills found for the selected CLIs in this project."
    return 0
  fi

  if ui_tty_available; then
    ui_checkbox_select "Choose Skills to Remove" "${AVAIL_NAMES[@]}"
    SELECTED_SKILL_NAMES=()
    if [ "${#UI_CHECK_RESULT[@]}" -gt 0 ]; then
      for index in "${UI_CHECK_RESULT[@]}"; do
        SELECTED_SKILL_NAMES+=("${AVAIL_NAMES[$((index - 1))]}")
      done
    fi
    return 0
  fi

  ui_step "Choose Skills to Remove"
  index=1
  while [ "$index" -le "${#AVAIL_NAMES[@]}" ]; do
    ui_line "$(printf '%2s) %s' "$index" "${AVAIL_NAMES[$((index - 1))]}")"
    index=$((index + 1))
  done
  ui_line ""
  ui_line "Examples: all, 1, 2-4, 1,3"

  while true; do
    read_prompt answer "${CYAN}│${NC}  Remove which skills? [all]: "
    [ -n "$answer" ] || answer="all"
    SELECTED_SKILL_NAMES=()

    if indexes="$(expand_selection_tokens "$answer" "${#AVAIL_NAMES[@]}")"; then
      while IFS= read -r index; do
        [ -n "$index" ] || continue
        append_unique "${AVAIL_NAMES[$((index - 1))]}" SELECTED_SKILL_NAMES
      done <<EOF
$indexes
EOF
      if [ "${#SELECTED_SKILL_NAMES[@]}" -gt 0 ]; then
        ui_answer "${#SELECTED_SKILL_NAMES[@]} skill(s) selected"
        return 0
      fi
    fi

    log_warn "Enter all, skill numbers, or ranges."
  done
}

print_plan() {
  local name

  ui_step "Plan"
  ui_line "$(printf "${GRAY}project${NC} %s" "$PROJECT_ROOT")"

  if [ "${#SELECTED_SKILL_NAMES[@]}" -gt 0 ]; then
    ui_line ""
    ui_line "$(printf "${BOLD}skills${NC}  (%s)" "${#SELECTED_SKILL_NAMES[@]}")"
    for name in "${SELECTED_SKILL_NAMES[@]}"; do
      ui_line "$(printf "${GRAY}·${NC}  %s" "$name")"
    done
  fi
}

# ── Removal logic ─────────────────────────────────────────────────────────────

remove_project_skill() {
  local cli_id="$1"
  local skill_name="$2"
  local target_dir target

  target_dir="$(cli_target_dir "$cli_id" "$PROJECT_ROOT")"
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

  if [ ! -f "$target/$MARKER_FILE" ] && [ ! -f "$target/$LEGACY_MARKER_FILE" ]; then
    log_warn "Skipping $target — not installer-owned (no marker file)"
    skipped=$((skipped + 1))
    return 0
  fi

  rm -rf "$target"
  log_success "Removed $cli_id: $target"
  removed=$((removed + 1))
}

update_project_manifest() {
  local manifest_path="$PROJECT_ROOT/$PROJECT_MANIFEST"
  local legacy_manifest_path="$PROJECT_ROOT/$LEGACY_PROJECT_MANIFEST"
  [ -f "$manifest_path" ] || [ -f "$legacy_manifest_path" ] || return 0

  local cli_id target_dir has_items=0

  for cli_id in claude codex gemini; do
    target_dir="$(cli_target_dir "$cli_id" "$PROJECT_ROOT")"
    if [ -d "$target_dir" ] && [ -n "$(ls -A "$target_dir" 2>/dev/null)" ]; then
      has_items=1
      break
    fi
  done

  if [ "$has_items" -eq 0 ]; then
    rm -f "$manifest_path" "$legacy_manifest_path"
    log_info "Removed project manifest (nothing left installed): $manifest_path"
  else
    log_info "Project manifest retained (other installed items remain): $manifest_path"
  fi
}

run_uninstall() {
  local cli_id name

  for name in "${SELECTED_SKILL_NAMES[@]:-}"; do
    [ -n "$name" ] || continue
    for cli_id in "${SELECTED_CLI_IDS[@]}"; do
      remove_project_skill "$cli_id" "$name"
    done
  done

  update_project_manifest
}

main() {
  ui_intro "blvck-skills · uninstall"
  ui_line "${GRAY}${REPO_ROOT}${NC}"

  # Default: all CLIs
  SELECTED_CLI_IDS=("claude" "codex" "gemini")

  select_project_root

  select_skills_to_remove "$PROJECT_ROOT"

  if [ "${#SELECTED_SKILL_NAMES[@]}" -eq 0 ]; then
    log_warn "Nothing selected for removal."
    exit 0
  fi

  print_plan

  if ! confirm "Remove?"; then
    ui_outro "Cancelled."
    exit 0
  fi

  run_uninstall

  ui_line "$(printf "${GREEN}✓${NC}  Done — %s removed, %s skipped, %s not found" "$removed" "$skipped" "$not_found")"
  ui_outro "All set."
}

main "$@"
