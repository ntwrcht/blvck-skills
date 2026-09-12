#!/usr/bin/env bash
# Runs a skill's trigger and output evals from <skill-dir>/assets/evals/.
# Usage: bash scripts/run-evals.sh <skill-dir> [--baseline] [--runs N] [--model MODEL] [--max-cost-usd USD] [--fallback]
#
# Wraps the skill in a throwaway plugin first: `claude plugin eval` given a bare
# skill folder resolves no plugin and silently scores the baseline instead.
# --baseline turns that trap into a tool: it runs only the output checks with no
# skill loaded, to show whether plain Claude already does the job. It needs only
# assets/evals/, so it runs before SKILL.md exists.
# Uses `claude plugin eval` when the account has it; otherwise falls back to
# `claude -p`, which checks triggering only and prints outputs for judging.
#
# Exit: 0 every case passed (--baseline: the run completed) · 1 a case failed · 2 usage error · 3 no claude CLI

set -euo pipefail

usage() { sed -n '2,3p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

SKILL_DIR=""
BASELINE=0
RUNS=3
MODEL=""
MAX_COST=5
FORCE_FALLBACK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --baseline)     BASELINE=1; shift ;;
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

CASES="$SKILL_DIR/assets/evals"
ls -d "$CASES"/*/ >/dev/null 2>&1 || { echo "No eval cases in $CASES — write them first." >&2; exit 2; }

NAME=""
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  NAME="$(sed -n 's/^name:[[:space:]]*"\{0,1\}\([a-z0-9-]*\)"\{0,1\}[[:space:]]*$/\1/p' "$SKILL_DIR/SKILL.md" | head -1)"
elif [ "$BASELINE" -eq 0 ]; then
  echo "No SKILL.md in $SKILL_DIR — draft it first, or pass --baseline." >&2
  exit 2
fi
[ -n "$NAME" ] || NAME="$(basename "$SKILL_DIR")"

command -v claude >/dev/null 2>&1 || {
  echo "No claude CLI on PATH: these evals need Claude Code. The cases in $CASES are written but unrun." >&2
  exit 3
}

TMP_ROOT="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "${TMP_ROOT%/}/skill-eval.XXXXXX")"
PLUGIN="$WORK/plugin"
BASE="$WORK/baseline"
RESULTS="$WORK/results"
trap 'rm -rf "$PLUGIN" "$BASE" "$WORK/cwd" "$WORK"/probe.*' EXIT
mkdir -p "$WORK/cwd" "$RESULTS"

# ── helpers ──────────────────────────────────────────────────────────────────

frontmatter() { awk 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {exit} f' "$1"; }
body()        { awk 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {f=0; next} !f' "$1"; }

# yes: a grader expects the skill to fire · no: expects silence · none: no trigger grader
expect_trigger() {
  local g fm
  for g in "$1"/graders/*.md; do
    [ -f "$g" ] || continue
    fm="$(frontmatter "$g")"
    grep -q '^type:[[:space:]]*tool_used' <<< "$fm" || continue
    grep -q '^tool:[[:space:]]*Skill' <<< "$fm" || continue
    if grep -q '^max:[[:space:]]*0[[:space:]]*$' <<< "$fm"; then echo no; else echo yes; fi
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

need_jq() { command -v jq >/dev/null 2>&1 || { echo "This mode needs jq on PATH." >&2; exit 2; }; }

# ── the skill under test: a throwaway plugin wrapper ─────────────────────────

build_wrapper() {
  mkdir -p "$PLUGIN/.claude-plugin" "$PLUGIN/skills"
  printf '{"name":"%s-eval","version":"0.0.0","skills":["./skills/%s"]}\n' "$NAME" "$NAME" \
    > "$PLUGIN/.claude-plugin/plugin.json"
  cp -R "$SKILL_DIR" "$PLUGIN/skills/$NAME"
  # The skill under test never sees its own answer key.
  rm -rf "$PLUGIN/skills/$NAME/assets/evals"
  cp -R "$CASES" "$PLUGIN/evals"
}

# ── the baseline: output checks only, no plugin at all ───────────────────────

build_baseline() {
  local case_dir case_name dest g kept
  mkdir -p "$BASE/evals"
  for case_dir in "$CASES"/*/; do
    case_dir="${case_dir%/}"
    case_name="$(basename "$case_dir")"
    [ "$(expect_trigger "$case_dir")" != no ] || continue
    dest="$BASE/evals/$case_name"
    cp -R "$case_dir" "$dest"
    for g in "$dest"/graders/*.md; do
      [ -f "$g" ] || continue
      if grep -q '^type:[[:space:]]*tool_used' <<< "$(frontmatter "$g")"; then rm "$g"; fi
    done
    kept=0
    for g in "$dest"/graders/*.md; do [ -f "$g" ] && kept=1; done
    if [ "$kept" -eq 0 ]; then rm -rf "$dest"; continue; fi
    # A user-invoked case fires the skill by name; plain Claude gets the request alone.
    sed -i.bak "s#^/$NAME[[:space:]]*##" "$dest/prompt.md" && rm -f "$dest/prompt.md.bak"
  done
  ls -d "$BASE/evals"/*/ >/dev/null 2>&1 || { echo "No case has an output check to run against the baseline." >&2; exit 2; }
}

