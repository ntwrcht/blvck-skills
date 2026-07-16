#!/usr/bin/env bash
# =============================================================================
# install-skills.sh — Interactive installer for shippable agent skills
#
# Copies selected skills into project-local CLI directories.
#
# Usage:
#   ./scripts/install-skills.sh
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

# --- Boxed prompt styling for this installer's interactive flow ---
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
      $'\x1b[A') cur=$(( (cur - 1 + count) % count )) ;;
      $'\x1b[B') cur=$(( (cur + 1) % count )) ;;
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
      $'\x1b[A') cur=$(( (cur - 1 + count) % count )) ;;
      $'\x1b[B') cur=$(( (cur + 1) % count )) ;;
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

INSTALLER_VERSION="1.0.0"
MARKER_FILE=".blvck-skills-install.json"
PROJECT_MANIFEST=".blvck-skills-install.json"
# Marker name used by installs made before the blvck-skills rename.
LEGACY_MARKER_FILE=".agent-skills-install.json"

CLI_NAMES=("Claude" "Codex" "Gemini")
CLI_IDS=("claude" "codex" "gemini")

SELECTED_CLI_IDS=()
SELECTED_SKILL_DIRS=()
SELECTED_SCENARIO=""
PROJECT_ROOT=""
PROJECT_TARGETS=()

created=0
replaced=0
skipped=0
shared_copied=0

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

absolute_path() {
  local path="$1"
  (cd "$path" 2>/dev/null && pwd -P)
}

read_prompt() {
  local var_name="$1"
  local prompt
  local prompt_answer
  shift
  prompt="$1"

  printf '%b' "$prompt" >&2
  if ! IFS= read -r prompt_answer; then
    echo "" >&2
    printf '  No input received; cancelling install.\n' >&2
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
        case "$start" in
          ""|*[!0-9]*) return 1 ;;
        esac
        case "$end" in
          ""|*[!0-9]*) return 1 ;;
        esac
        [ "$start" -le "$end" ] || return 1
        i="$start"
        while [ "$i" -le "$end" ]; do
          [ "$i" -ge 1 ] && [ "$i" -le "$max" ] || return 1
          printf '%s\n' "$i"
          i=$((i + 1))
        done
        ;;
      *)
        case "$token" in
          *[!0-9]*) return 1 ;;
        esac
        [ "$token" -ge 1 ] && [ "$token" -le "$max" ] || return 1
        printf '%s\n' "$token"
        ;;
    esac
  done
}

cli_target_dir() {
  local cli_id="$1"
  local root="$2"

  case "$cli_id" in
    claude) printf '%s\n' "$root/.claude/skills" ;;
    codex)  printf '%s\n' "$root/.codex/skills" ;;
    gemini) printf '%s\n' "$root/.gemini/extensions/$GEMINI_EXTENSION_NAME/skills" ;;
  esac
}

gemini_extension_dir() {
  local root="$1"
  printf '%s\n' "$root/.gemini/extensions/$GEMINI_EXTENSION_NAME"
}

write_gemini_extension_json() {
  local extension_dir="$1"

  mkdir -p "$extension_dir/skills"
  chmod 700 "$extension_dir" "$extension_dir/skills"
  cat > "$extension_dir/gemini-extension.json" <<JSON
{
  "name": "$GEMINI_EXTENSION_NAME",
  "version": "1.0.0",
  "description": "Local agent skills from blvck-skills."
}
JSON
}

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
  ui_line "${BOLD}1)${NC}  Claude"
  ui_line "${BOLD}2)${NC}  Codex"
  ui_line "${BOLD}3)${NC}  Gemini"
  ui_line "${BOLD}all)${NC} Claude, Codex, and Gemini"

  while true; do
    read_prompt answer "${CYAN}│${NC}  CLIs [1]: "
    [ -n "$answer" ] || answer="1"

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

load_skills() {
  SKILL_DIRS=()
  SKILL_NAMES=()
  SKILL_BUCKETS=()

  while IFS= read -r skill_dir; do
    skill_path="${skill_dir#$SKILLS_DIR/}"
    SKILL_DIRS+=("$skill_dir")
    SKILL_NAMES+=("$(skill_name_from_dir "$skill_dir")")
    SKILL_BUCKETS+=("${skill_path%%/*}")
  done < <(list_installable_skill_dirs)
}

