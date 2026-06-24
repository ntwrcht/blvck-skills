#!/usr/bin/env bash
# =============================================================================
# install-skills.sh — Interactive installer for shippable agent skills and commands
#
# Global installs symlink selected skills into CLI config directories.
# Project installs copy selected skills and commands into project-local CLI directories.
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

INSTALLER_VERSION="1.0.0"
MARKER_FILE=".agent-skills-install.json"
PROJECT_MANIFEST=".agent-skills-install.json"

CLI_NAMES=("Claude" "Codex" "Gemini")
CLI_IDS=("claude" "codex" "gemini")

SELECTED_CLI_IDS=()
SELECTED_SKILL_DIRS=()
SELECTED_COMMAND_DIRS=()
INSTALL_SKILLS=1
INSTALL_COMMANDS=0
SELECTED_SCOPE=""
SELECTED_SCENARIO=""
PROJECT_ROOT=""
PROJECT_TARGETS=()

created=0
replaced=0
skipped=0
shared_copied=0
shared_linked=0

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

  printf '%s' "$prompt" >&2
  if ! IFS= read -r prompt_answer; then
    echo "" >&2
    printf '  No input received; cancelling install.\n' >&2
    exit 0
  fi

  printf -v "$var_name" '%s' "$prompt_answer"
}

confirm() {
  local prompt="$1"
  local answer
  read_prompt answer "$prompt"
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

select_content() {
  local answer

  echo ""
  log_section "Choose Content"
  echo "  1) Skills"
  echo "  2) Slash commands"
  echo "  3) Both"
  echo ""

  while true; do
    read_prompt answer "Install what? [3]: "
    [ -n "$answer" ] || answer="3"
    case "$answer" in
      1|skills)
        INSTALL_SKILLS=1
        INSTALL_COMMANDS=0
        return 0
        ;;
      2|commands|slash|slash-commands)
        INSTALL_SKILLS=0
        INSTALL_COMMANDS=1
        return 0
        ;;
      3|both|all)
        INSTALL_SKILLS=1
        INSTALL_COMMANDS=1
        return 0
        ;;
      *) log_warn "Enter 1 for skills, 2 for commands, or 3 for both." ;;
    esac
  done
}

gemini_extension_dir_for_scope() {
  local scope="$1"
  local root="$2"

  if [ "$scope" = "global" ]; then
    printf '%s\n' "$GEMINI_EXTENSION_DIR"
  else
    printf '%s\n' "$root/.gemini/extensions/$GEMINI_EXTENSION_NAME"
  fi
}

