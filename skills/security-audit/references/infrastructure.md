# Infrastructure Security Reference

## Table of Contents
1. Cloud Configuration
2. Secrets Management
3. Network Security
4. Container Security
5. CI/CD Pipeline Security
6. Monitoring & Incident Response

---

## 1. Cloud Configuration

### Common High-Risk Misconfigurations

**Storage buckets (S3 / GCS / Azure Blob):**
```
[ ] No public buckets unless explicitly required (static assets only)
[ ] Bucket policies reviewed — no wildcard (*) principal
[ ] Versioning enabled for sensitive data buckets
[ ] Server-side encryption enabled (SSE-S3 minimum, SSE-KMS preferred)
[ ] Access logging enabled
[ ] Block Public Access settings enabled at account level (AWS)
```

**Databases:**
```
[ ] Not publicly accessible (no public IP / firewall restricts to app only)
[ ] Encryption at rest enabled
[ ] Automated backups enabled with tested restore process
[ ] Database credentials rotated and not shared across environments
[ ] Audit logging enabled for sensitive data access
[ ] No default users/passwords active
```

**Compute (EC2 / GCE / VMs):**
```
[ ] No 0.0.0.0/0 inbound rules except ports 80/443
[ ] SSH access restricted to VPN / bastion host — not public internet
[ ] Instance metadata service v2 only (AWS IMDSv2) — prevents SSRF
[ ] IAM instance roles follow least privilege
[ ] OS patches applied, no EOL operating systems
```

---

## 2. Secrets Management

**Secret storage priority (best to worst):**

1. **Dedicated secret manager** — AWS Secrets Manager, GCP Secret Manager, HashiCorp Vault
2. **Environment variables** injected at deploy time (never stored in container image)
3. **Encrypted config files** with key stored separately
4. **❌ Source code** — never acceptable
5. **❌ Container images** — secrets baked into image are visible to anyone with image access

```bash
# Check for secrets accidentally committed
git log --all --full-history -- "**/.env"
git grep -i "password\|secret\|api_key\|private_key" -- "*.js" "*.ts" "*.go"

# Scan history (use truffleHog or git-secrets)
trufflehog git file://. --since-commit HEAD~50
```

**Secret rotation checklist:**
```
[ ] All secrets have documented rotation procedure
[ ] Rotation can be done without downtime (graceful dual-active period)
[ ] Old secrets revoked after rotation confirmed successful
[ ] Rotation frequency defined (API keys: 90 days, DB passwords: 180 days)
[ ] Emergency rotation procedure exists and tested
```

---

## 3. Network Security

**Firewall / Security Group rules:**
```
[ ] Default deny — only explicitly allowed traffic passes
[ ] Inbound: only 80/443 from internet; app ports from internal only
[ ] Outbound: restricted to known destinations (egress filtering)
[ ] Inter-service: services can only talk to services they need to
[ ] No 0.0.0.0/0 on database ports (3306, 5432, 27017, 6379)
[ ] Management ports (22, 3389) not exposed to internet
```

**TLS configuration:**
```
[ ] TLS 1.2 minimum, TLS 1.3 preferred
[ ] TLS 1.0 and 1.1 disabled
[ ] Weak ciphers disabled (RC4, DES, 3DES, EXPORT)
[ ] HSTS header set (min 1 year, includeSubDomains)
[ ] Certificate auto-renewal configured (no manual expiry risk)
[ ] Certificate pinning for mobile apps if applicable
```

Test with: `nmap --script ssl-enum-ciphers -p 443 example.com`
Or: [ssllabs.com/ssltest](https://www.ssllabs.com/ssltest/)

---

## 4. Container Security

**Dockerfile security checklist:**
```dockerfile
# ❌ Run as root
FROM node:18
COPY . .
CMD ["node", "server.js"]

# ✅ Non-root user, minimal base image, no secrets in image
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=appuser:appgroup . .
USER appuser
EXPOSE 3000
CMD ["node", "server.js"]
```

**Container runtime checklist:**
```
[ ] No containers running as root
[ ] Read-only root filesystem where possible
[ ] No privileged containers
[ ] Resource limits set (CPU, memory) — prevent DoS
[ ] Secrets injected via environment or secret mount — not in image
[ ] Base images scanned for vulnerabilities (Trivy, Snyk)
[ ] Images pinned to digest (not :latest tag)
```

---

## 5. CI/CD Pipeline Security

**Pipeline checklist:**
```
[ ] Secrets in CI are masked — never echoed in logs
[ ] OIDC used for cloud auth instead of long-lived keys (GitHub Actions → AWS)
[ ] Third-party actions pinned to commit SHA (not tag — tags can be moved)
[ ] SAST scan runs on every PR
[ ] Dependency vulnerability scan on every PR
[ ] Container image scan before deploy
[ ] Separate credentials per environment (dev ≠ staging ≠ prod)
[ ] Production deploys require manual approval
[ ] Artifact signing / provenance (SLSA level 2+)
```

```yaml
# ❌ Third-party action pinned to tag — can be changed by attacker
- uses: actions/checkout@v4

# ✅ Pinned to commit SHA — immutable
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

---

## 6. Monitoring & Incident Response

**Alerts that must exist:**
```
[ ] Authentication failure rate spike (brute force indicator)
[ ] Impossible travel (login from two distant IPs in short time)
[ ] Privilege escalation events
[ ] Data export / bulk download anomalies
[ ] API error rate spike (potential attack or misconfiguration)
[ ] New admin user created
[ ] Secret accessed outside normal hours / patterns
[ ] Infrastructure change outside change window
```

**Incident response checklist (when a security event is suspected):**
```
1. Contain  — isolate affected system, revoke suspected credentials
2. Assess   — what was accessed? what time window? which users affected?
3. Evidence — preserve logs before they rotate (snapshot, export)
4. Notify   — legal, DPO (if PII breach), affected users per law requirement
5. Remediate — fix root cause, not just symptoms
6. Review   — post-incident: how was it missed? what detection would have caught it earlier?
```

**Log retention:**
```
[ ] Security logs retained for minimum 90 days (1 year for compliance)
[ ] Logs stored in separate account / project (attacker can't delete them)
[ ] Log integrity protected (WORM storage or external SIEM)
[ ] Log search tested — can you find an event from 30 days ago in <5 min?
```
