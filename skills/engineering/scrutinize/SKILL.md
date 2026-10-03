---
name: scrutinize
description: "Reviews a pasted diff, PR, plan, or design doc from an external verification stance, checking correctness, simpler alternatives, and rollout risk. Use when the user hands over a change to look over or poke holes in before merging, a plan to pressure-test, or code paths, edge cases, and tests to verify."
---

# Scrutinize

Stand outside the proposal and verify whether it should exist, whether it works, and whether a smaller path would serve the goal.

## When to Use

Use this skill for review requests: plans, PRs, diffs, design docs, architecture proposals, implementation approaches, risky changes, or "scrutinize this" prompts. It is the default for stack-neutral review — correctness, simpler alternatives, evidence, and rollout risk.

## When Not to Use

- **Reviewing the current branch in a Claude Code session** — the host's built-in `/code-review` scopes the local diff itself. This skill takes a diff, PR, plan, or design doc the user hands over.
- **Live bug investigation** — use `debug`. This skill reviews a proposal; it does not chase a failure.
- **The goal itself is unclear and there is no artifact to review yet** — use `grilling` to interview the user first.
- **The review is specifically about what an attacker could do** — use `security-audit`. It asks about exploitability and impact; this skill asks whether the change is correct and whether a smaller path exists.
- **A deep framework-level review inside one stack** — the matching engineer skill (`angular-engineer`, `next-engineer`, `supabase-engineer`) carries its own review reference and stack conventions. Use this skill when the review does not depend on framework specifics.

## Artifacts

- Produces: review notes at the `scrutiny` key path — see `references/artifact-paths.md` (default `.context/scrutiny.md`, or `.context/scrutiny-<slug>.md` per topic, on request)
- Consumes: artifact under review (plan, PR, diff, or design doc)

## Core Rule

Find the shortest defensible path from intent to evidence. Separate what the artifact claims from what you verified.

## Workflow

1. **Scope, then state intent.** If no artifact was handed over, look for one with `git diff --stat`, staged changes, and the branch's commits; if all are empty, say so and ask for a diff, PR, commit range, or plan rather than reviewing nothing. If the change exceeds 500 lines, list each file with a one-line risk note first, then review in batches by feature area, riskiest first. Then summarize the goal in one sentence. If the goal is missing or contradictory, lead with that and stop deep review until it is clarified.
2. **Check alternatives.** Ask whether doing nothing, reusing an existing pattern, changing config, narrowing scope, or solving at a different layer would satisfy the goal with less risk. When the artifact under review is an interface or module boundary, judge it with `codebase-design`'s vocabulary — depth, seam placement, leverage, locality — and reach for its Design It Twice path if the shape itself is the open question. When the change leaves code unused, call it `delete now` or `defer with a plan` per `references/removal-plan.md`.
3. **Trace behavior.** Follow real paths through changed and unchanged code: entry points, call sites, branches, state mutation, outputs, side effects, and external contracts. For plans, trace proposed flow against the current system.
4. **Verify claims.** Test each claim against inputs, edge cases, empty/nil states, retries, partial failures, concurrency, ordering, performance, observability, persistence, and API contracts. For code, walk each changed function through `references/verification-checklist.md`: failure paths, boundaries, and cost at scale.
5. **Inspect tests.** Confirm tests exercise the traced path and would fail for the important regression. Call out mocks or assertions that bypass the behavior.
6. **Report findings first.** Order by severity, P0 first. Keep summary secondary.

## Finding Format

Label every finding with one severity:

| Severity | Meaning | Example |
|---|---|---|
| **P0** | Wrong result, data loss, or money or access lost in normal use | A balance check and deduction that two requests can both pass |
| **P1** | Breaks on a realistic edge case, regresses performance, or a test misses the main path | An empty list that crashes the handler |
| **P2** | Maintainability cost or a gap worth a follow-up | Dead code left behind by the change |
| **P3** | Optional polish | A clearer name |

For each issue include:

- Finding: `P0`–`P3`, then one specific sentence with file, line, path, symbol, or artifact reference.
- Why it matters: concrete consequence.
- Evidence: trace, input, state, or claim that exposes it.
- Suggested change: minimal correction.

Close with a line starting `Verdict:` — one of `ship`, `fix then ship`, `rework`, or `reject`, plus the main reason. The highest severity sets it: any P0 → `rework` or `reject`; any P1 → `fix then ship`; only P2 or P3 → `ship`.

## Operating Rules

- No rubber stamps. If no issues are found, state what was traced and what risk remains.
- Cite local file paths or symbols for code claims.
- Do not pad with style nits when structural risk exists.
- Do not rewrite the artifact unless the user asks for edits.
- Prefer concise, actionable findings over broad critique.
- For local files, use clickable file links when practical.

## Optional Artifact

Default to chat output. If the user asks to persist or hand off context, write to the `scrutiny` key path — see `references/artifact-paths.md` (default `.context/scrutiny.md`, or `.context/scrutiny-<pr-or-topic>.md` when a PR, design, or topic is clear). Ask before overwriting unrelated context.

## Reference Map

- `references/verification-checklist.md`: load in step 4 for code changes — swallowed errors, partial writes, edge values, and N+1 or unbounded growth.
- `references/removal-plan.md`: load when the change leaves code unused or a smaller path would delete code — the delete-now test and the defer-with-a-plan fields.

## Next Step

Route by the verdict closed out in the Finding Format section above.

- **If `ship`:** return to whichever stage the reviewed artifact was headed toward — implementation, testing, or ship.
- **If `fix then ship`, `rework`, or `reject`:** send the findings back to the artifact's owner skill (e.g. `write-a-prd`, `write-a-story`, `tdd`, or the relevant implementation skill) for revision, then re-run `scrutinize`.

---

_Verification checklist and removal plan adapted from the `code-review-expert` skill in `sanyuan-skills`, MIT-licensed © 2025 sanyuan0704._