write_gemini_extension_json() {
  local extension_dir="$1"

  mkdir -p "$extension_dir/skills"
  chmod 700 "$extension_dir" "$extension_dir/skills"
  cat > "$extension_dir/gemini-extension.json" <<JSON
{
  "name": "$GEMINI_EXTENSION_NAME",
  "version": "1.0.0",
  "description": "Local agent skills from agent-skills."
}
JSON
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
    read_prompt answer "Install for which CLIs? [all]: "
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
    read_prompt answer "Install scope? [1]: "
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

load_skills() {
  SKILL_DIRS=()
  SKILL_NAMES=()
  SKILL_BUCKETS=()

  while IFS= read -r skill_dir; do
    skill_path="${skill_dir#$SKILLS_DIR/}"
    SKILL_DIRS+=("$skill_dir")
    SKILL_NAMES+=("$(skill_name_from_dir "$skill_dir")")
    SKILL_BUCKETS+=("${skill_path%%/*}")
  done < <(list_shippable_skill_dirs)
}

load_commands() {
  COMMAND_DIRS=()
  COMMAND_NAMES=()
  COMMAND_BUCKETS=()

  while IFS= read -r command_dir; do
    command_path="${command_dir#$COMMANDS_DIR/}"
    COMMAND_DIRS+=("$command_dir")
    COMMAND_NAMES+=("$(command_name_from_dir "$command_dir")")
    COMMAND_BUCKETS+=("${command_path%%/*}")
  done < <(list_shippable_command_dirs)
}

select_skills() {
  local answer token bucket_token bucket_number bucket index indexes skill_name
  local bucket_names=("engineering" "productivity" "misc")

  load_skills

  echo ""
  log_section "Choose Skills"
  echo "  Bucket shortcuts:"
  index=1
  for bucket in "${bucket_names[@]}"; do
    printf '  b%s) %s\n' "$index" "$bucket"
    index=$((index + 1))
  done
  echo ""
  echo "  Skills:"
  index=1
  while [ "$index" -le "${#SKILL_NAMES[@]}" ]; do
    printf '  %2s) %-32s [%s]\n' "$index" "${SKILL_NAMES[$((index - 1))]}" "${SKILL_BUCKETS[$((index - 1))]}"
    index=$((index + 1))
  done
  echo ""
  echo "  Examples: all, b1, b1,12,14-16"
  echo ""

  while true; do
    read_prompt answer "Install which skills? [all]: "
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
      [ "${#SELECTED_SKILL_DIRS[@]}" -gt 0 ] && return 0
    fi

    log_warn "Enter all, bucket shortcuts like b1, skill numbers, or ranges."
  done
}

select_commands() {
  local answer token bucket_number bucket index indexes command_name
  local bucket_names=("engineering" "productivity" "misc")

  load_commands

  if [ "${#COMMAND_NAMES[@]}" -eq 0 ]; then
    log_warn "No shippable slash commands found."
    return 0
  fi

  echo ""
  log_section "Choose Slash Commands"
  echo "  Bucket shortcuts:"
  index=1
  for bucket in "${bucket_names[@]}"; do
    printf '  b%s) %s\n' "$index" "$bucket"
    index=$((index + 1))
  done
  echo ""
  echo "  Commands:"
  index=1
  while [ "$index" -le "${#COMMAND_NAMES[@]}" ]; do
    printf '  %2s) %-32s [%s]\n' "$index" "${COMMAND_NAMES[$((index - 1))]}" "${COMMAND_BUCKETS[$((index - 1))]}"
    index=$((index + 1))
  done
  echo ""
  echo "  Examples: all, b2, 1"
  echo ""

  while true; do
    read_prompt answer "Install which slash commands? [all]: "
    [ -n "$answer" ] || answer="all"
    answer="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]' | tr ',' ' ')"
    SELECTED_COMMAND_DIRS=()
    indexes=""

    if [ "$answer" = "all" ]; then
      indexes="$(expand_selection_tokens "all" "${#COMMAND_NAMES[@]}")"
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
            for command_name in "${COMMAND_NAMES[@]}"; do
              if [ "${COMMAND_BUCKETS[$((index - 1))]}" = "$bucket" ]; then
                indexes="${indexes}${index}
"
              fi
              index=$((index + 1))
            done
            ;;
          *)
            if selected="$(expand_selection_tokens "$token" "${#COMMAND_NAMES[@]}")"; then
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
        append_unique "${COMMAND_DIRS[$((index - 1))]}" SELECTED_COMMAND_DIRS
      done <<EOF
$indexes
EOF
      [ "${#SELECTED_COMMAND_DIRS[@]}" -gt 0 ] && return 0
    fi

    log_warn "Enter all, bucket shortcuts like b2, command numbers, or ranges."
  done
}

print_plan() {
  local scope="$1"
  local cli_id target skill_dir command_dir

  echo ""
  log_section "Install Plan"
  echo "  Scope:    $scope"
  [ -n "$SELECTED_SCENARIO" ] && [ "$SELECTED_SCENARIO" != "custom" ] && echo "  Preset:   $SELECTED_SCENARIO"
  [ "$scope" = "project" ] && echo "  Project:  $PROJECT_ROOT"
  echo ""

  if [ "$INSTALL_SKILLS" -eq 1 ]; then
    echo "  Skill targets:"
    for cli_id in "${SELECTED_CLI_IDS[@]}"; do
      target="$(cli_target_dir "$cli_id" "$scope" "$PROJECT_ROOT")"
      echo "  - $cli_id -> $target"
    done
    echo ""
    echo "  Skills:"
    for skill_dir in "${SELECTED_SKILL_DIRS[@]}"; do
      echo "  - $(skill_name_from_dir "$skill_dir")"
    done
    echo ""
  fi

  if [ "$INSTALL_COMMANDS" -eq 1 ]; then
    echo "  Slash command targets:"
    for cli_id in "${SELECTED_CLI_IDS[@]}"; do
      target="$(command_target_dir "$cli_id" "$scope" "$PROJECT_ROOT")"
      echo "  - $cli_id -> $target"
    done
    echo ""
    echo "  Slash commands:"
    for command_dir in "${SELECTED_COMMAND_DIRS[@]}"; do
      echo "  - /$(command_name_from_dir "$command_dir")"
    done
    echo ""
  fi
}

inject_global_shared_refs() {
  local skill_dir="$1"
  local skill_name shared_files filename src link

  skill_name="$(skill_name_from_dir "$skill_dir")"
  shared_files="$(get_shared_refs "$skill_name")"
  [ -n "$shared_files" ] || return 0

  if [ ! -d "$SHARED_DIR" ]; then
    log_warn "_shared/references/ not found — skipping shared refs"
    return 0
  fi

  mkdir -p "$skill_dir/references"

  for filename in $shared_files; do
    src="$SHARED_DIR/$filename"
    link="$skill_dir/references/$filename"

    if [ ! -f "$src" ]; then
      log_warn "Shared file not found, skipping: _shared/references/$filename"
      continue
    fi

    if [ -L "$link" ]; then
      rm "$link"
    elif [ -e "$link" ]; then
      log_warn "Skipping references/$filename — exists and is not a symlink"
      continue
    fi

    ln -s "$src" "$link"
    shared_linked=$((shared_linked + 1))
  done
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
  local scope="$4"
  local source_path="$5"
  local target_path="$6"
  local installed_at

  installed_at="$(timestamp_utc)"
  cat > "$marker_path" <<JSON
{
  "installer": "agent-skills",
  "installer_version": "$INSTALLER_VERSION",
  "source_repo": "$(json_escape "$REPO_ROOT")",
  "source_skill": "$(json_escape "$source_path")",
  "skill": "$(json_escape "$skill_name")",
  "cli": "$(json_escape "$cli_id")",
  "scope": "$scope",
  "target": "$(json_escape "$target_path")",
  "installed_at": "$installed_at"
}
JSON
}

extract_command_description() {
  local command_file="$1"

  awk '
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---" { exit }
    in_fm && $0 ~ /^description:[[:space:]]*/ {
      sub(/^description:[[:space:]]*/, "")
      gsub(/^"/, "")
      gsub(/"$/, "")
      print
      exit
    }
  ' "$command_file"
}

write_command_marker() {
  local marker_path="$1"
  local command_name="$2"
  local cli_id="$3"
  local scope="$4"
  local source_path="$5"
  local target_path="$6"
  local installed_at

  installed_at="$(timestamp_utc)"
  cat > "$marker_path" <<JSON
{
  "installer": "agent-skills",
  "installer_version": "$INSTALLER_VERSION",
  "source_repo": "$(json_escape "$REPO_ROOT")",
  "source_command": "$(json_escape "$source_path")",
  "command": "$(json_escape "$command_name")",
  "cli": "$(json_escape "$cli_id")",
  "scope": "$scope",
  "target": "$(json_escape "$target_path")",
  "installed_at": "$installed_at"
}
JSON
}

write_gemini_command_toml() {
  local command_file="$1"
  local target="$2"
  local description="$3"

  if grep -q "'''" "$command_file"; then
    log_warn "Skipping Gemini command with unsupported TOML literal delimiter: $command_file"
    skipped=$((skipped + 1))
    return 1
  fi

  {
    printf 'description = "%s"\n' "$(json_escape "$description")"
    printf "prompt = '''\n"
    awk '
      NR == 1 && $0 == "---" { in_fm = 1; next }
      in_fm && $0 == "---" { in_fm = 0; next }
      !in_fm { print }
    ' "$command_file"
    printf "\n'''\n"
  } > "$target"
}

install_global_skill() {
  local cli_id="$1"
  local skill_dir="$2"
  local target_dir target skill_name

  skill_name="$(skill_name_from_dir "$skill_dir")"
  target_dir="$(cli_target_dir "$cli_id" "global" "")"
  target="$target_dir/$skill_name"

  mkdir -p "$target_dir"
  chmod 700 "$target_dir"

  if [ -L "$target" ]; then
    rm "$target"
    replaced=$((replaced + 1))
  elif [ -e "$target" ]; then
    log_warn "Skipping $target — exists and is not a symlink"
    skipped=$((skipped + 1))
    return 0
  fi

  ln -s "$skill_dir" "$target"
  created=$((created + 1))
  inject_global_shared_refs "$skill_dir"
  log_success "Linked $cli_id: $target"
}

installer_owned_project_target() {
  local target="$1"
  [ -f "$target/$MARKER_FILE" ]
}

install_project_skill() {
  local cli_id="$1"
  local skill_dir="$2"
  local target_dir target skill_name

  skill_name="$(skill_name_from_dir "$skill_dir")"
  target_dir="$(cli_target_dir "$cli_id" "project" "$PROJECT_ROOT")"
  target="$target_dir/$skill_name"

  mkdir -p "$target_dir"

  if [ -L "$target" ]; then
    rm "$target"
    replaced=$((replaced + 1))
  elif [ -e "$target" ]; then
    if installer_owned_project_target "$target"; then
      if confirm "Replace existing installer-owned copy $target? [y/N]: "; then
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
  write_skill_marker "$target/$MARKER_FILE" "$skill_name" "$cli_id" "project" "$skill_dir" "$target"
  created=$((created + 1))
  PROJECT_TARGETS+=("$cli_id|$skill_name|$target")
  log_success "Copied $cli_id: $target"
}

install_global_command() {
  local cli_id="$1"
  local command_dir="$2"
  local command_name command_file target_dir target marker_path description

  command_name="$(command_name_from_dir "$command_dir")"
  command_file="$command_dir/command.md"
  target_dir="$(command_target_dir "$cli_id" "global" "")"
  target="$target_dir/$command_name"
  description="$(extract_command_description "$command_file")"
  [ -n "$description" ] || description="Run /$command_name."

  mkdir -p "$target_dir"
  chmod 700 "$target_dir"

  case "$cli_id" in
    gemini)
      target="$target.toml"
      marker_path="${target%.*}$MARKER_FILE"
      if [ -L "$target" ]; then
        rm "$target"
        replaced=$((replaced + 1))
      elif [ -e "$target" ] && [ -f "$marker_path" ]; then
        rm -f "$target" "$marker_path"
        replaced=$((replaced + 1))
      elif [ -e "$target" ]; then
        log_warn "Skipping $target — exists and is not a symlink"
        skipped=$((skipped + 1))
        return 0
      fi
      write_gemini_command_toml "$command_file" "$target" "$description" || return 0
      write_command_marker "$marker_path" "$command_name" "$cli_id" "global" "$command_file" "$target"
      ;;
    *)
      target="$target.md"
      if [ -L "$target" ]; then
        rm "$target"
        replaced=$((replaced + 1))
      elif [ -e "$target" ]; then
        log_warn "Skipping $target — exists and is not a symlink"
        skipped=$((skipped + 1))
        return 0
      fi
      ln -s "$command_file" "$target"
      ;;
  esac

  created=$((created + 1))
  log_success "Installed $cli_id command: $target"
}

project_command_target_owned() {
  local target="$1"
  local marker_path

  if [ -d "$target" ]; then
    [ -f "$target/$MARKER_FILE" ] && return 0
  fi

  marker_path="${target%.*}$MARKER_FILE"
  [ -f "$marker_path" ]
}

install_project_command() {
  local cli_id="$1"
  local command_dir="$2"
  local command_name command_file target_dir target marker_path description

  command_name="$(command_name_from_dir "$command_dir")"
  command_file="$command_dir/command.md"
  target_dir="$(command_target_dir "$cli_id" "project" "$PROJECT_ROOT")"
  target="$target_dir/$command_name"
  description="$(extract_command_description "$command_file")"
  [ -n "$description" ] || description="Run /$command_name."

  mkdir -p "$target_dir"

  case "$cli_id" in
    gemini) target="$target.toml" ;;
    *)      target="$target.md" ;;
  esac

  marker_path="${target%.*}$MARKER_FILE"

  if [ -L "$target" ]; then
    rm "$target"
    replaced=$((replaced + 1))
  elif [ -e "$target" ]; then
    if project_command_target_owned "$target"; then
      if confirm "Replace existing installer-owned command $target? [y/N]: "; then
        rm -f "$target" "$marker_path"
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

  if [ "$cli_id" = "gemini" ]; then
    write_gemini_command_toml "$command_file" "$target" "$description" || return 0
  else
    cp "$command_file" "$target"
  fi

  write_command_marker "$marker_path" "$command_name" "$cli_id" "project" "$command_file" "$target"
  created=$((created + 1))
  PROJECT_TARGETS+=("$cli_id|command:$command_name|$target")
  log_success "Copied $cli_id command: $target"
}

