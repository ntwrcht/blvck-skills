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

read_prompt() {
  local var_name="$1" prompt prompt_answer
  shift
  prompt="$1"
  printf '%b' "$prompt" >&2
  if ! IFS= read -r prompt_answer; then
    echo "" >&2
    exit 0
  fi
  printf -v "$var_name" '%s' "$prompt_answer"
}

printf "\n${CYAN}┌${NC}  ${BOLD}blvck-skills${NC}\n${CYAN}│${NC}\n"
printf "${CYAN}│${NC}  ${GRAY}%s${NC}\n" "$REPO_ROOT"
printf "${CYAN}│${NC}\n${CYAN}◇${NC}  ${BOLD}Choose Action${NC}\n"

if ui_tty_available; then
  options=("Install" "Uninstall")
  cur=0
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
      $'\x1b[A') cur=$(( (cur - 1 + 2) % 2 )) ;;
      $'\x1b[B') cur=$(( (cur + 1) % 2 )) ;;
      "") break ;;
    esac
    tput cuu 2 2>/dev/null
  done
  tput cnorm 2>/dev/null
  stty sane < /dev/tty 2>/dev/null
  printf "${CYAN}│${NC}  ${GRAY}→${NC}  %s\n" "${options[$cur]}"
  case "$cur" in
    0) exec "$script_dir/install-skills.sh" ;;
    1) exec "$script_dir/uninstall-skills.sh" ;;
  esac
fi

printf "${CYAN}│${NC}  ${BOLD}1)${NC}  Install\n"
printf "${CYAN}│${NC}  ${BOLD}2)${NC}  Uninstall\n"

while true; do
  read_prompt answer "${CYAN}│${NC}  Action [1]: "
  [ -n "$answer" ] || answer="1"
  case "$answer" in
    1|install)   exec "$script_dir/install-skills.sh" ;;
    2|uninstall) exec "$script_dir/uninstall-skills.sh" ;;
    *) printf "${CYAN}│${NC}  ${YELLOW}⚠${NC}  Enter 1 or 2.\n" ;;
  esac
done
