#!/usr/bin/env bash
# =============================================================================
# test-validate-skills.sh — Prove validate-skills.sh actually fails.
#
# This repo once shipped a check that silently passed: it grepped the README for
# a heading that had been renamed, extracted nothing, and reported success for
# months. A validator nobody has watched fail is indistinguishable from one that
# does nothing. Each case below breaks exactly one rule in a scratch copy and
# asserts the validator rejects it.
#
# Usage:
#   ./scripts/test-validate-skills.sh
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_skills-lib.sh"

WORK="$(mktemp -d)"
BASE="$WORK/base"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$BASE"
(cd "$REPO_ROOT" && tar cf - --exclude=.git .) | (cd "$BASE" && tar xf -)

PASSED=0
FAILED=0

# expect_reject <label> <expected-message-substring> <mutation>
expect_reject() {
  local label="$1" expect="$2" mutation="$3" out code
  local sandbox="$WORK/case"

  rm -rf "$sandbox"; cp -R "$BASE" "$sandbox"
  ( cd "$sandbox" && eval "$mutation" )

  set +e
  out="$(cd "$sandbox" && ./scripts/validate-skills.sh 2>&1)"
  code=$?
  set -e

  if [ "$code" -eq 0 ]; then
    log_error "not rejected: $label"
    FAILED=$((FAILED + 1))
  elif ! printf '%s' "$out" | grep -qi -- "$expect"; then
    log_error "rejected for the wrong reason: $label (wanted \"$expect\")"
    printf '%s\n' "$out" | grep '✗' | head -2
    FAILED=$((FAILED + 1))
  else
    log_success "$label"
    PASSED=$((PASSED + 1))
  fi
}

# expect_accept <label> <mutation>  — changes that must NOT trip the validator
expect_accept() {
  local label="$1" mutation="$2" code
  local sandbox="$WORK/case"

  rm -rf "$sandbox"; cp -R "$BASE" "$sandbox"
  ( cd "$sandbox" && eval "$mutation" )

  set +e
  (cd "$sandbox" && ./scripts/validate-skills.sh) >/dev/null 2>&1
  code=$?
  set -e

  if [ "$code" -ne 0 ]; then
    log_error "false positive: $label"
    FAILED=$((FAILED + 1))
  else
    log_success "$label"
    PASSED=$((PASSED + 1))
  fi
}

log_section "Baseline"

if ! (cd "$BASE" && ./scripts/validate-skills.sh) >/dev/null 2>&1; then
  log_error "the repo itself does not pass validate-skills.sh — fix that first"
  exit 1
fi
log_success "unmodified repo passes"

log_section "Rules that must be enforced"

expect_reject "dangling reference link" "does not exist" \
  "sed -i.bak 's|\`references/artifact-paths.md\`|\`references/nope.md\`|' skills/engineering/tdd/SKILL.md"

expect_reject "reference is a dangling symlink" "does not exist" \
  "rm -f skills/engineering/tdd/references/artifact-paths.md
   ln -s /nonexistent.md skills/engineering/tdd/references/artifact-paths.md"

expect_reject "name does not match folder" "does not match its folder" \
  "sed -i.bak 's/^name: tdd\$/name: tdd-renamed/' skills/engineering/tdd/SKILL.md"

expect_reject "name contains a reserved word" "reserved word" \
  "sed -i.bak 's/^name: tdd\$/name: claude-tdd/' skills/engineering/tdd/SKILL.md"

expect_reject "name has consecutive hyphens" "single internal hyphens" \
  "sed -i.bak 's/^name: tdd\$/name: t--dd/' skills/engineering/tdd/SKILL.md"

expect_reject "missing frontmatter" "frontmatter" \
  "printf '# no frontmatter\n' > skills/engineering/tdd/SKILL.md"

expect_reject "forceful wording in the body" "forceful" \
  "printf 'ALWAYS use this skill.\n' >> skills/engineering/tdd/SKILL.md"

