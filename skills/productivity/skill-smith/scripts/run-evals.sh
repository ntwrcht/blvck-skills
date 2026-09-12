#!/usr/bin/env bash
# Runs a skill's trigger and output evals from <skill-dir>/assets/evals/.
# Usage: bash scripts/run-evals.sh <skill-dir> [--runs N] [--model MODEL] [--max-cost-usd USD] [--fallback]
#
# Wraps the skill in a throwaway plugin first: `claude plugin eval` given a bare
# skill folder resolves no plugin and silently scores the baseline instead.
# Uses `claude plugin eval` when the account has it; otherwise falls back to
# `claude -p`, which checks triggering only and prints outputs for judging.
#
# Exit: 0 every case passed · 1 a case failed · 2 usage error · 3 no claude CLI

set -euo pipefail

usage() { sed -n '2,3p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

SKILL_DIR=""
RUNS=3
MODEL=""
MAX_COST=5
FORCE_FALLBACK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --runs)         RUNS="${2:?--runs needs a number}"; shift 2 ;;
    --model)        MODEL="${2:?--model needs a model name}"; shift 2 ;;
    --max-cost-usd) MAX_COST="${2:?--max-cost-usd needs an amount}"; shift 2 ;;
    --fallback)     FORCE_FALLBACK=1; shift ;;
    -h|--help)      usage ;;
    -*)             echo "Unknown option: $1" >&2; usage ;;
    *)              SKILL_DIR="$1"; shift ;;
  esac
done

[ -n "$SKILL_DIR" ] || usage
SKILL_DIR="$(cd "$SKILL_DIR" && pwd)"
[ -f "$SKILL_DIR/SKILL.md" ] || { echo "No SKILL.md in $SKILL_DIR" >&2; exit 2; }