run_baseline_eval() {
  need_jq
  echo "Baseline for '$NAME': output checks only, no skill loaded, $RUNS run(s) per case."
  claude plugin eval "$BASE" --trust-plugin --no-publish --ablation none --runs "$RUNS" -j 4 ${MODEL:+--model "$MODEL"} \
    --max-cost-usd "$MAX_COST" --output-dir "$RESULTS" --report "$RESULTS/report.html" || true
  local agg
  agg="$(find "$RESULTS" -name aggregate-result.json | head -1)"
  [ -n "$agg" ] || { echo "The baseline run produced no results." >&2; exit 1; }
  echo
  jq -r '.cases[] | "\(if .aggregates.score >= 1 then "PLAIN CLAUDE PASSES" else "SKILL HAS A JOB    " end)  \(.name)  (baseline score \(.aggregates.score))"' "$agg"
  if jq -e 'all(.cases[]; .aggregates.score >= 1)' "$agg" >/dev/null; then
    echo "VERDICT: plain Claude already meets every output check — the skill has no job for these cases."
  else
    echo "VERDICT: plain Claude misses at least one output check — the skill has a job."
  fi
  echo "Results: $RESULTS"
}

# ── primary: claude plugin eval ──────────────────────────────────────────────

run_plugin_eval() {
  echo "Running claude plugin eval on '$NAME': $RUNS run(s) per case, cost ceiling \$$MAX_COST${MODEL:+, model $MODEL}."
  local status=0 ablation=""
  # A /<name> prompt fails without the skill, so the no-skill arm would score a
  # meaningless 0 for free. --baseline gives the real comparison.
  if grep -q '^disable-model-invocation:[[:space:]]*true' "$SKILL_DIR/SKILL.md"; then
    ablation="none"
    echo "User-invoked skill: skipping the no-skill arm. Run --baseline for the comparison."
  fi
  claude plugin eval "$PLUGIN" --trust-plugin --no-publish --runs "$RUNS" -j 4 ${MODEL:+--model "$MODEL"} ${ablation:+--ablation "$ablation"} \
    --max-cost-usd "$MAX_COST" --output-dir "$RESULTS" --report "$RESULTS/report.html" || status=$?
  echo "Results: $RESULTS"
  [ "$status" -eq 0 ] || exit 1
}

# ── fallback: claude -p, triggering only ─────────────────────────────────────

# $1: the cases to run · $2: 1 to load the wrapper plugin, 0 for the baseline
run_fallback() {
  local run_cases="$1" load_plugin="$2"
  need_jq
  if [ "$FORCE_FALLBACK" -eq 1 ]; then
    echo "--fallback given — running claude -p."
  else
    echo "claude plugin eval is unavailable — falling back to claude -p."
  fi
  if [ "$load_plugin" -eq 1 ]; then
    echo "Triggering is checked on every case; outputs are printed for you to judge."
  else
    echo "Baseline: no skill loaded. Judge each output against its criteria — a pass means plain Claude already does that job."
  fi
  echo

  local failed=0 case_dir case_name fm prompt max_turns tools expect run out fired skill verdict g
  for case_dir in "$run_cases"/*/; do
    case_dir="${case_dir%/}"
    case_name="$(basename "$case_dir")"
    [ -f "$case_dir/prompt.md" ] || { echo "SKIP  $case_name: no prompt.md"; continue; }

    fm="$(frontmatter "$case_dir/prompt.md")"
    prompt="$(body "$case_dir/prompt.md")"
    max_turns="$(sed -n 's/^max_turns:[[:space:]]*//p' <<< "$fm")"
    tools="$(sed -n 's/^allowed_tools:[[:space:]]*\[\(.*\)\]/\1/p' <<< "$fm" | tr -d ' ')"
    case ",$tools," in *,Skill,*) ;; *) tools="Skill${tools:+,$tools}" ;; esac
    expect="$(expect_trigger "$case_dir")"

    run=1
    while [ "$run" -le "$RUNS" ]; do
      out="$RESULTS/$case_name-$run.jsonl"
      if [ "$load_plugin" -eq 1 ]; then
        (cd "$WORK/cwd" && claude -p "$prompt" --plugin-dir "$PLUGIN" ${MODEL:+--model "$MODEL"} --output-format stream-json --verbose \
          --max-turns "${max_turns:-10}" --allowedTools "$tools" > "$out" 2>/dev/null) || true
      else
        (cd "$WORK/cwd" && claude -p "$prompt" ${MODEL:+--model "$MODEL"} --output-format stream-json --verbose \
          --max-turns "${max_turns:-10}" --allowedTools "$tools" > "$out" 2>/dev/null) || true
      fi

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
      grep -Eq '^type:[[:space:]]*(llm|regex)' <<< "$(frontmatter "$g")" || continue
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

# ── main ─────────────────────────────────────────────────────────────────────

if [ "$BASELINE" -eq 1 ]; then
  build_baseline
  if eval_available; then run_baseline_eval; else run_fallback "$BASE/evals" 0; fi
else
  build_wrapper
  if eval_available; then run_plugin_eval; else run_fallback "$CASES" 1; fi
fi
