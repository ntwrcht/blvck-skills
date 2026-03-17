# Analytics Project Context Template

Copy this file to your project root as `ANALYTICS_CONTEXT.md` and fill it in.
The GA4 skill reads this file at the start of every session.

---

## Product Overview

```
Product name:     _______________
Product type:     SaaS / e-commerce / marketplace / content / other
Tech stack:       Angular / React / Vue / other
GA4 via:          gtag.js / GTM / both
GA4 property ID:  G-XXXXXXXXXX
GTM container:    GTM-XXXXXXX
```

---

## Key Business Questions

List the 3–5 questions that analytics must answer. Every event must trace back to one of these.

```
1. "What % of registered users reach their first [key action] within [N] days?"
2. "Which features drive [retention / upgrade / referral]?"
3. "Where in [main flow] do users drop off?"
4. "Which error types cause the most abandonment?"
5. "..."
```

---

## Activation Definition

The single action that defines an "activated" user — the moment they get real value.

```
Activation event:  _______________    (e.g. item_published, order_placed)
Target timeframe:  ___ days after registration
Healthy rate:      ___% (baseline or target)
```

---

## User Properties

Properties set once on login and attached to every event:

| Property | Values | Notes |
|---|---|---|
| `user_id` | anonymized string | never raw ID or email |
| `plan` | free / pro / enterprise | subscription tier |
| `app_version` | semver string | from environment config |
| (add more) | | |

---

## Event Taxonomy

All events in production. This is the source of truth — add events here before implementing.

### Activation Events

| Event | Trigger | Key Parameters |
|---|---|---|
| `user_registered` | User completes signup | `source`, `plan_selected` |
| (add your activation funnel) | | |

### Feature Adoption Events

| Event | Trigger | Key Parameters |
|---|---|---|
| `feature_viewed` | User opens a feature | `feature`, `source` |
| `feature_used` | User performs main action | `feature`, `action`, `plan` |

### Engagement Events

| Event | Trigger | Key Parameters |
|---|---|---|
| `step_completed` | User completes a flow step | `flow`, `step`, `step_name`, `total_steps` |
| `flow_abandoned` | User leaves a flow early | `flow`, `step`, `completion_pct`, `time_spent_ms` |

### Error Events

| Event | Trigger | Key Parameters |
|---|---|---|
| `error_api_failed` | API returns non-2xx | `endpoint`, `status_code`, `user_action` |
| `error_ui_crashed` | Uncaught JS error | `component`, `error_type`, `error_message` |

### Performance Events

| Event | Trigger | Key Parameters |
|---|---|---|
| `performance_loaded` | Page load complete | `page`, `lcp_ms`, `ttfb_ms` |
| `performance_api_slow` | API exceeds threshold | `endpoint`, `duration_ms`, `threshold_ms` |

---

## Core Funnels

Define the funnels you'll track in GA4 Explore:

### [Name] Funnel
```
Goal:    _______________
Step 1:  event_name  { condition }
Step 2:  event_name  { condition }
...
Step N:  event_name  (conversion)
```

---

## Governance

```
Taxonomy owner:          _______________
Review process:          New events require _______________ before merging
Deprecated events log:   (list here — never delete from this file)
```
