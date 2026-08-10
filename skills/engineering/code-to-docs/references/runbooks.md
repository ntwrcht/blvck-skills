# Runbooks

A runbook is read at 3am by someone tired and under pressure. Write for that reader: no background, no rationale, no prose paragraphs — just ordered, verifiable actions.

## Categories

| Category | Examples | Cadence |
| :--- | :--- | :--- |
| Incident response | Database failover, service restart, deployment rollback, cache flush | Rehearse quarterly |
| Routine operations | Backup and restore, certificate renewal, log rotation, key rotation | Follow on schedule |
| Disaster recovery | Full restore from backup, region failover | Rehearse annually |
| Scaling | Add capacity, resize a database, change autoscaling bounds | As needed |

One runbook per procedure. A document titled "Operations" that covers six procedures will be searched, not read.

## Template

````markdown
# Runbook: Database Failover

**Severity:** Critical — all writes fail
**Estimated duration:** 10–15 minutes
**Last rehearsed:** 2026-05-14

## When to run this

The primary Postgres instance is unreachable or returning errors on writes, and
a restart has already failed. Do not run this for elevated latency alone.

## Prerequisites

- AWS console access with `rds:PromoteReadReplica`
- `kubectl` context set to `prod-eu`
- VPN connected
- Incident channel open in `#incidents`

## Steps

### 1. Confirm the primary is actually down

```bash
psql -h primary.db.internal -U admin -c "SELECT 1" -w
```

**Expect:** a row in under 100ms.
**If it times out or refuses:** continue to step 2.
**If it succeeds:** stop. This is not a failover situation.

### 2. Promote the read replica

AWS console → RDS → Databases → `task-replica-1` → Actions → Promote.

**Expect:** status moves to `modifying`, then `available` within 2–5 minutes.
**Verify:**

```bash
aws rds describe-db-instances --db-instance-identifier task-replica-1 \
  --query 'DBInstances[0].DBInstanceStatus'
```

### 3. Repoint the application

```bash
kubectl set env deployment/api DATABASE_HOST=task-replica-1.db.internal
kubectl rollout status deployment/api --timeout=180s
```

**Expect:** rollout completes, all pods `Ready`.

### 4. Verify service health

```bash
curl -fsS https://api.example.com/health
```

**Expect:** `{"status":"ok","db":"ok"}`.
**If `db` is not `ok`:** go to Rollback.

### 5. Announce

Post in `#incidents`: new primary, time of promotion, current health, and that
root-cause investigation is pending.

## Rollback

If the promoted replica is unhealthy and the original primary has recovered:

```bash
kubectl set env deployment/api DATABASE_HOST=primary.db.internal
kubectl rollout status deployment/api --timeout=180s
```

Then escalate to the database on-call — do not attempt a second promotion.

## After the incident

- [ ] Capture logs from the failed primary before its retention window closes
- [ ] Provision a replacement read replica
- [ ] Open a post-mortem
- [ ] Update this runbook with anything that did not match reality
````

## Rules

- **Every step has an expected result.** Without one the reader cannot tell success from silent failure — this is the single most common defect in real runbooks.
- **Every destructive action has a rollback.** If there is genuinely no undo, say so in bold at that step.
- **Commands are copy-pasteable and complete.** Real hostnames, real flags, no `<your-cluster>` placeholders where a value is knowable.
- **State the timing.** "Wait 2–5 minutes" prevents someone deciding it hung after 30 seconds.
- **Branch explicitly.** "If X, go to step 4; if Y, stop and escalate."
- **Name who to escalate to** and when — the runbook must have an exit that is not "keep trying".
- **Date the last rehearsal.** An unrehearsed runbook is a hypothesis.

## Extracting from a repo

| Source | Yields |
| :--- | :--- |
| CI/CD workflows | The real deploy and rollback commands |
| Kubernetes manifests, Helm charts | Deployment names, namespaces, probes, replica counts |
| Terraform, Pulumi, CDK | Resource identifiers, regions, backup configuration |
| Health and readiness endpoints | Verification commands |
| Alert rules, monitor definitions | Which incidents warrant a runbook at all |
| `Makefile`, `scripts/`, `justfile` | Operational commands the team already uses |

Never execute the commands while writing. Extract, assemble, and mark anything you could not confirm as **UNVERIFIED — confirm before relying on this step.**
