# Improving an Existing Skill

**Load this when** the input is a skill that already exists — the user asks to review, improve, upgrade, or fix one — or **Should It Exist** recommended extending one.

One rule sits above the rest: the skill's current eval score is the floor. Every change keeps every case that passed before passing after.

## 1. Read and Summarize

Read `SKILL.md`, every bundled file, and the target's instructions. Give the user a summary before any finding: what the skill does, who fires it (model or user), its workflow in a few lines, and what it produces and consumes. Findings come after, so the user can correct your reading of the skill first.

## 2. Pin the Current Behaviour

- If the skill has `assets/evals/`, run `bash scripts/run-evals.sh <skill-dir>`; its score is the before-score.
- If it has none, infer the use cases from the description and body and confirm them in one round in the house style, each question pre-filled with the case you inferred so the user corrects rather than composes. Write the cases per `evals.md`, then run them.
- Run `bash scripts/run-evals.sh <skill-dir> --baseline` as well: a trigger case plain Claude passes is a job the skill does not have.

Record the before-score for every case.

## 3. Find

Check in this order; the order is also the ranking, most user-visible first.

1. **Eval failures** — a trigger case that does not fire, a near-miss that does, an output check that fails.
2. **No-job cases** — the baseline passes, so the skill spends context and adds nothing there.
3. **Overlap** — for each trigger case, the neighbouring skill that would also fire.
4. **Description** — the **Description Format** rules, and `bash scripts/check-skill.sh <skill-dir>`.
5. **Portability** — paths outside the folder, assumptions that hold in one repo only.
6. **Sentence pass** — the thirteen rules in **Writing the Instructions**.
7. **Failure modes** — sediment, sprawl, duplication, no-ops, and vague completion criteria (`principles.md`).

Give every finding its evidence: an eval case, a `file:line`, or a quoted sentence. Drop a finding you cannot back with evidence.

## 4. Report

One table, ranked in the order above:

| # | Finding | Evidence | Fix | What the fix loses |
|---|---|---|---|---|
| 1 | Near-miss "explain this git error" fires the skill | `nearmiss-explain-git-error`: fired 3 of 3 runs | Narrow the description's second sentence; name the neighbour in `When Not to Use` | Nothing |

End with one question: which finding to fix first, with your recommendation.

## 5. Apply, One at a Time

Fix one finding, re-run the evals, and show the result beside the before-score. Wait for approval before the next finding. When the user asks to batch, apply the findings they name together and re-run once.

A case that passed before and fails now is a regression: revert or rework that change before anything else. A case itself changes only when the user changes the use case.

Follow the target's instructions for anything a fix touches outside the skill — a catalog description, a manifest entry.

## 6. Close

Show the before/after table — every case with its before-score and after-score — and list each finding left unfixed with its reason.