select_skills() {
  local answer token bucket_token bucket_number bucket index indexes skill_name
  local bucket_names=("engineering" "productivity" "misc")
  local -a display
  local n

  load_skills

  if ui_tty_available; then
    display=()
    n=0
    while [ "$n" -lt "${#SKILL_NAMES[@]}" ]; do
      display+=("$(printf '%-32s [%s]' "${SKILL_NAMES[$n]}" "${SKILL_BUCKETS[$n]}")")
      n=$((n + 1))
    done
    ui_checkbox_select "Choose Skills" "${display[@]}"
    SELECTED_SKILL_DIRS=()
    if [ "${#UI_CHECK_RESULT[@]}" -gt 0 ]; then
      for index in "${UI_CHECK_RESULT[@]}"; do
        SELECTED_SKILL_DIRS+=("${SKILL_DIRS[$((index - 1))]}")
      done
    fi
    if [ "${#SELECTED_SKILL_DIRS[@]}" -eq 0 ]; then
      log_warn "No skills selected; cancelling."
      exit 0
    fi
    return 0
  fi

  ui_step "Choose Skills"
  ui_line "Bucket shortcuts:"
  index=1
  for bucket in "${bucket_names[@]}"; do
    ui_line "$(printf 'b%s) %s' "$index" "$bucket")"
    index=$((index + 1))
  done
  ui_line ""
  ui_line "Skills:"
  index=1
  while [ "$index" -le "${#SKILL_NAMES[@]}" ]; do
    ui_line "$(printf '%2s) %-32s [%s]' "$index" "${SKILL_NAMES[$((index - 1))]}" "${SKILL_BUCKETS[$((index - 1))]}")"
    index=$((index + 1))
  done
  ui_line ""
  ui_line "Examples: all, b1, b1,12,14-16"

  while true; do
    read_prompt answer "${CYAN}│${NC}  Install which skills? [all]: "
    [ -n "$answer" ] || answer="all"
    answer="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]' | tr ',' ' ')"
    SELECTED_SKILL_DIRS=()
    indexes=""

    if [ "$answer" = "all" ]; then
      indexes="$(expand_selection_tokens "all" "${#SKILL_NAMES[@]}")"
    else
      for token in $answer; do
        case "$token" in
          b[0-9]*)
            bucket_number="${token#b}"
            case "$bucket_number" in
              *[!0-9]*|"") indexes="__invalid__"; break ;;
            esac
            [ "$bucket_number" -ge 1 ] && [ "$bucket_number" -le "${#bucket_names[@]}" ] || {
              indexes="__invalid__"
              break
            }
            bucket="${bucket_names[$((bucket_number - 1))]}"
            index=1
            for skill_name in "${SKILL_NAMES[@]}"; do
              if [ "${SKILL_BUCKETS[$((index - 1))]}" = "$bucket" ]; then
                indexes="${indexes}${index}
"
              fi
              index=$((index + 1))
            done
            ;;
          *)
            if selected="$(expand_selection_tokens "$token" "${#SKILL_NAMES[@]}")"; then
              indexes="${indexes}${selected}
"
            else
              indexes="__invalid__"
              break
            fi
            ;;
        esac
      done
    fi

    if [ "$indexes" != "__invalid__" ]; then
      while IFS= read -r index; do
        [ -n "$index" ] || continue
        append_unique "${SKILL_DIRS[$((index - 1))]}" SELECTED_SKILL_DIRS
      done <<EOF
$indexes
EOF
      if [ "${#SELECTED_SKILL_DIRS[@]}" -gt 0 ]; then
        ui_answer "${#SELECTED_SKILL_DIRS[@]} skill(s) selected"
        return 0
      fi
    fi

    log_warn "Enter all, bucket shortcuts like b1, skill numbers, or ranges."
  done
}

