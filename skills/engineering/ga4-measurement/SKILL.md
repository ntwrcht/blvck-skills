---
name: ga4-measurement
description: "Plan, implement, review, and validate GA4/GTM measurement for product flows, funnels, feature adoption, conversion, errors, and performance. Use when designing event taxonomies, dataLayer or gtag tracking, GA4 reports, GTM setup, analytics QA, or measurement plans."
---

# GA4 Measurement

Design GA4 and GTM measurement that answers product and business questions with reliable, privacy-safe event data.

## When to Use

Use this skill when the task involves GA4, Google Tag Manager, gtag.js, dataLayer events, product analytics, event taxonomy, funnel tracking, conversion measurement, feature adoption, error capture, performance events, or analytics validation.

Use it for planning new measurement, reviewing an existing tracking plan, implementing tracking code, defining report inputs, debugging missing events, or deciding what not to track.

## When Not to Use

Use a general debugging skill when the problem is not analytics-specific. Use a frontend or backend engineering skill when the task is only application implementation and does not require measurement design.

Do not invent business goals or activation definitions when the user or project artifacts provide them. If goals are missing, state assumptions before proposing events.

## Artifacts

- Produces: measurement plan at the `analytics` key path — see `references/artifact-paths.md` (default `.context/analytics.md`, on request; same file as the `analytics.md` domain, read-then-update rather than one per feature)
- Consumes: `.context/project.md`, `.context/analytics.md`, `.context/engineering.md`

## Core Rule

Track decisions, not clicks. Every event must answer a real question someone will use to make a product, growth, reliability, or revenue decision.

## Workflow

1. Load local context first. Check `.context/INDEX.md`, then relevant domain files such as `.context/project.md`, `.context/analytics.md`, and `.context/engineering.md`, along with analytics docs, tracking code, GTM snippets, dataLayer conventions, event constants, tests, or dashboards.
2. Define the decision. Write the business question, report audience, success metric, and action the team will take from the data.
3. Identify the flow outcome. Prefer completion, abandonment, error, conversion, adoption, and performance signals over raw UI interactions.
4. Draft the event taxonomy. Use stable `snake_case` names, past-tense actions, and parameters that explain who, what, where, and why without PII.
5. Choose the implementation path. Use a single analytics service or tracking boundary; avoid scattered direct `gtag()` or `dataLayer.push()` calls.
6. Validate end to end. Confirm events fire once, parameters are typed correctly, GTM triggers match intent, GA4 DebugView receives data, and reports can answer the original question.
7. Document assumptions, events, parameters, validation steps, and known gaps.

## Context Setup

If project context exists, read it before designing or changing measurement. Treat `.context/analytics.md` or an existing measurement plan as the source of truth for activation definitions, funnels, event names, and reporting audiences.

If context is missing and the task needs product goals, activation criteria, funnel steps, implementation stack, or reporting audiences, use `skills/productivity/setup-context/references/domains.md` to guide the setup. Ask only for the missing inputs, then either document assumptions in the answer or create context files when the user asks for reusable project documentation.

## Measurement Principles

- Start with P1 events: activation, conversion, funnel completion, abandonment, critical errors, and revenue-impacting actions.
- Keep event names stable; renaming production events breaks historical reporting.
- Use parameters to make events actionable, such as `step_name`, `plan`, `source`, `feature`, `error_type`, `status_code`, `time_to_complete_ms`, or `is_first_time`.
- Block or clearly separate development and staging traffic from production measurement.
- Never send PII such as names, emails, phone numbers, addresses, raw IDs, or free-text user input.
- Use GA4 built-ins such as `page_view` where they fit instead of duplicating them with custom events.

## Naming Convention

```text
{object}_{action}_{qualifier?}

Case: snake_case
Length: max 40 characters
Action: past-tense verb for completed outcomes
```

Examples:

```text
item_created
onboarding_step_completed
activation_completed
checkout_completed
flow_abandoned
api_error_occurred
editor_loaded
```

Avoid names like `button_clicked`, `user_email_submitted`, `pageViewDashboard`, or custom `page_view_*` events that duplicate GA4 defaults.

## Reference Files

Read only the file needed for the task:

- `references/measurement-plan.md` - planning framework, business-question template, and prioritization.
- `references/event-taxonomy.md` - universal SaaS event schemas, parameter patterns, and naming rules.
- `references/angular-integration.md` - Angular AnalyticsService, router tracking, gtag.js, and GTM setup.
- `references/gtm-setup.md` - GTM container setup, dataLayer schema, triggers, variables, and tags.
- `references/funnel-analysis.md` - funnel design, drop-off analysis, conversion reports, and exploration setup.
- `references/debugging.md` - GA4 DebugView, GTM Preview, validation, and missing-event troubleshooting.
- `references/context-template.md` - optional `.context/` domain structure for bootstrapping reusable analytics context.

## Next Step

Do not treat instrumentation as done until the user confirms the event taxonomy and validation results are correct.

- **If approved:** proceed to ship or stakeholder communication — hand off to `stakeholder-update`.
- **If not approved:** return to the implementation skill (`angular-engineer`, `python-engineer`, `strapi-engineer`, or whichever owns the affected code) to close instrumentation gaps, then re-validate with this skill.