write_project_manifest() {
  local manifest_path="$PROJECT_ROOT/$PROJECT_MANIFEST"
  local installed_at target_count index cli_id item_name target comma item_type

  installed_at="$(timestamp_utc)"
  target_count="${#PROJECT_TARGETS[@]}"

  {
    echo "{"
    echo "  \"installer\": \"agent-skills\","
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
      item_type="skill"
      case "$item_name" in
        command:*)
          item_type="command"
          item_name="${item_name#command:}"
          ;;
      esac
      comma=","
      [ "$index" -eq $((target_count - 1)) ] && comma=""
      echo "    {\"cli\": \"$(json_escape "$cli_id")\", \"type\": \"$(json_escape "$item_type")\", \"name\": \"$(json_escape "$item_name")\", \"target\": \"$(json_escape "$target")\"}$comma"
      index=$((index + 1))
    done

    echo "  ]"
    echo "}"
  } > "$manifest_path"
}

run_install() {
  local scope="$1"
  local cli_id skill_dir command_dir extension_dir

  if [ "$INSTALL_SKILLS" -eq 1 ]; then
    for cli_id in "${SELECTED_CLI_IDS[@]}"; do
      if [ "$cli_id" = "gemini" ]; then
        extension_dir="$(gemini_extension_dir_for_scope "$scope" "$PROJECT_ROOT")"
        write_gemini_extension_json "$extension_dir"
      fi
    done

    for cli_id in "${SELECTED_CLI_IDS[@]}"; do
      for skill_dir in "${SELECTED_SKILL_DIRS[@]}"; do
        if [ "$scope" = "global" ]; then
          install_global_skill "$cli_id" "$skill_dir"
        else
          install_project_skill "$cli_id" "$skill_dir"
        fi
      done
    done
  fi

  if [ "$INSTALL_COMMANDS" -eq 1 ]; then
    for cli_id in "${SELECTED_CLI_IDS[@]}"; do
      for command_dir in "${SELECTED_COMMAND_DIRS[@]}"; do
        if [ "$scope" = "global" ]; then
          install_global_command "$cli_id" "$command_dir"
        else
          install_project_command "$cli_id" "$command_dir"
        fi
      done
    done
  fi

  if [ "$scope" = "project" ]; then
    write_project_manifest
  fi
}