print_plan() {
  local skill_dir

  ui_step "Plan"
  [ -n "$SELECTED_SCENARIO" ] && [ "$SELECTED_SCENARIO" != "custom" ] && \
    ui_line "$(printf "${GRAY}preset${NC}   %s" "$SELECTED_SCENARIO")"
  ui_line "$(printf "${GRAY}project${NC}  %s" "$PROJECT_ROOT")"
  ui_line "$(printf "${GRAY}cli${NC}      %s" "${SELECTED_CLI_IDS[*]}")"

  if [ "${#SELECTED_SKILL_DIRS[@]}" -gt 0 ]; then
    ui_line ""
    ui_line "$(printf "${BOLD}skills${NC}  (%s)" "${#SELECTED_SKILL_DIRS[@]}")"
    for skill_dir in "${SELECTED_SKILL_DIRS[@]}"; do
      ui_line "$(printf "${GRAY}·${NC}  %s" "$(skill_name_from_dir "$skill_dir")")"
    done
  fi
}

materialize_project_shared_refs() {
  local src_skill_dir="$1"
  local dest_skill_dir="$2"
  local skill_name shared_files filename src dest

  skill_name="$(skill_name_from_dir "$src_skill_dir")"
  shared_files="$(get_shared_refs "$skill_name")"
  [ -n "$shared_files" ] || return 0

  if [ ! -d "$SHARED_DIR" ]; then
    log_warn "_shared/references/ not found — skipping shared refs"
    return 0
  fi

  mkdir -p "$dest_skill_dir/references"

  for filename in $shared_files; do
    src="$SHARED_DIR/$filename"
    dest="$dest_skill_dir/references/$filename"

    if [ ! -f "$src" ]; then
      log_warn "Shared file not found, skipping: _shared/references/$filename"
      continue
    fi

    if [ -L "$dest" ] || [ -e "$dest" ]; then
      rm -f "$dest"
    fi

    cp "$src" "$dest"
    shared_copied=$((shared_copied + 1))
  done
}

write_skill_marker() {
  local marker_path="$1"
  local skill_name="$2"
  local cli_id="$3"
  local source_path="$4"
  local target_path="$5"
  local installed_at

  installed_at="$(timestamp_utc)"
  cat > "$marker_path" <<JSON
{
  "installer": "blvck-skills",
  "installer_version": "$INSTALLER_VERSION",
  "source_repo": "$(json_escape "$REPO_ROOT")",
  "source_skill": "$(json_escape "$source_path")",
  "skill": "$(json_escape "$skill_name")",
  "cli": "$(json_escape "$cli_id")",
  "scope": "project",
  "target": "$(json_escape "$target_path")",
  "installed_at": "$installed_at"
}
JSON
}

installer_owned_project_target() {
  local target="$1"
  [ -f "$target/$MARKER_FILE" ] || [ -f "$target/$LEGACY_MARKER_FILE" ]
}

install_project_skill() {
  local cli_id="$1"
  local skill_dir="$2"
  local target_dir target skill_name

  skill_name="$(skill_name_from_dir "$skill_dir")"
  target_dir="$(cli_target_dir "$cli_id" "$PROJECT_ROOT")"
  target="$target_dir/$skill_name"

  mkdir -p "$target_dir"

  if [ -L "$target" ]; then
    rm "$target"
    replaced=$((replaced + 1))
  elif [ -e "$target" ]; then
    if installer_owned_project_target "$target"; then
      if confirm "Replace existing installer-owned copy $target?"; then
        rm -rf "$target"
        replaced=$((replaced + 1))
      else
        log_warn "Skipping $target"
        skipped=$((skipped + 1))
        return 0
      fi
    else
      log_warn "Skipping $target — exists and is not installer-owned"
      skipped=$((skipped + 1))
      return 0
    fi
  fi

  cp -R "$skill_dir" "$target"
  materialize_project_shared_refs "$skill_dir" "$target"
  write_skill_marker "$target/$MARKER_FILE" "$skill_name" "$cli_id" "$skill_dir" "$target"
  created=$((created + 1))
  PROJECT_TARGETS+=("$cli_id|$skill_name|$target")
  log_success "Copied $cli_id: $target"
}

write_project_manifest() {
  local manifest_path="$PROJECT_ROOT/$PROJECT_MANIFEST"
  local installed_at target_count index cli_id item_name target comma

  installed_at="$(timestamp_utc)"
  target_count="${#PROJECT_TARGETS[@]}"

  {
    echo "{"
    echo "  \"installer\": \"blvck-skills\","
    echo "  \"installer_version\": \"$INSTALLER_VERSION\","
    echo "  \"source_repo\": \"$(json_escape "$REPO_ROOT")\","
    echo "  \"scope\": \"project\","
    echo "  \"project\": \"$(json_escape "$PROJECT_ROOT")\","
    echo "  \"installed_at\": \"$installed_at\","
    echo "  \"targets\": ["

    index=0
    for entry in "${PROJECT_TARGETS[@]}"; do
      cli_id="${entry%%|*}"
      item_name="${entry#*|}"
      item_name="${item_name%%|*}"
      target="${entry##*|}"
      comma=","
      [ "$index" -eq $((target_count - 1)) ] && comma=""
      echo "    {\"cli\": \"$(json_escape "$cli_id")\", \"type\": \"skill\", \"name\": \"$(json_escape "$item_name")\", \"target\": \"$(json_escape "$target")\"}$comma"
      index=$((index + 1))
    done

    echo "  ]"
    echo "}"
  } > "$manifest_path"
}

run_install() {
  local cli_id skill_dir extension_dir

  for cli_id in "${SELECTED_CLI_IDS[@]}"; do
    if [ "$cli_id" = "gemini" ]; then
      extension_dir="$(gemini_extension_dir "$PROJECT_ROOT")"
      write_gemini_extension_json "$extension_dir"
    fi
  done

  for cli_id in "${SELECTED_CLI_IDS[@]}"; do
    for skill_dir in "${SELECTED_SKILL_DIRS[@]}"; do
      install_project_skill "$cli_id" "$skill_dir"
    done
  done

  write_project_manifest
}

select_scenario() {
  local answer pm_label dev_label custom_label

  # Counted, not hardcoded: these labels drifted out of step with the bundles.
  pm_label="Project PM  — $(list_skills_for_preset project-pm | wc -l | tr -d ' ') productivity skills (PM / non-coder)"
  dev_label="Project Dev — $(list_skills_for_preset project-dev | wc -l | tr -d ' ') engineering essentials"
  custom_label="Custom      — pick from all available skills"

  if ui_tty_available; then
    ui_radio_select "Choose Scenario" "$pm_label" "$dev_label" "$custom_label"
    case "$UI_RADIO_INDEX" in
      1) SELECTED_SCENARIO="project-pm" ;;
      2) SELECTED_SCENARIO="project-dev" ;;
      3) SELECTED_SCENARIO="custom" ;;
    esac
    return 0
  fi

  ui_step "Choose Scenario"
  ui_line "${BOLD}1)${NC}  $pm_label"
  ui_line "${BOLD}2)${NC}  $dev_label"
  ui_line "${BOLD}3)${NC}  $custom_label"

  while true; do
    read_prompt answer "${CYAN}│${NC}  Scenario [1]: "
    [ -n "$answer" ] || answer="1"
    case "$answer" in
      1) SELECTED_SCENARIO="project-pm";  ui_answer "Project PM"; return 0 ;;
      2) SELECTED_SCENARIO="project-dev"; ui_answer "Project Dev"; return 0 ;;
      3) SELECTED_SCENARIO="custom";      ui_answer "Custom"; return 0 ;;
      *) log_warn "Enter 1–3." ;;
    esac
  done
}

