#!/usr/bin/env bash
# =============================================================================
# validate-skills.sh — Enforce every skill rule this repo states in CLAUDE.md,
# plus the Agent Skills spec (https://agentskills.io/specification).
#
# Checks:
#   Frontmatter  present; name matches folder, charset/length/reserved words;
#                description present and within the 1024-char spec limit
#   Body         no overly forceful activation wording; every bundled
#                references/ and scripts/ link resolves on disk
#   Catalog      shippable skills appear in plugin.json + both README surfaces;
#                unshippable buckets appear in neither
#
# Usage:
#   ./scripts/validate-skills.sh
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_skills-lib.sh"

BANNED_PATTERN='ALWAYS use|MUST use|Trigger when|Trigger on|proactively whenever|Do NOT attempt|no exceptions'
RESERVED_PATTERN='anthropic|claude'
NAME_PATTERN='^[a-z0-9]+(-[a-z0-9]+)*$'   # no leading/trailing or doubled hyphen
NAME_MAX=64
DESC_MAX=1024

PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"
FAILED=0

fail() { log_error "$1"; FAILED=1; }

# ── Frontmatter parsing ───────────────────────────────────────────────────────

extract_frontmatter() {
  awk '
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---" { exit }
    in_fm { print }
  ' "$1"
}

extract_body() {
  awk '
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---" { in_fm = 0; body = 1; next }
    body { print }
  ' "$1"
}

# Reads a scalar, handling both `key: value` and folded (`key: >`) block scalars.
frontmatter_value() {
  extract_frontmatter "$1" | awk -v key="$2" '
    index($0, key ":") == 1 {
      val = substr($0, length(key) + 2)
      sub(/^[[:space:]]+/, "", val)
      if (val == ">" || val == "|" || val == ">-" || val == "|-") {
        val = ""
        while ((getline line) > 0) {
          if (line !~ /^[[:space:]]/) break
          sub(/^[[:space:]]+/, "", line)
          val = (val == "" ? line : val " " line)
        }
      }
      sub(/^"/, "", val); sub(/"$/, "", val)
      print val
      exit
    }
  '
}

# ── Per-skill checks (every bucket — the spec applies to drafts too) ──────────

log_section "Checking skill frontmatter and bodies"

skill_count=0
while IFS= read -r skill_dir; do
  skill_count=$((skill_count + 1))
  skill_file="$skill_dir/SKILL.md"
  rel="${skill_file#"$REPO_ROOT"/}"
  dir_name="$(skill_name_from_dir "$skill_dir")"

  if [ "$(head -1 "$skill_file")" != "---" ]; then
    fail "$rel does not open with YAML frontmatter on line 1"
    continue
  fi

  name="$(frontmatter_value "$skill_file" name)"
  desc="$(frontmatter_value "$skill_file" description)"

  # name
  if [ -z "$name" ]; then
    fail "$rel has no name"
  else
    [ "$name" = "$dir_name" ] || fail "$rel name '$name' does not match its folder '$dir_name'"
    [ "${#name}" -le "$NAME_MAX" ] || fail "$rel name is ${#name} chars (spec max $NAME_MAX)"
    printf '%s' "$name" | grep -Eq "$NAME_PATTERN" ||
      fail "$rel name '$name' must be lowercase alphanumeric with single internal hyphens"
    if printf '%s' "$name" | grep -Eiq "$RESERVED_PATTERN"; then
      fail "$rel name '$name' contains a spec-reserved word (anthropic, claude)"
    fi
  fi

  # description
  if [ -z "$desc" ]; then
    fail "$rel has no description"
  else
    [ "${#desc}" -le "$DESC_MAX" ] || fail "$rel description is ${#desc} chars (spec max $DESC_MAX)"
  fi

  # forceful wording — frontmatter and body
  if grep -Eiq "$BANNED_PATTERN" "$skill_file"; then
    fail "$rel contains overly forceful activation wording"
    grep -Ein "$BANNED_PATTERN" "$skill_file" || true
  fi

  # bundled links resolve — the check that catches a dangling reference
  body="$(extract_body "$skill_file")"
  targets="$(
    {
      # markdown links: [x](target)
      printf '%s\n' "$body" | grep -oE '\]\([^)]+\)' | sed 's/^](//; s/)$//' || true
      # backticked bundled paths: `references/x.md`, `scripts/y.sh`
      printf '%s\n' "$body" | grep -oE '`(references|scripts)/[^`]+`' | tr -d '`' || true
    } | sort -u
  )"

  while IFS= read -r target; do
    [ -n "$target" ] || continue
    case "$target" in
      http*|'#'*|mailto:*) continue ;;
    esac
    target="${target#./}"
    [ -e "$skill_dir/$target" ] || fail "$rel references '$target', which does not exist in the skill folder"
  done <<< "$targets"

  # A skill folder is copied out of this repo on its own, so a path that reaches
  # outside it — into the repo root or a sibling skill — is dead once installed.
  escaping="$(
    printf '%s\n' "$body" |
      grep -oE '`(\.\./|skills/)[^`]+`|\]\((\.\./|skills/)[^)]+\)' |
      sed 's/^`//; s/`$//; s/^](//; s/)$//' |
      sort -u || true
  )"
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    # `skills/<bucket>/<name>/` and friends are templates describing a path shape,
    # not files to read. Placeholders are the tell.
    case "$target" in *'<'*|*'>'*) continue ;; esac
    fail "$rel references '$target', which reaches outside the skill folder and breaks once the skill is installed"
  done <<< "$escaping"
