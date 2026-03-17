# Event Taxonomy Reference

This file defines universal event schemas for SaaS products.
**Project-specific events and parameters live in `ANALYTICS_CONTEXT.md`** — always read that first.

---

## Naming Convention

```
{object}_{action}_{qualifier?}

snake_case always | max 40 chars | past-tense action verbs
```

---

## Standard Properties (Every Event)

Set via `gtag('set')` or GTM user-defined variable — never repeat per-event call:

| Property | Type | Notes |
|---|---|---|
| `user_id` | string | Anonymized — never email or raw DB ID |
| `plan` | string | Subscription tier: free / pro / enterprise |
| `app_version` | string | Semver from environment config |
| `environment` | string | `production` only — block in dev/staging |

---

## Universal Event Schemas

### Activation

#### `user_registered`
Trigger: User completes signup successfully

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `registration_source` | string | yes | `organic` / `invite` / `google_oauth` |
| `plan_selected` | string | yes | Initial plan chosen |

---

#### `onboarding_step_completed`
Trigger: User completes a step in a guided onboarding sequence

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `step` | number | yes | Step number (1-based) |
| `step_name` | string | yes | Human-readable step identifier |
| `total_steps` | number | yes | Total steps in this onboarding |
| `time_spent_ms` | number | no | Time on this step |

---

#### `activation_completed`
Trigger: User reaches the product's defined activation milestone
(Define what "activated" means in `ANALYTICS_CONTEXT.md`)

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `days_since_registered` | number | yes | How long activation took |
| `steps_completed` | number | yes | Onboarding steps finished before activating |
| `source` | string | no | What triggered activation (e.g. `invite`, `self`) |

---

### Feature Adoption

#### `feature_viewed`
Trigger: User navigates to a feature for the first time in a session

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `feature` | string | yes | Feature identifier — consistent slug |
| `source` | string | yes | How they got there: `sidebar` / `onboarding` / `search` |
| `is_first_time` | boolean | yes | First time ever, or just this session |

---

#### `feature_used`
Trigger: User performs the primary action of a feature (not just views it)

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `feature` | string | yes | Feature identifier |
| `action` | string | yes | Specific action: `create` / `export` / `share` |
| `plan` | string | yes | User's plan at time of use |

---

#### `upgrade_prompted`
Trigger: User hits a paywall or plan limit

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `feature` | string | yes | Feature that triggered the prompt |
| `current_plan` | string | yes | User's current plan |
| `limit_type` | string | yes | `item_count` / `feature_gated` / `usage_limit` |

---

### Flow & Funnel

#### `step_completed`
Trigger: User completes a step in a multi-step flow

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `flow` | string | yes | Flow identifier: `onboarding` / `setup` / `checkout` |
| `step` | number | yes | Step number (1-based) |
| `step_name` | string | yes | Descriptive step name |
| `total_steps` | number | yes | Total steps in this flow |
| `time_on_step_ms` | number | yes | Time spent on this step |

---

#### `flow_abandoned`
Trigger: User leaves a multi-step flow without completing it
Fire on: route change away from flow, or session end while on a flow step

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `flow` | string | yes | Flow identifier |
| `step` | number | yes | Last step reached |
| `step_name` | string | yes | Name of last step reached |
| `total_steps` | number | yes | |
| `completion_pct` | number | yes | `step / total_steps * 100` |
| `time_spent_ms` | number | yes | Total time in the flow |

---

### Errors

#### `error_api_failed`
Trigger: API call returns non-2xx response that affects the user experience

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `endpoint` | string | yes | Path only, no domain: `/items` |
| `method` | string | yes | `GET` / `POST` / `PUT` / `DELETE` |
| `status_code` | number | yes | HTTP status |
| `user_action` | string | yes | What the user was trying to do |
| `retry_count` | number | yes | `0` if first attempt |

---

#### `error_ui_crashed`
Trigger: Uncaught JS error (from GlobalErrorHandler)

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `component` | string | yes | Component name where error occurred |
| `error_type` | string | yes | `TypeError` / `HttpError` etc. |
| `error_message` | string | yes | Sanitized — no user data, max 100 chars |
| `page_path` | string | yes | Current route path |

---

### Performance

#### `performance_loaded`
Trigger: Page navigation complete (once per route change)

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `page` | string | yes | Normalized page name (no IDs) |
| `lcp_ms` | number | yes | Largest Contentful Paint |
| `ttfb_ms` | number | yes | Time to First Byte |
| `fid_ms` | number | no | First Input Delay |
| `cls_score` | number | no | Cumulative Layout Shift |

---

#### `performance_api_slow`
Trigger: API call exceeds defined threshold (recommended: 2000ms)

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `endpoint` | string | yes | Path only |
| `method` | string | yes | HTTP method |
| `duration_ms` | number | yes | Actual duration |
| `threshold_ms` | number | yes | Threshold that was exceeded |
| `user_action` | string | yes | Context of the slow call |

---

## Parameter Best Practices

```typescript
// ✅ Use null for optional params that have no value — undefined is dropped by GA4
{ template_used: selectedTemplate ?? null }

// ✅ Normalize IDs out of page paths for performance tracking
'/items/abc-123-xyz/edit' → 'item_editor'

// ✅ Boolean values for first-time flags
{ is_first_publish: true }

// ✅ Timestamps in milliseconds
{ time_to_complete_ms: Date.now() - startTime }

// ❌ Never send raw user data
{ user_email: user.email }   // PDPA / GDPR violation
```

---

## Deprecated Events

| Event | Deprecated | Replaced By | Notes |
|---|---|---|---|
| — | — | — | None yet |

When deprecating: stop firing, add row here, never delete.
