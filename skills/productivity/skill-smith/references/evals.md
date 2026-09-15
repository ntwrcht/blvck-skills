# Evals — Proving a Skill Triggers and Delivers

**Load this when** the use cases are confirmed and it is time to turn them into eval cases, run them, or read a failing result.

## What an Eval Proves

Three claims, each checked by a different grader:

| Claim | Case | Grader |
|---|---|---|
| The skill fires for the requests it owns | Trigger case | `tool_used` on `Skill`, `min: 1` |
| The skill stays quiet for requests it does not own | Near-miss case | `tool_used` on `Skill`, `max: 0`, `arm: both` |
| The output does the job | Trigger case | `regex` for exact, checkable parts; `llm` for judgement |

`claude plugin eval` runs every case twice, with the skill and without it. The without-arm is the baseline: a trigger case whose output passes without the skill too means the skill adds nothing for that request.

## Case Layout

One folder per case under the new skill's `assets/evals/`, named for the request and prefixed by type:

```text
assets/evals/
|-- trigger-review-pr-diff/
|   |-- prompt.md
|   `-- graders/
|       |-- fired.md
|       `-- output.md
`-- nearmiss-write-release-notes/
    |-- prompt.md
    `-- graders/
        `-- not-fired.md
```

### `prompt.md`

```md
---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Can you look over the diff on this branch before I open the PR?
```

- Word the prompt the way the user types it, and leave the skill's name out — a prompt that names the skill tests the name, not the description.
- Add `Write`, `Edit`, or `Bash` to `allowed_tools` only when the output depends on them.
- The prompt runs in an empty folder with no repository and no shell, so paste whatever the skill reads — a diff, a file, a log — into the prompt after the request.
- For a user-invoked skill (`disable-model-invocation: true`), write output cases only and start the prompt with `/<skill-name>` followed by the request, the way the user fires it. Name the folder `output-...`. A `/<skill-name>` prompt fails without the skill, so the normal run skips the no-skill arm; run `--baseline` for the comparison.

### `graders/fired.md` — trigger case

```md
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?<skill-name>"'
min: 1
---
```

The optional `[\w-]+:` prefix matters: inside the wrapper the skill fires as `<plugin>:<skill-name>`.

### `graders/not-fired.md` — near-miss case

```md
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?<skill-name>"'
min: 0
max: 0
arm: both
---
```

Keep `arm: both`. Without it a `tool_used: Skill` grader is only an indicator in the with/without run, so the near-miss passes whatever happens.

Give a near-miss prompt `allowed_tools: [Skill]` and `max_turns: 2`: the case asks only whether the skill fires, and file tools let the agent explore at full price — one near-miss with `Read`, `Glob`, and `Grep` cost $0.97 on its own.

### `graders/output.md` — trigger case

```md
---
type: llm
---

Lists every changed file with a one-line risk note, and ends with a merge recommendation of approve, approve-with-changes, or block.
```

Write criteria as properties of the final message an observer can check — "lists every changed file with a risk note", never "is a good review". A judge model votes three times; the majority wins.

For an exact part — a heading, a signature line, a fixed phrase — use a `regex` grader, which costs nothing and never wavers:

```md
---
type: regex
pattern: '^## Risks'
flags: m
match: contains
---
```

## Baseline Before Drafting

```bash
bash scripts/run-evals.sh <path-to-new-skill> --baseline [--runs N] [--model MODEL] [--keep-temp]
```

`--baseline` runs the trigger and output cases' output checks with no skill loaded, so it needs only `assets/evals/` and runs before `SKILL.md` exists. It drops each case's `tool_used` grader, skips near-misses, and strips a leading `/<skill-name>` from a user-invoked case's prompt. Each case prints `SKILL HAS A JOB` (plain Claude missed a check) or `PLAIN CLAUDE PASSES`, followed by one verdict line.

A case plain Claude passes is a job the skill does not have. Keep it only when the user wants the behaviour pinned down anyway — as a regression guard, say — and tell them the skill adds nothing there today. The fallback cannot grade output, so it prints each baseline output beside its criteria for you to judge.

## Running

```bash
bash scripts/run-evals.sh <path-to-new-skill> [--runs N] [--model MODEL] [--max-cost-usd USD] [--fallback] [--keep-temp]
```

The script:

1. Copies the skill into a throwaway plugin wrapper, minus its `assets/evals/`, so the skill under test never sees the answer key. A bare skill folder handed to `claude plugin eval` resolves no plugin and silently scores the baseline — the wrapper is what makes the run test anything.
2. Uses `claude plugin eval` when the account has it (early access, Claude Code 2.1.269 or later), keeping the report local.
3. Otherwise falls back to `claude -p`: triggering is checked on every case, and each output is printed beside its criteria for you to grade.
4. Exits 3 when no Claude Code CLI is installed — tell the user the cases are written but unrun.

Read the exit code from the script itself: `run-evals.sh … | tail` reports `tail`'s exit code, which is 0 even when a case failed.

A run costs roughly $0.13 per case per run, baseline arm included; the default is 3 runs. Triggering varies run to run, so use `--runs 1` while iterating and the default for the final pass. The cost ceiling is checked before each run starts and the script runs four at once, so a pass can overshoot it by up to four runs' cost.

The script passes `--trust-plugin` because the wrapper holds a skill you wrote this session. Run it only on skills you wrote or reviewed.

## Reading a Failure

| Symptom | Fault | Fix |
|---|---|---|
| Trigger case: skill did not fire | The description lacks the user's words for this request | Add the missing keyword or context to the description's second sentence |
| Fires in some runs, not others | The description is borderline for this request | Treat it as a trigger failure |
| Near-miss case: skill fired | The description is too broad or overlaps a neighbour | Narrow the description; name the neighbour in `When Not to Use` |
| Skill fired, output failed | The instructions | Sharpen the step that produces the failing property |
| Output passes without the skill too | The skill adds nothing for this request | Find what the skill should do that the default does not, or drop the use case with the user's agreement |

Read the transcript of a failing run, not just its score — it shows where the agent went instead: a skill never opened, a reference skipped, a step misread. `claude plugin eval` deletes each run's sandbox, transcript included, when the run ends, so re-run the failing case with `--keep-temp`: the script keeps the sandboxes and lists the transcript of every failed run. The transcript holds every message the agent wrote, the last of them the one the judge graded; the judge itself records only its votes. The fallback always writes `<case>-<run>.jsonl` beside its results.

When the skill will run on more than one model, re-run the final pass with `--model <model>` for each — wording that lands on a large model can need more detail for a small one.

Change one thing per round and re-run. Fix the skill, not the case: a case changes only when the user changes the use case. After three rounds without progress, stop and report the still-failing cases and what each round tried.
