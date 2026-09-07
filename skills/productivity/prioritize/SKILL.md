---
name: prioritize
description: "Ranks candidate backlog items with RICE — Reach, Impact, Confidence, Effort — scoring each factor from cited evidence or a labelled assumption on one fixed scale, and producing a ranked table the team can argue with. Use when prioritizing a backlog, ranking features or stories, deciding what to build next, comparing candidates for a sprint or quarter, or re-scoring after new evidence."
argument-hint: "<candidate items, or the stories/PRDs to rank> [time window]"
---

# Prioritize

Rank candidates by **RICE** and show the working. The output is not the order — it is the order plus the assumptions that produced it, so the team argues with the assumptions instead of the ranking.

## When to Use

Use this skill when there are several candidate items and a decision about which come first: a backlog to rank, features competing for a quarter, stories competing for a sprint, a roadmap review, or a re-score after new evidence changed a factor. Inputs can be stories from `write-a-story`, PRDs from `write-a-prd`, discovery findings from `discovery-synthesis`, or a list the user pastes.

## When Not to Use

- **One item, and the question is whether it is ready** — use `write-a-story`'s readiness check. This skill compares; it does not refine.
- **The outcome itself is undecided** — use `grilling`. RICE ranks means toward an agreed outcome; it cannot pick the outcome.
- **Incoming tracker issues need a category and a state, not a rank** — use `triage`.
- **Effort needs a real engineering estimate** — ask the owning engineering skill for a range, then come back. This skill records the estimate; it does not produce one.

## Artifacts

- Produces: ranked table at the `priorities` key path — see `references/artifact-paths.md` (default `docs/priorities/<slug>.md`)
- Consumes: stories at the `story` key path, PRDs at the `prd` key path, findings at the `discovery` key path (each if present), `.context/project.md`, `.context/analytics.md`
- Bundled: `references/rice-scales.md` — the fixed scales and the assumption rules; `references/priorities-template.md` — the output structure

## Core Rule

Every score traces to a source or is labelled an assumption. A number with no source is an assumption, and an assumption is shown in the table next to the score it produced — never absorbed into the score. Confidence is where unsupported factors show up: it drops when Reach or Impact rests on an assumption.

## Workflow

1. **Collect the candidates.** Gather them from the named files or the user's list. Normalise each to one line: a name and the outcome it claims. Merge duplicates and split anything that is really two items. Confirm the list before scoring — scoring the wrong set wastes every step after.
2. **Fix the frame.** Three settings decide comparability, so settle them once, up front, with a recommended answer for each: the time window Reach counts over (default: one quarter), the metric Impact is judged against (default: the North Star or L1 metric the items share — read `.context/analytics.md` or the PRDs' Success Metrics), and the unit Effort is counted in (default: person-weeks). Load `references/rice-scales.md`.
3. **Score each factor with its source.** For every item and every factor, record the value, the scale step it maps to, and where the value came from — a metric, a PRD, a discovery finding, a ticket count, an engineer's estimate, or `assumption: <what was assumed>`. Look facts up before asking; ask only for values the environment cannot supply.
4. **Compute RICE** as Reach × Impact × Confidence ÷ Effort, and rank.
5. **Test the order.** For each of the top items, ask which single assumption, if wrong, would move it down, and which item below it would move up. Items whose place depends on one assumption get a **fragile** flag.
6. **Write the table** to the `priorities` key path using `references/priorities-template.md`.
7. **Report:** the top items, the three assumptions that most affect the order, and the evidence that would raise confidence on each fragile item.

## Operating Rules

- Use the fixed scales in `references/rice-scales.md`. A custom scale for one item makes the whole table incomparable.
- Counts over adjectives: Reach is a number in the window, never "many users".
- Effort includes the whole cost to ship — design, build, test, rollout — not build alone.
- Show ties as ties. A difference smaller than the assumptions behind it is not an order.
- Leave tracker priority fields alone. When the user wants the ranking written into a tracker, hand the approved order to `write-a-story`, which owns the payload approval flow.

## Reference Map

- `references/rice-scales.md`: the Reach, Impact, Confidence, and Effort scales, what each step means, and the rule that caps Confidence when a factor is assumed.
- `references/priorities-template.md`: the ranked-table structure, the assumptions ledger, and the fragile-item section.

## Review Checklist

- Does every factor on every item carry a source or an explicit assumption?
- Is Confidence capped wherever Reach or Impact is assumed?
- Are the frame settings (window, impact metric, effort unit) stated at the top of the artifact?
- Are fragile items flagged, with the assumption that makes them fragile?
- Would a reader who disagrees with the order know exactly which cell to argue with?

## Next Step

The ranking is done when the user has read the assumptions ledger and either confirmed each assumption or replaced it with a fact.

- **If approved:** hand off to `write-a-story` to set priority fields or publish the order to the tracker, and tell the user to run `/subagent-driven-development` when the top items are ready to build.
- **If not approved:** re-score the disputed factor with the new fact and re-rank — do not adjust the order by hand. If the disagreement is about the outcome the items serve rather than a score, stop and escalate to `grilling`.
