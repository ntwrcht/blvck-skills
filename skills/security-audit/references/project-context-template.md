# Security Project Context Template

Copy this file to your project root as `SECURITY_CONTEXT.md` and fill it in.
The security-audit skill reads this file at the start of every session.

---

## Product Overview

```
Product name:      _______________
Product type:      SaaS / API / mobile / internal tool
Deployment:        Cloud (AWS/GCP/Azure) / on-premise / hybrid
Internet-facing:   yes / no
Authentication:    JWT / session / OAuth / API key / other
```

---

## Tech Stack

```
Frontend:    _______________   (e.g. Angular 17, React)
Backend:     _______________   (e.g. Go, Node.js, Python)
Database:    _______________   (e.g. MongoDB, PostgreSQL)
Infra:       _______________   (e.g. GKE, EKS, EC2)
CDN/WAF:     _______________   (e.g. Cloudflare, AWS WAF)
```

---

## Data Sensitivity

```
PII handled:         yes / no   (names, emails, phone numbers)
Financial data:      yes / no
Health data:         yes / no
Third-party data:    yes / no   (e.g. user content, messages)
Data residency:      _______________   (e.g. Thailand, EU)
```

---

## Compliance Requirements

```
[ ] PDPA (Thailand)
[ ] GDPR (EU)
[ ] SOC 2 Type II
[ ] ISO 27001
[ ] PCI-DSS
[ ] Other: _______________
```

---

## Threat Model

Who are the likely attackers?

```
[ ] External unauthenticated attackers (internet)
[ ] Authenticated but malicious users
[ ] Compromised insider / employee
[ ] Supply chain (third-party dependencies)
[ ] Other: _______________
```

What are the highest-value targets?

```
1. _______________   (e.g. user PII database)
2. _______________   (e.g. admin panel)
3. _______________
```

---

## Known Issues & Remediation History

| Finding | Severity | Status | Remediated In |
|---|---|---|---|
| (add previous pentest findings here) | | | |

---

## Security Controls Already in Place

```
[ ] WAF / DDoS protection
[ ] Rate limiting on APIs
[ ] Input validation / sanitization
[ ] Output encoding
[ ] HTTPS enforced everywhere
[ ] Secrets in vault (not in code)
[ ] Dependency scanning (e.g. Snyk, Dependabot)
[ ] SAST in CI pipeline
[ ] Logging & alerting on auth failures
[ ] MFA for admin access
```

---

## Out of Scope

List anything explicitly excluded from security review:

```
- _______________
```
