# RICE Scales

One fixed scale per factor. Every item in a table uses the same four scales, so scores compare. Change a scale only for the whole table, and record the change in the artifact's frame block.

## Reach

How many people or events the item affects in the frame's time window. A **count**, taken from a metric, a ticket volume, a segment size, or a discovery finding's evidence count. Record the number and its source.

When the count is not available, write `assumption: <the estimate and what it rests on>`. That triggers the Confidence cap below.

## Impact

How much the item moves the frame's impact metric for each person or event it reaches.

| Score | Meaning |
|---|---|
| 3 | Massive — the metric moves for everyone reached; the item is the mechanism |
| 2 | High — a clear, direct contribution |
| 1 | Medium — a noticeable contribution among several |
| 0.5 | Low — a small or indirect contribution |
| 0.25 | Minimal — hard to see in the metric at all |

The source is the mechanism: how a user getting this item shows up in the metric. A PRD's Success Metrics section or a discovery finding's desired outcome usually names it. No mechanism means `assumption`.

## Confidence

How sure the scorer is about Reach and Impact together.

| Score | Meaning |
|---|---|
| 100% | Both Reach and Impact rest on measured data or shipped precedent |
| 80% | One factor measured, the other backed by qualitative evidence |
| 50% | Both factors backed by evidence, none of it quantitative |
| 20% | At least one factor is an assumption with no evidence behind it |

**Cap rule:** an `assumption` on Reach or Impact caps Confidence at 50%; an assumption with nothing behind it caps it at 20%. Confidence is where unsupported factors show up in the score, so it is never raised to reflect enthusiasm.

## Effort

Total cost to ship, in the frame's unit (default person-weeks): design, build, test, and rollout together. Use a range from the owning engineer or engineering skill when one exists, and score with the midpoint. A guess is `assumption`. Minimum 0.5 — an effort of zero makes the score infinite and the table meaningless.

## Score

RICE = Reach × Impact × Confidence ÷ Effort. Rank descending. Report ties as ties when the difference is smaller than the uncertainty in the assumptions behind it.