select_scenario() {
  local answer index
  local names=(
    "Global — core skills, symlinked into every project"
    "Project — PM / non-coder workspace (productivity skills only)"
    "Project — Software development (all skills)"
    "Custom — choose scope and skills manually"
  )

  echo ""
  log_section "Choose Scenario"
  index=1
  while [ "$index" -le "${#names[@]}" ]; do
    printf '  %s) %s\n' "$index" "${names[$((index - 1))]}"
    index=$((index + 1))
  done
  echo ""

  while true; do
    read_prompt answer "Scenario? [1]: "
    [ -n "$answer" ] || answer="1"
    case "$answer" in
      1) SELECTED_SCENARIO="global";      SELECTED_SCOPE="global";  return 0 ;;
      2) SELECTED_SCENARIO="project-pm";  SELECTED_SCOPE="project"; return 0 ;;
      3) SELECTED_SCENARIO="project-dev"; SELECTED_SCOPE="project"; return 0 ;;
      4) SELECTED_SCENARIO="custom";                                  return 0 ;;
      *) log_warn "Enter 1-4." ;;
    esac
  done
}

select_skills_fzf() {
  local i=0 display_line selected_name fzf_output

  load_skills

  if [ "${#SKILL_NAMES[@]}" -eq 0 ]; then
    log_warn "No shippable skills found."
    return 0
  fi

  local display=()
  while [ "$i" -lt "${#SKILL_NAMES[@]}" ]; do
    display+=("$(printf '%-32s [%s]' "${SKILL_NAMES[$i]}" "${SKILL_BUCKETS[$i]}")")
    i=$((i + 1))
  done

  echo ""
  log_section "Choose Skills"
  echo ""

  fzf_output=$(printf '%s\n' "${display[@]}" | \
    fzf --multi \
        --header="Tab/Space=toggle  Ctrl-A=all  Ctrl-D=none  Enter=confirm" \
        --bind="ctrl-a:select-all,ctrl-d:deselect-all" \
        --height=60% \
        --layout=reverse \
        --prompt="Skills > " 2>/dev/null) || true

  if [ -z "$fzf_output" ]; then
    log_warn "No skills selected; cancelling."
    exit 0
  fi

  SELECTED_SKILL_DIRS=()
  while IFS= read -r display_line; do
    [ -z "$display_line" ] && continue
    selected_name="$(printf '%s' "$display_line" | awk '{print $1}')"
    i=0
    while [ "$i" -lt "${#SKILL_NAMES[@]}" ]; do
      if [ "${SKILL_NAMES[$i]}" = "$selected_name" ]; then
        append_unique "${SKILL_DIRS[$i]}" SELECTED_SKILL_DIRS
        break
      fi
      i=$((i + 1))
    done
  done <<< "$fzf_output"

  [ "${#SELECTED_SKILL_DIRS[@]}" -gt 0 ] && return 0
  log_warn "No skills selected; cancelling."
  exit 0
}