CASES="$SKILL_DIR/assets/evals"
ls -d "$CASES"/*/ >/dev/null 2>&1 || { echo "No eval cases in $CASES — write them first." >&2; exit 2; }

NAME="$(sed -n 's/^name:[[:space:]]*"\{0,1\}\([a-z0-9-]*\)"\{0,1\}[[:space:]]*$/\1/p' "$SKILL_DIR/SKILL.md" | head -1)"
[ -n "$NAME" ] || NAME="$(basename "$SKILL_DIR")"

command -v claude >/dev/null 2>&1 || {
  echo "No claude CLI on PATH: these evals need Claude Code. The cases in $CASES are written but unrun." >&2
  exit 3
}

# ── throwaway plugin wrapper ─────────────────────────────────────────────────

TMP_ROOT="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "${TMP_ROOT%/}/skill-eval.XXXXXX")"
PLUGIN="$WORK/plugin"
RESULTS="$WORK/results"
trap 'rm -rf "$PLUGIN" "$WORK/cwd" "$WORK"/probe.*' EXIT

mkdir -p "$PLUGIN/.claude-plugin" "$PLUGIN/skills" "$WORK/cwd" "$RESULTS"
printf '{"name":"%s-eval","version":"0.0.0","skills":["./skills/%s"]}\n' "$NAME" "$NAME" \
  > "$PLUGIN/.claude-plugin/plugin.json"
cp -R "$SKILL_DIR" "$PLUGIN/skills/$NAME"
# The skill under test never sees its own answer key.
rm -rf "$PLUGIN/skills/$NAME/assets/evals"
cp -R "$CASES" "$PLUGIN/evals"

# ── helpers ──────────────────────────────────────────────────────────────────

frontmatter() { awk 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {exit} f' "$1"; }
body()        { awk 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {f=0; next} !f' "$1"; }

# yes: a grader expects the skill to fire · no: expects silence · none: no trigger grader
expect_trigger() {
  local g fm
  for g in "$1"/graders/*.md; do
    [ -f "$g" ] || continue
    fm="$(frontmatter "$g")"
    printf '%s\n' "$fm" | grep -q '^type:[[:space:]]*tool_used' || continue
    printf '%s\n' "$fm" | grep -q '^tool:[[:space:]]*Skill' || continue
    if printf '%s\n' "$fm" | grep -q '^max:[[:space:]]*0[[:space:]]*$'; then echo no; else echo yes; fi
    return
  done
  echo none
}

eval_available() {
  [ "$FORCE_FALLBACK" -eq 0 ] || return 1
  claude plugin eval --help >/dev/null 2>&1 || return 1
  local probe out
  probe="$(mktemp -d "$WORK/probe.XXXXXX")"
  out="$(cd "$probe" && claude plugin eval . --trust-plugin --no-publish 2>&1 || true)"
  case "$out" in *"early access"*) return 1 ;; esac
}

# ── primary: claude plugin eval ──────────────────────────────────────────────

run_plugin_eval() {
  echo "Running claude plugin eval on '$NAME': $RUNS run(s) per case, cost ceiling \$$MAX_COST${MODEL:+, model $MODEL}."
  local status=0
  claude plugin eval "$PLUGIN" --trust-plugin --no-publish --runs "$RUNS" -j 4 ${MODEL:+--model "$MODEL"} \
    --max-cost-usd "$MAX_COST" --output-dir "$RESULTS" --report "$RESULTS/report.html" || status=$?
  echo "Results: $RESULTS"
  [ "$status" -eq 0 ] || exit 1
}

# ── fallback: claude -p, triggering only ─────────────────────────────────────

run_fallback() {
  command -v jq >/dev/null 2>&1 || { echo "The fallback needs jq on PATH." >&2; exit 2; }
  if [ "$FORCE_FALLBACK" -eq 1 ]; then
    echo "--fallback given — running claude -p."
  else
    echo "claude plugin eval is unavailable — falling back to claude -p."
  fi
  echo "Triggering is checked on every case; outputs are printed for you to judge."
  echo

  local failed=0 case_dir case_name fm prompt max_turns tools expect run out fired skill verdict g
  for case_dir in "$CASES"/*/; do
    case_dir="${case_dir%/}"
    case_name="$(basename "$case_dir")"
    [ -f "$case_dir/prompt.md" ] || { echo "SKIP  $case_name: no prompt.md"; continue; }

    fm="$(frontmatter "$case_dir/prompt.md")"
    prompt="$(body "$case_dir/prompt.md")"
    max_turns="$(printf '%s\n' "$fm" | sed -n 's/^max_turns:[[:space:]]*//p')"
    tools="$(printf '%s\n' "$fm" | sed -n 's/^allowed_tools:[[:space:]]*\[\(.*\)\]/\1/p' | tr -d ' ')"
    case ",$tools," in *,Skill,*) ;; *) tools="Skill${tools:+,$tools}" ;; esac
    expect="$(expect_trigger "$case_dir")"

    run=1
    while [ "$run" -le "$RUNS" ]; do
      out="$RESULTS/$case_name-$run.jsonl"
      (cd "$WORK/cwd" && claude -p "$prompt" --plugin-dir "$PLUGIN" ${MODEL:+--model "$MODEL"} --output-format stream-json --verbose \
        --max-turns "${max_turns:-10}" --allowedTools "$tools" > "$out" 2>/dev/null) || true

      fired=no
      while IFS= read -r skill; do
        case "$skill" in "$NAME"|*":$NAME") fired=yes ;; esac
      done < <(jq -r 'select(.type=="assistant") | .message.content[]?
                      | select(.type=="tool_use" and .name=="Skill") | .input.skill // empty' "$out" 2>/dev/null || true)

      case "$expect" in
        yes) if [ "$fired" = yes ]; then verdict=PASS; else verdict=FAIL; failed=1; fi ;;
        no)  if [ "$fired" = no ];  then verdict=PASS; else verdict=FAIL; failed=1; fi ;;
        *)   verdict="----" ;;
      esac
      echo "$verdict  $case_name  run $run/$RUNS  expected to fire: $expect, fired: $fired"
      run=$((run + 1))
    done

    for g in "$case_dir"/graders/*.md; do
      [ -f "$g" ] || continue
      frontmatter "$g" | grep -Eq '^type:[[:space:]]*(llm|regex)' || continue
      echo
      echo "  JUDGE $case_name against $(basename "$g"):"
      body "$g" | sed '/^[[:space:]]*$/d; s/^/    criteria │ /'
      frontmatter "$g" | sed -n 's/^pattern:[[:space:]]*/    pattern  │ /p'
      jq -r 'select(.type=="result") | .result // empty' "$out" 2>/dev/null | sed 's/^/    output   │ /'
    done
    echo
  done

  echo "Transcripts: $RESULTS"
  [ "$failed" -eq 0 ] || exit 1
}

if eval_available; then run_plugin_eval; else run_fallback; fi