populate_skills_from_preset() {
  local preset="$1" skill_dir
  load_skills
  SELECTED_SKILL_DIRS=()
  while IFS= read -r skill_dir; do
    SELECTED_SKILL_DIRS+=("$skill_dir")
  done < <(list_skills_for_preset "$preset")

  if [ "${#SELECTED_SKILL_DIRS[@]}" -eq 0 ]; then
    log_warn "No skills found for preset '$preset'."
    exit 0
  fi
}

main() {
  ui_intro "blvck-skills · install"
  ui_line "${GRAY}${REPO_ROOT}${NC}"

  select_scenario
  select_clis
  select_project_root

  if [ "$SELECTED_SCENARIO" = "custom" ]; then
    select_skills
  else
    populate_skills_from_preset "$SELECTED_SCENARIO"
  fi

  print_plan

  if ! confirm "Install?"; then
    ui_outro "Cancelled."
    exit 0
  fi

  ui_step "Installing"
  run_install

  ui_line "$(printf "${GREEN}✓${NC}  Done — %s installed, %s replaced, %s skipped" "$created" "$replaced" "$skipped")"
  ui_line "Shared refs copied — $shared_copied"
  ui_line "Manifest → $PROJECT_ROOT/$PROJECT_MANIFEST"

  ui_outro "All set."
}

main "$@"
