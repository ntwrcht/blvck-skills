<!-- Customer release document. Work the sections in order.
     references/document-sections.md carries the rule each one follows.
     An empty section is stated as empty, never dropped — the numbering is the contract. -->

# <Product / Platform> Release <platform-version>

## 1. Release Summary

<!-- 2-3 sentences: what, why now, when. -->

## 2. Major Changes

<!-- 3-6 themes by capability, 2-4 bullets each. Never one section per repository. -->

### <Theme>

-

## 3. Benefits

<!-- One line per theme: what the customer gets. Only numbers a report substantiates. -->

-

## 4. Impact

### 4.1 System

<!-- Breaking changes and which customer integrations must change; new infra;
     new outbound hosts to allowlist; resource changes. -->

-

### 4.2 Process

<!-- Retraining, SOP and doc updates, changes to their integration code. -->

-

### 4.3 Downtime

<!-- Total window, which functions unavailable, what stays up. -->

-

## 5. Deployment Playbook

<!-- A proposal requiring customer approval: their timezone, a low-traffic window,
     never a fixed date. Waves come from deploy_after — provider before consumer. -->

```
T-0:00  Pre-checks, backup verification
T-0:xx  Maintenance window opens — traffic stopped
T-0:xx  DB migration
T-0:xx  Wave 1 deploy (no dependencies)
T-0:xx  Wave 2 deploy (dependents)
T-0:xx  Smoke tests
T-0:xx  ROLLBACK DECISION POINT — abort criteria: <explicit>
T-0:xx  Traffic restored
T+xx    Monitoring window
```

- Rollback after the migration step: <redeploy old tag | restore from backup, RPO <n>>

## 6. Version Matrix

<!-- Every service, including no-ops. -->

| Service | Current | New |
|---|---|---|
|  |  |  |

**Platform release number:** <the one number the customer quotes in support tickets>

## 7. Customer Actions Required

<!-- Everything the customer must do, each with a by-when. -->

| # | Action | Owner | By when |
|---|---|---|---|
| 1 |  |  |  |

## 8. Open Items / TBC

<!-- Every unresolved NEEDS-HUMAN / UNKNOWN, stated plainly rather than smoothed over. -->

-