select_commands_fzf() {
  local i=0 display_line selected_name fzf_output

  load_commands

  if [ "${#COMMAND_NAMES[@]}" -eq 0 ]; then
    log_warn "No shippable slash commands found."
    return 0
  fi

  local display=()
  while [ "$i" -lt "${#COMMAND_NAMES[@]}" ]; do
    display+=("$(printf '%-32s [%s]' "${COMMAND_NAMES[$i]}" "${COMMAND_BUCKETS[$i]}")")
    i=$((i + 1))
  done

  echo ""
  log_section "Choose Slash Commands"
  echo ""

  fzf_output=$(printf '%s\n' "${display[@]}" | \
    fzf --multi \
        --header="Tab/Space=toggle  Ctrl-A=all  Ctrl-D=none  Enter=confirm" \
        --bind="ctrl-a:select-all,ctrl-d:deselect-all" \
        --height=60% \
        --layout=reverse \
        --prompt="Commands > " 2>/dev/null) || true

  if [ -z "$fzf_output" ]; then
    log_warn "No commands selected; cancelling."
    exit 0
  fi

  SELECTED_COMMAND_DIRS=()
  while IFS= read -r display_line; do
    [ -z "$display_line" ] && continue
    selected_name="$(printf '%s' "$display_line" | awk '{print $1}')"
    i=0
    while [ "$i" -lt "${#COMMAND_NAMES[@]}" ]; do
      if [ "${COMMAND_NAMES[$i]}" = "$selected_name" ]; then
        append_unique "${COMMAND_DIRS[$i]}" SELECTED_COMMAND_DIRS
        break
      fi
      i=$((i + 1))
    done
  done <<< "$fzf_output"

  [ "${#SELECTED_COMMAND_DIRS[@]}" -gt 0 ] && return 0
  log_warn "No commands selected; cancelling."
  exit 0
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

  log_info "Preset '$preset' — ${#SELECTED_SKILL_DIRS[@]} skill(s) selected."
}