expect_reject "shippable skill missing from plugin.json" "missing from .claude-plugin" \
  "sed -i.bak '/\"\.\/skills\/engineering\/tdd\"/d' .claude-plugin/plugin.json"

expect_reject "plugin.json entry with no skill on disk" "no SKILL.md on disk" \
  "sed -i.bak 's|\"./skills/engineering/tdd\",|\"./skills/engineering/ghost\",|' .claude-plugin/plugin.json"

expect_reject "shippable skill not linked in README" "not linked in README" \
  "sed -i.bak '/](skills\/engineering\/tdd\/SKILL.md)/d' README.md"

# The catalog drifted from four SKILL.md descriptions before anything checked it.
expect_reject "README description drifted from SKILL.md" "differs from its SKILL.md" \
  "python3 - <<'EOF'
import pathlib
p = pathlib.Path('README.md')
lines = p.read_text().split('\n')
for i, ln in enumerate(lines):
    if 'skills/engineering/tdd/SKILL.md)' in ln and ln.startswith('|'):
        lines[i] = '|' + ln.split('|')[1] + '| A description that drifted. |'
p.write_text('\n'.join(lines))
EOF"

expect_reject "README lists no skills at all" "lists no skills" \
  "sed -i.bak '/SKILL.md)/d' README.md"

# Six catalog rows once carried the skill's argument-hint on a second physical
# line, which renders as a broken table while leaving the description cell intact.
expect_reject "catalog row split across two lines" "well-formed row" \
  "python3 - <<'EOF'
import pathlib
p = pathlib.Path('README.md')
lines = p.read_text().split('\n')
for i, ln in enumerate(lines):
    if 'skills/engineering/tdd/SKILL.md)' in ln and ln.startswith('|'):
        lines.insert(i + 1, 'argument-hint: \"<hint> |')
        break
p.write_text('\n'.join(lines))
EOF"

# The same bug in a bucket README must be caught too, not just the top-level one.
expect_reject "malformed row in a bucket README" "well-formed row" \
  "python3 - <<'EOF'
import pathlib
p = pathlib.Path('skills/productivity/README.md')
lines = p.read_text().split('\n')
for i, ln in enumerate(lines):
    if 'handoff/SKILL.md)' in ln and ln.startswith('|'):
        lines.insert(i + 1, 'argument-hint: \"<hint> |')
        break
p.write_text('\n'.join(lines))
EOF"

# The badge said 27 while 28 shipped.
expect_reject "README skill count out of date" "claims" \
  "sed -i.bak 's|badge/skills-[0-9]*-|badge/skills-99-|' README.md"

# Only the skill's own folder is copied on install, so any path reaching outside
# it is dead on arrival. Both shapes shipped in this repo at some point.
expect_reject "path into a sibling skill's folder" "reaches outside" \
  "sed -i.bak 's|point them at the \`setup-context\` skill (\`/setup-context\`).|use \`skills/productivity/setup-context/references/domains.md\`.|' skills/engineering/security-audit/SKILL.md"

expect_reject "../.. path escaping the skill root" "reaches outside" \
  "sed -i.bak 's|\`references/artifact-paths.md\`: output-location|\`../../_shared/references/artifact-paths.md\`: output-location|' skills/productivity/setup-context/SKILL.md"

log_section "Changes that must not trip it"

# The original bug: the catalog check keyed off a heading name, so renaming the
# heading silently disabled it. Rows are now found by content instead.
expect_accept "renaming the README catalog heading" \
  "sed -i.bak 's/^## Skill Catalog/## The Catalog/' README.md"

# skill-smith documents where skills live; a placeholder path is not a reference.
expect_accept "a templated path with <placeholders>" \
  "printf 'See \`skills/<bucket>/<name>/SKILL.md\` for the shape.\n' >> skills/engineering/tdd/SKILL.md"

log_section "Result"

if [ "$FAILED" -ne 0 ]; then
  log_error "$FAILED case(s) failed, $PASSED passed"
  exit 1
fi

log_success "$PASSED case(s) passed — validate-skills.sh rejects what it should"
