# Measurement Planning

## Why Plan Before Tracking

Unplanned tracking fills GA4 with events nobody queries.
Planning forces you to connect every event to a decision — if you can't name the decision, don't build the event.

---

## Measurement Plan Template

Fill this out before writing any tracking code for a new feature or flow.

```
Feature / Flow:   _______________

Business Question:
  "We want to know _______ so we can decide _______"

Audience:
  Who reads this report? (PM / Dev / C-level / Marketing)

Success Metric:
  What number moves if this is working?
  e.g. "% of users who complete the flow within 7 days"

Events Required:
  | Event Name       | Trigger                  | Key Parameters       |
  |------------------|--------------------------|----------------------|
  |                  |                          |                      |

Funnel Steps (if applicable):
  Step 1: [user action] → Event: [event_name]
  Step 2: ...
  Step N: [conversion]  → Event: [event_name]  ← mark the goal

Drop-off Points to Watch:
  - Between step X and Y because _______________

Segmentation Needed:
  - plan (always)
  - (add product-specific dimensions)

What We Will NOT Track:
  - _______________ — reason: not actionable
  - _______________ — reason: PII risk
```

---

## Event Priority Framework

When you have more events than time, prioritize in this order:

| Priority | Type | Rationale |
|---|---|---|
| P1 | Funnel conversion events | Direct revenue / activation impact |
| P1 | Error events | Prevent abandonment, fix bugs faster |
| P2 | Feature adoption events | Inform roadmap decisions |
| P2 | Drop-off signals | Explain funnel gaps |
| P3 | Engagement depth | Nice-to-have retention signals |
| P3 | Performance events | UX quality baseline |

Build P1 first. Always.

---

## Question Bank by Audience

Use these to pressure-test whether your event design is complete.

### C-level / Executive
- What is our activation rate this month vs last month?
- Which acquisition channels produce users who actually activate?
- What % of activated users are still active at 30 days?

### PM / Product
- Where in [flow] do users drop off, and what step?
- Which features are used by >50% of [plan] users?
- Which features are shipped but barely adopted?
- What do users do right before they upgrade?

### Dev / Engineering
- Which API endpoints have the highest error rate?
- What % of sessions encounter an error?
- What is p95 load time for [page]?
- Which errors appear most before a flow abandonment?

### Marketing / Growth
- Which channels produce users with the highest activation rate?
- What is the conversion rate from trial to paid by channel?

---

## Taxonomy Governance Rules

1. **New events need a plan entry** — no ad-hoc events in PRs
2. **Event names are reviewed before merging** — check against naming convention
3. **Deprecated events are logged** — never just deleted (breaks historical data)
4. **Parameter names are consistent** — `item_type` not `itemType` or `type`
5. **One person owns the taxonomy** — PM or analytics engineer

All events live in `ANALYTICS_CONTEXT.md` — it is the source of truth.