done < <(list_skill_dirs)

log_info "Checked $skill_count skill(s)"

# ── Catalog sync (shippable skills only) ─────────────────────────────────────

log_section "Checking catalog sync"

# Public description rows are identified by content (a link to a SKILL.md), not
# by heading position — a renamed heading must never silently skip this check.
check_catalog_rows() {
  local file="$1" rows
  rows="$(grep -E '\]\([^)]*SKILL\.md\)' "$file" || true)"

  if [ -z "$rows" ]; then
    fail "${file#"$REPO_ROOT"/} lists no skills (expected table rows linking to a SKILL.md)"
    return
  fi

  if printf '%s\n' "$rows" | grep -Eiq "$BANNED_PATTERN"; then
    fail "${file#"$REPO_ROOT"/} contains overly forceful activation wording"
    printf '%s\n' "$rows" | grep -Ein "$BANNED_PATTERN" || true
  fi
}

check_catalog_rows "$REPO_ROOT/README.md"

# The README advertises a skill count in a badge and in prose; both drift silently.
shippable_count="$(list_shippable_skill_dirs | wc -l | tr -d ' ')"
while IFS= read -r claimed; do
  [ "$claimed" = "$shippable_count" ] ||
    fail "README.md claims $claimed skills, but $shippable_count are shippable"
done < <(
  {
    grep -oE 'badge/skills-[0-9]+-' "$REPO_ROOT/README.md" | grep -oE '[0-9]+'
    grep -oE '\*\*[0-9]+ production-ready skills\*\*' "$REPO_ROOT/README.md" | grep -oE '[0-9]+'
  } | sort -u
)

for bucket in "${SHIPPABLE_BUCKETS[@]}"; do
  bucket_readme="$SKILLS_DIR/$bucket/README.md"
  [ -f "$bucket_readme" ] || continue
  # An empty bucket legitimately lists nothing.
  [ -n "$(find "$SKILLS_DIR/$bucket" -mindepth 2 -name SKILL.md -print -quit)" ] || continue
  check_catalog_rows "$bucket_readme"
done

# The catalog must describe what actually ships: a README row whose text has
# drifted from the SKILL.md description documents a skill that does not exist.
readme_row_description() {
  grep -F "$2/SKILL.md)" "$1" | head -1 | sed 's/.*SKILL\.md) *| *//; s/ *|$//'
}

while IFS= read -r skill_dir; do
  name="$(skill_name_from_dir "$skill_dir")"
  bucket="$(basename "$(dirname "$skill_dir")")"
  desc="$(frontmatter_value "$skill_dir/SKILL.md" description)"

  grep -q "\"\./skills/$bucket/$name\"" "$PLUGIN_JSON" ||
    fail "$bucket/$name is shippable but missing from .claude-plugin/plugin.json"

  if ! grep -q "](skills/$bucket/$name/SKILL.md)" "$REPO_ROOT/README.md"; then
    fail "$bucket/$name is shippable but not linked in README.md"
  elif [ "$(readme_row_description "$REPO_ROOT/README.md" "$name")" != "$desc" ]; then
    fail "$bucket/$name description in README.md differs from its SKILL.md"
  fi

  if ! grep -q "]($name/SKILL.md)" "$SKILLS_DIR/$bucket/README.md"; then
    fail "$bucket/$name is shippable but not linked in skills/$bucket/README.md"
  elif [ "$(readme_row_description "$SKILLS_DIR/$bucket/README.md" "$name")" != "$desc" ]; then
    fail "$bucket/$name description in skills/$bucket/README.md differs from its SKILL.md"
  fi
done < <(list_shippable_skill_dirs)

# plugin.json must not point at anything missing or unshippable
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  path="${entry#./}"
  [ -f "$REPO_ROOT/$path/SKILL.md" ] ||
    fail "plugin.json lists '$entry', which has no SKILL.md on disk"

  entry_bucket="$(basename "$(dirname "$path")")"
  _is_in_list "$entry_bucket" "${SHIPPABLE_BUCKETS[@]}" ||
    fail "plugin.json lists '$entry' from the unshippable '$entry_bucket' bucket"
done < <(grep -oE '"\./skills/[^"]+"' "$PLUGIN_JSON" | tr -d '"')

# Unshippable skills must appear in neither the manifest nor any README
while IFS= read -r skill_dir; do
  bucket="$(basename "$(dirname "$skill_dir")")"
  _is_in_list "$bucket" "${SHIPPABLE_BUCKETS[@]}" && continue
  name="$(skill_name_from_dir "$skill_dir")"

  if grep -q "\"\./skills/$bucket/$name\"" "$PLUGIN_JSON"; then
    fail "$bucket/$name is not shippable but appears in .claude-plugin/plugin.json"
  fi
  if grep -q "](skills/$bucket/$name/SKILL.md)" "$REPO_ROOT/README.md"; then
    fail "$bucket/$name is not shippable but is linked in README.md"
  fi
done < <(list_skill_dirs)

# ── Result ────────────────────────────────────────────────────────────────────

if [ "$FAILED" -ne 0 ]; then
  cat <<'EOF'

Fix the failures above. Reference:
  - Skill rules and bucket policy: CLAUDE.md
  - Agent Skills spec:             https://agentskills.io/specification
  - Shared references:             ./scripts/sync-shared-refs.sh

Public descriptions may use a concise "Use when" trigger sentence, but should
avoid forceful activation wording such as "ALWAYS use" or "MUST use".
EOF
  exit 1
fi

log_success "All skills valid"
