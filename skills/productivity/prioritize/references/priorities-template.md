# Priorities Template

Use this structure for the artifact at the `priorities` key path.

```md
# Priorities — <topic>

**Frame:** Reach window: <period> · Impact metric: <metric> · Effort unit: <unit> · Scored: <date>
**Candidates:** <n>, from <sources>

## Ranking

| # | Item | Reach | Impact | Confidence | Effort | RICE | Flags |
|---|---|---|---|---|---|---|---|
| 1 | <item> | <n> | <score> | <%> | <n> | <score> | fragile / tie |

## Assumptions Ledger

One row per assumption, in the order it affects the ranking most.

| Item | Factor | Assumed | What would replace it with a fact |
|---|---|---|---|
| <item> | Reach | <the assumption> | <the metric, query, or question> |

## Evidence

One row per sourced factor. Item, factor, value, source (metric name, PRD path, finding id, ticket count, estimate owner).

## Fragile Items

For each flagged item: which assumption its place depends on, where it moves if that assumption is wrong, and which item takes its place.

## Not Ranked

Items dropped or merged during collection, with the reason.
```