populate_commands_from_preset() {
  load_commands
  SELECTED_COMMAND_DIRS=("${COMMAND_DIRS[@]:-}")
}

main() {
  local scope

  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║        Agent Content Installer       ║"
  echo "╚══════════════════════════════════════╝"
  echo ""
  echo "  Repo:     $REPO_ROOT"
  echo "  Skills:   $SKILLS_DIR"
  echo "  Commands: $COMMANDS_DIR"
  [ "$FZF_AVAILABLE" -eq 1 ] && log_info "fzf detected — checkbox selection available in custom mode"

  select_content
  select_clis
  select_scenario

  [ "$SELECTED_SCENARIO" = "custom" ] && select_scope
  scope="$SELECTED_SCOPE"
  [ "$scope" = "project" ] && select_project_root

  if [ "$SELECTED_SCENARIO" = "custom" ]; then
    if [ "$INSTALL_SKILLS" -eq 1 ]; then
      if [ "$FZF_AVAILABLE" -eq 1 ]; then
        select_skills_fzf
      else
        select_skills
      fi
    fi
    if [ "$INSTALL_COMMANDS" -eq 1 ]; then
      if [ "$FZF_AVAILABLE" -eq 1 ]; then
        select_commands_fzf
      else
        select_commands
      fi
    fi
  else
    [ "$INSTALL_SKILLS"   -eq 1 ] && populate_skills_from_preset "$SELECTED_SCENARIO"
    [ "$INSTALL_COMMANDS" -eq 1 ] && populate_commands_from_preset
  fi

  print_plan "$scope"

  if ! confirm "Proceed with install? [y/N]: "; then
    log_warn "Install cancelled."
    exit 0
  fi

  echo ""
  run_install "$scope"

  echo ""
  echo "────────────────────────────────────────"
  log_info "Done — $created installed, $replaced replaced, $skipped skipped"
  [ "$scope" = "global" ] && [ "$INSTALL_SKILLS" -eq 1 ] && log_info "Shared refs linked — $shared_linked"
  [ "$scope" = "project" ] && [ "$INSTALL_SKILLS" -eq 1 ] && log_info "Shared refs copied — $shared_copied"
  [ "$scope" = "project" ] && log_info "Manifest: $PROJECT_ROOT/$PROJECT_MANIFEST"
  echo ""
}

main "$@"
