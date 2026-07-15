---
name: scrutinize
description: "Reviews plans, PRs, diffs, design docs, and code changes from an external verification stance. Use when pressure-testing intent, simpler alternatives, traced code paths, behavioral claims, edge cases, tests, or rollout risk."
---

# Scrutinize

Stand outside the proposal and verify whether it should exist, whether it works, and whether a smaller path would serve the goal.

## When to Use

Use this skill for review requests: plans, PRs, diffs, design docs, architecture proposals, implementation approaches, risky changes, or "scrutinize this" prompts. It is the default for stack-neutral review — correctness, simpler alternatives, evidence, and rollout risk.

## When Not to Use

- **Live bug investigation** — use `debug-mantra`, or `diagnose` for a hard one. This skill reviews a proposal; it does not chase a failure.
- **The goal itself is unclear and there is no artifact to review yet** — use `grilling` to interview the user first.
- **The review is specifically about what an attacker could do** — use `security-audit`. It asks about exploitability and impact; this skill asks whether the change is correct and whether a smaller path exists.
- **A deep framework-level review inside one stack** — the matching engineer skill (`angular-engineer`, `python-engineer`, `strapi-engineer`) carries its own review reference and stack conventions. Use this skill when the review does not depend on framework specifics.

## Artifacts

- Produces: review notes at the `scrutiny` key path — see `references/artifact-paths.md` (default `.context/scrutiny.md`, or `.context/scrutiny-<slug>.md` per topic, on request)
- Consumes: artifact under review (plan, PR, diff, or design doc)

## Core Rule

Find the shortest defensible path from intent to evidence. Separate what the artifact claims from what you verified.

## Workflow

1. **State intent.** Summarize the goal in one sentence. If the goal is missing or contradictory, lead with that and stop deep review until it is clarified.
2. **Check alternatives.** Ask whether doing nothing, reusing an existing pattern, changing config, narrowing scope, or solving at a different layer would satisfy the goal with less risk.
3. **Trace behavior.** Follow real paths through changed and unchanged code: entry points, call sites, branches, state mutation, outputs, side effects, and external contracts. For plans, trace proposed flow against the current system.
4. **Verify claims.** Test each claim against inputs, edge cases, empty/nil states, retries, partial failures, concurrency, ordering, performance, observability, persistence, and API contracts.
5. **Inspect tests.** Confirm tests exercise the traced path and would fail for the important regression. Call out mocks or assertions that bypass the behavior.
6. **Report findings first.** Order by severity. Keep summary secondary.

## Finding Format

For each issue include:

- Finding: one specific sentence with file, line, path, symbol, or artifact reference.
- Why it matters: concrete consequence.
- Evidence: trace, input, state, or claim that exposes it.
- Suggested change: minimal correction.

Close with one verdict: `ship`, `fix then ship`, `rework`, or `reject`, plus the main reason.

## Operating Rules

- No rubber stamps. If no issues are found, state what was traced and what risk remains.
- Cite local file paths or symbols for code claims.
- Do not pad with style nits when structural risk exists.
- Do not rewrite the artifact unless the user asks for edits.
- Prefer concise, actionable findings over broad critique.
- For local files, use clickable file links when practical.

## Optional Artifact

Default to chat output. If the user asks to persist or hand off context, write to the `scrutiny` key path — see `references/artifact-paths.md` (default `.context/scrutiny.md`, or `.context/scrutiny-<pr-or-topic>.md` when a PR, design, or topic is clear). Ask before overwriting unrelated context.

## Next Step

Route by the verdict closed out in the Finding Format section above.

- **If `ship`:** return to whichever stage the reviewed artifact was headed toward — implementation, testing, or ship.
- **If `fix then ship`, `rework`, or `reject`:** send the findings back to the artifact's owner skill (e.g. `write-a-prd`, `write-a-story`, `tdd`, or the relevant implementation skill) for revision, then re-run `scrutinize`.
