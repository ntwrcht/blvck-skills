#!/usr/bin/env bash
# Checks one skill folder against the Agent Skills spec and the portability rule.
# Usage: bash scripts/check-skill.sh <skill-dir>
#
# For projects with no validator of their own. Checks: `name` matches the folder
# and the spec's format; `description` exists, is at most 1,024 characters, and
# holds no XML tags; the body is under 500 lines; every bundled path SKILL.md
# names exists inside the folder, and none reaches outside it.
#
# Exit: 0 every check passed · 1 a check failed · 2 usage error

set -euo pipefail

[ $# -eq 1 ] || { sed -n '2,3p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
DIR="$(cd "$1" && pwd)"
SKILL="$DIR/SKILL.md"
[ -f "$SKILL" ] || { echo "FAIL  no SKILL.md in $DIR"; exit 1; }

failed=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; failed=1; }

frontmatter() { awk 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {exit} f' "$SKILL"; }
body()        { awk 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {f=0; next} !f' "$SKILL"; }

# Reads a top-level scalar, including a folded (>) or literal (|) block.
field() {
  frontmatter | awk -v key="$1" '
    $0 ~ "^" key ":" {
      v = $0; sub("^" key ":[[:space:]]*", "", v)
      if (v ~ /^[>|][-+]?$/) { block = 1; v = ""; found = 1; next }
      print v; exit
    }
    block && /^[[:space:]]/ { sub(/^[[:space:]]+/, ""); v = (v == "" ? $0 : v " " $0); next }
    block { print v; exit }
    END { if (block) print v }'
}
unquote() { sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"; }

head -1 "$SKILL" | grep -qx -- '---' || fail "SKILL.md opens with a --- frontmatter block"

# ── name ─────────────────────────────────────────────────────────────────────

name="$(field name | unquote)"
folder="$(basename "$DIR")"
if [ -z "$name" ]; then
  fail "name is present"
else
  [ "$name" = "$folder" ] && pass "name '$name' matches the folder" || fail "name '$name' matches the folder '$folder'"
  if printf '%s' "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' && [ "${#name}" -le 64 ]; then
    pass "name is 1-64 lowercase letters, digits, and single hyphens"
  else
    fail "name is 1-64 lowercase letters, digits, and single hyphens"
  fi
  case "$name" in
    *anthropic*|*claude*) fail "name avoids the reserved words 'anthropic' and 'claude'" ;;
  esac
fi

# ── description ──────────────────────────────────────────────────────────────

desc="$(field description | unquote)"
if [ -z "$desc" ]; then
  fail "description is present"
else
  len="$(printf '%s' "$desc" | wc -m | tr -d ' ')"
  [ "$len" -le 1024 ] && pass "description is $len characters (limit 1,024)" \
                      || fail "description is $len characters (limit 1,024)"
  printf '%s' "$desc" | grep -Eq '<[A-Za-z/][^>]*>' \
    && fail "description holds no XML tags" || pass "description holds no XML tags"
fi

# ── body length ──────────────────────────────────────────────────────────────

lines="$(body | wc -l | tr -d ' ')"
[ "$lines" -lt 500 ] && pass "body is $lines lines (limit 500)" || fail "body is $lines lines (limit 500)"

# ── bundled paths ────────────────────────────────────────────────────────────

# Backticked references/ and scripts/ paths, plus markdown link targets. An assets/
# path often names what the skill writes, and <placeholders> and URLs are not references.
paths="$(
  {
    body | grep -oE '`(references|scripts)/[^`[:space:]]+`' | tr -d '`' || true
    body | grep -oE '\]\([^)]+\)' | sed 's/^](//; s/)$//' || true
  } | { grep -v '[<>]' || true; } | { grep -vE '^(https?:|mailto:|#)' || true; } | sort -u
)"
missing=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  p="${p#./}"; p="${p%%#*}"
  [ -e "$DIR/$p" ] || { fail "bundled path '$p' exists in the skill folder"; missing=1; }
done <<< "$paths"
[ "$missing" -eq 1 ] || pass "every bundled path SKILL.md names exists in the folder"

# A ../ path anywhere, or an absolute path as a link target. A backticked absolute
# path such as /tmp/out.md names a runtime location, not a bundled file.
escaping="$(
  {
    body | grep -oE '(`|\]\()\.\./[^`)[:space:]]+' || true
    body | grep -oE '\]\(/[^)[:space:]]+' || true
  } | sed 's/^`//; s/^](//' | sort -u
)"
if [ -n "$escaping" ]; then
  while IFS= read -r p; do fail "path '$p' stays inside the skill folder — only the folder travels on install"; done <<< "$escaping"
else
  pass "no path reaches outside the skill folder"
fi

find "$DIR" -type l | grep -q . && fail "the folder holds no symlinks — they do not survive a copy" || true

exit "$failed"
