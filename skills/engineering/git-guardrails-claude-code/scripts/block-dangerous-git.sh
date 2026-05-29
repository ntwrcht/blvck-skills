#!/usr/bin/env bash
set -euo pipefail

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  command_text=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
else
  echo "BLOCKED: Cannot inspect command because jq is not installed." >&2
  exit 2
fi

dangerous_patterns=(
  '(^|[;&|[:space:]])git[[:space:]]+push([[:space:]]|$)'
  '(^|[;&|[:space:]])git[[:space:]]+reset[[:space:]]+--hard([[:space:]]|$)'
  '(^|[;&|[:space:]])git[[:space:]]+clean[[:space:]]+-[[:alnum:]]*f[[:alnum:]]*([[:space:]]|$)'
  '(^|[;&|[:space:]])git[[:space:]]+branch[[:space:]]+-D([[:space:]]|$)'
  '(^|[;&|[:space:]])git[[:space:]]+checkout[[:space:]]+\.(\/)?([[:space:]]|$)'
  '(^|[;&|[:space:]])git[[:space:]]+restore[[:space:]]+\.(\/)?([[:space:]]|$)'
  '(^|[;&|[:space:]])git[[:space:]]+[^;&|]*--force([^[:alnum:]_-]|$)'
)

for pattern in "${dangerous_patterns[@]}"; do
  if printf '%s' "$command_text" | grep -Eq "$pattern"; then
    echo "BLOCKED: '$command_text' matches dangerous pattern '$pattern'. The user has prevented you from doing this." >&2
    exit 2
  fi
done

exit 0
