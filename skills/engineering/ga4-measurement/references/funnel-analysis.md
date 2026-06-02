# Funnel Analysis & Drop-off Detection

## Table of Contents
1. Funnel Design Principles
2. Universal Funnel Patterns
3. Building Funnels in GA4
4. Drop-off Analysis Workflow
5. Cohort & Retention Analysis
6. Segment-Based Analysis

---

## 1. Funnel Design Principles

A good funnel has:
- **Clear start and end** — what is the conversion goal?
- **Meaningful steps** — each step represents a real user commitment, not a click
- **No noise steps** — add steps only if drop-off at that point is actionable
- **Consistent user identity** — use `user_id` so users are tracked across sessions

**Anti-patterns:**
- >7 steps — too many to act on, noise obscures signal
- Steps that always complete together — merge them
- Steps defined by UI interactions instead of outcomes

---

## 2. Universal Funnel Patterns

Adapt these to your product using your event names from `ANALYTICS_CONTEXT.md`.

### Activation Funnel
The most important funnel for any SaaS.
Goal: measure how many users reach their first real value moment.

```
Step 1: user_registered
Step 2: onboarding_step_completed  { step: 1 }
Step 3: [first meaningful action]   (product-specific)
Step 4: [setup completion]          (product-specific)
Step 5: activation_completed        ← conversion goal
```

Healthy: 20–40% of registered users activate within 7 days.
Below 10%: onboarding emergency — check steps 2→3 and 4→5 first.

---

### Feature Adoption Funnel
Goal: measure if users who discover a feature actually get value from it.

```
Step 1: feature_viewed   { feature: 'X' }
Step 2: feature_used     { feature: 'X', action: 'primary_action' }
Step 3: feature_used     { feature: 'X', action: 'save_or_complete' }
```

High 1→2 drop: discoverability or value proposition problem.
High 2→3 drop: output quality or UX friction problem.

---

### Setup / Configuration Flow Funnel
Goal: measure completion of multi-step configuration wizards.

```
Step 1: step_completed  { flow: 'setup', step: 1 }
Step 2: step_completed  { flow: 'setup', step: 2 }
...
Step N: [final outcome event]
```

Track `flow_abandoned` alongside — it captures who dropped off and at which step.

---

## 3. Building Funnels in GA4

### Exploration → Funnel Exploration

1. Go to **Explore** → **Funnel exploration**
2. Set **Steps** using event names + parameter filters:
   ```
   Step 1: Event name = user_registered
   Step 2: Event name = activation_completed
   ```
3. Set **Breakdown** dimension: `plan` — always compare plans separately
4. Set **Date range**: 30 days (enough volume, recent enough to be relevant)
5. Enable **Elapsed time** to see how long users take between steps
6. Enable **Trended funnel** to spot if drop-off changed after a release

### Key Metrics to Read

| Metric | What It Tells You |
|---|---|
| Step completion % | Where the biggest drop happens |
| Elapsed time between steps | Where users are stuck or disengaged |
| Breakdown by `plan` | Whether drop-off is plan-specific |
| Trended view | Whether a recent release improved or hurt conversion |

---

## 4. Drop-off Analysis Workflow

When you see high drop-off at a step, follow this sequence:

**1. Quantify**
- What % drops off? (30% = normal, 70% = critical)
- Is it a recent spike or a long-standing pattern? (spike = likely a bug or release regression)

**2. Segment**
- Does drop-off differ by `plan`?
- Does drop-off differ by other product-specific dimensions?
- Is it new users or returning users?

**3. Correlate with errors**
- Check `error_api_failed` firing at the same step
- Check `performance_api_slow` — slow steps cause abandonment
- Check `error_ui_crashed` for the same page/component

**4. Check time on step**
- High `time_on_step_ms` + no errors → UX comprehension problem
- Low `time_on_step_ms` + high drop-off → users bail immediately (value unclear)
- High errors + high drop-off → reliability problem

**5. Hypothesize and act**
- Define the fix as a testable hypothesis
- Add more granular events if needed to validate
- A/B test the fix where possible — don't assume the fix works

---

## 5. Cohort & Retention Analysis

### Activation Cohort

In GA4 **Explore** → **Cohort exploration**:
- **Cohort inclusion**: `user_registered`
- **Return criterion**: `activation_completed`
- **Granularity**: Daily
- **Date range**: Last 90 days

Read as: "Of users who registered on Day 0, what % activated by Day N?"

### Feature Retention

Question: "Do users of feature X retain better at 30 days?"

1. In GA4 → **Audiences** → Create segment:
   - Segment A: users who fired `feature_used { feature: 'X' }`
   - Segment B: all users
2. Compare 30-day retention in **Explore** → **User lifetime**

If Segment A retains significantly better → feature X is a retention driver → prioritize it on the roadmap.

---

## 6. Segment-Based Analysis

**Never present aggregate numbers to stakeholders without first checking plan-level breakdown.**
An average that hides a broken enterprise experience is worse than no data.

Always cut by these dimensions before drawing conclusions:

| Dimension | Why |
|---|---|
| `plan` | Different plans have different user intent and behavior |
| `registration_source` | Organic vs invited users convert differently |
| `is_first_*` | First-time actions reveal onboarding problems |
| (product-specific) | Add your key dimensions in `ANALYTICS_CONTEXT.md` |

### Creating Segments in GA4

1. **Explore** → any report → **Segments** panel → **+**
2. Add filter: `User property` → `plan` = `enterprise`
3. Apply to compare segments side by side in the same funnel

### Segment Comparison Template

When reporting to stakeholders, always show:
```
Metric: [e.g. 7-day activation rate]
Overall:     XX%
Free:        XX%
Pro:         XX%
Enterprise:  XX%
Change vs last period: +X% / -X%
```
