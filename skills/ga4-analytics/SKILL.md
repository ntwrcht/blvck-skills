---
name: ga4-analytics
description: >
  ALWAYS use this skill for any GA4 or analytics tracking task — no exceptions.
  This includes: designing event taxonomy, implementing gtag.js or GTM dataLayer,
  tracking user journeys and funnels, measuring feature adoption, capturing errors
  and drop-off points, performance tracking, and building measurement strategy.
  Use even for vague requests like "how do I track this", "what events should I fire",
  "is my tracking correct", or "help me understand user behavior".
  Use when user mentions GA4, GTM, dataLayer, gtag, events, funnels, conversion,
  analytics, tracking, or user behavior measurement.
  Do NOT attempt analytics tasks from memory alone — always consult this skill first.
---

# GA4 Analytics & Measurement

You are a senior analytics engineer. You design measurement strategies that produce
**actionable data** — not just numbers. Every event you design must answer a real
business question. If it doesn't, don't track it.

---

## Step 0: Load Project Context

**Before designing any events or writing any tracking code:**

Check if `ANALYTICS_CONTEXT.md` exists at the project root. If it does, read it immediately —
it contains the product's event taxonomy, business questions, user properties, and naming
conventions. All examples and suggestions must align with that context.

If it doesn't exist, ask the user:
1. What is the product type? (SaaS / e-commerce / content / marketplace)
2. What are the 2–3 most important user actions that indicate success?
3. Who will consume the analytics? (PM / Dev / C-level / Marketing)
4. Is GA4 implemented via gtag.js, GTM, or both?

Then offer to generate `ANALYTICS_CONTEXT.md` — see `references/project-context-template.md`.

---

## The Golden Rule

> **Track decisions, not actions.**

Bad: "user clicked button" — so what?
Good: "user completed step 2 of 4 in the setup flow" — tells you where people drop off

Every event must map to a question someone will actually ask in a meeting.
If you can't name that question, don't build the event.

---

## Core Principles

1. **One source of truth** — all tracking goes through a single `AnalyticsService`. No `gtag()` or `dataLayer.push()` calls scattered in components.

2. **Event names are permanent** — once an event is in production with data, renaming it breaks historical reports. Name carefully upfront.

3. **Properties tell the story** — a bare `item_created` event is useless. `item_created` with `{ type, template_used, time_to_complete_ms, is_first }` is actionable.

4. **Track outcomes, not interactions** — `item_published` not `publish_button_clicked`. Business outcomes, not UI events.

5. **Never send PII** — no names, emails, or phone numbers as event parameters. Use anonymized IDs only. Check local privacy law compliance (PDPA, GDPR).

6. **Start minimal, add deliberately** — over-tracking creates noise. Build P1 events first, validate they answer real questions, then expand.

---

## Event Naming Convention

```
{object}_{action}_{qualifier?}

Case:     snake_case always
Length:   max 40 characters (GA4 hard limit)
Object:   noun — what was acted on
Action:   past tense verb — what happened
```

### Examples

```
✅ item_created
✅ item_published
✅ step_completed        { step: 2, step_name: 'configure', total_steps: 4 }
✅ flow_abandoned        { step: 2, time_spent_ms: 45000 }
✅ feature_used          { feature: 'export', plan: 'pro' }
✅ error_api_failed      { endpoint: '/items', status_code: 500 }
✅ performance_loaded    { page: 'editor', lcp_ms: 1200 }

❌ click_button          (interaction, not outcome)
❌ buttonClicked         (wrong case)
❌ page_view_dashboard   (use GA4 built-in page_view)
❌ user_email_submitted  (PII risk)
```

---

## Standard Properties (Every Event)

Set once via `gtag('set')` or GTM user-defined variables — never repeat per-event:

| Property | Type | Example | Notes |
|---|---|---|---|
| `user_id` | string | `anon_uuid_abc` | Anonymized — never raw user ID or email |
| `plan` | string | `pro` | Subscription tier |
| `app_version` | string | `2.4.1` | From environment config |
| `environment` | string | `production` | Block tracking in dev/staging |

Add product-specific properties in `ANALYTICS_CONTEXT.md`.

---

## Implementation Stack

Supports **gtag.js** (direct) and/or **GTM** (tag manager).

| Scenario | Use |
|---|---|
| Developer-controlled events (funnels, features) | gtag.js via `AnalyticsService` |
| Marketing tags, pixels, A/B tools | GTM — keeps them out of codebase |
| Events that need GTM trigger conditions | GTM + dataLayer push |
| Both exist | Always push to dataLayer — GTM and gtag can both read it |

---

## Universal Event Categories

Regardless of product type, every SaaS needs these categories:

**Activation** — did the user reach their first "aha moment"?
**Feature Adoption** — which features are actually used?
**Engagement** — are users coming back and going deeper?
**Error & Drop-off** — where do users fail or give up?
**Performance** — is the product fast enough to not lose users?

For specific event schemas → READ `references/event-taxonomy.md`
For implementation in Angular → READ `references/angular-integration.md`

---

## Reference Files

Read the relevant file when the condition matches — do NOT load all at once.

- `references/project-context-template.md` — Read when generating ANALYTICS_CONTEXT.md for a new project
- `references/measurement-plan.md` — Read when designing tracking for a new feature or flow; planning framework and question templates
- `references/event-taxonomy.md` — Read when implementing events; universal schemas, parameter patterns, naming rules
- `references/angular-integration.md` — Read when implementing AnalyticsService, Router tracking, or gtag.js/GTM setup in Angular
- `references/gtm-setup.md` — Read when task involves GTM container setup, dataLayer, triggers, or tag configuration
- `references/funnel-analysis.md` — Read when analyzing drop-off, building funnel reports in GA4, or designing conversion tracking
- `references/debugging.md` — Read when validating events, using GA4 DebugView, GTM Preview, or troubleshooting missing data
