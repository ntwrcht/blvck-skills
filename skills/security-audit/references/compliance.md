# Compliance Reference

## Table of Contents
1. PDPA (Thailand)
2. GDPR (EU)
3. SOC 2 Type II
4. ISO 27001
5. Compliance Gap Analysis Template

---

## 1. PDPA — Thailand Personal Data Protection Act

Effective: June 2022. Applies to any organization collecting PII of persons in Thailand.

### Key Requirements

**Lawful basis for processing:**
```
[ ] Consent obtained before collecting PII (explicit, not pre-ticked)
[ ] Purpose of collection stated clearly at time of collection
[ ] Data minimization — collect only what's necessary
[ ] Retention period defined and enforced
```

**Data subject rights (must be technically implemented):**
```
[ ] Right to access — user can request their data within 30 days
[ ] Right to erasure — user can request deletion ("right to be forgotten")
[ ] Right to portability — data exportable in machine-readable format
[ ] Right to correction — user can correct inaccurate data
[ ] Right to object — user can opt out of specific processing
[ ] Right to withdraw consent — as easy to withdraw as to give
```

**Technical requirements:**
```
[ ] Privacy notice / policy accessible before data collection
[ ] Consent records maintained (who consented, when, to what)
[ ] Data breach notification within 72 hours to PDPC (if 500+ persons affected)
[ ] DPA (Data Processing Agreement) with all third-party processors
[ ] Data Protection Officer (DPO) appointed if large-scale processing
[ ] Cross-border transfer only to countries with adequate protection
```

**High-risk for PDPA:**
- Collecting PII without explicit consent checkbox
- Selling or sharing data with third parties without disclosure
- Retaining data beyond stated retention period
- No mechanism for users to delete their accounts and data

---

## 2. GDPR — EU General Data Protection Regulation

Applies to any organization processing data of EU residents, regardless of where the organization is located.

### Key Requirements (similar to PDPA but stricter)

```
[ ] Lawful basis for every processing activity documented
[ ] Privacy by design — data protection built into system, not bolted on
[ ] Data Protection Impact Assessment (DPIA) for high-risk processing
[ ] Records of Processing Activities (RoPA) maintained
[ ] Breach notification: 72 hours to supervisory authority, without undue delay to users
[ ] DPO required for large-scale systematic processing
[ ] Standard Contractual Clauses (SCCs) for data transfers outside EU
```

**Key differences from PDPA:**
- Fines up to €20M or 4% global annual revenue (higher)
- More explicit requirements for children's data (under 16 need parental consent)
- Right to not be subject to automated decision-making

---

## 3. SOC 2 Type II

Framework for SaaS companies demonstrating security, availability, and confidentiality controls.
Type I = controls exist at a point in time. Type II = controls operated effectively over 6–12 months.

### Trust Service Criteria

**Security (CC series) — mandatory:**
```
CC6: Logical and Physical Access Controls
  [ ] Access provisioning and deprovisioning process
  [ ] MFA for all systems with sensitive data
  [ ] Principle of least privilege enforced
  [ ] Access reviews conducted quarterly

CC7: System Operations
  [ ] Vulnerability scanning run regularly
  [ ] Penetration testing annually
  [ ] Patch management process (critical within 30 days)
  [ ] Security monitoring and alerting

CC8: Change Management
  [ ] All changes go through defined process
  [ ] Code review required before merge
  [ ] Deployment approval process
  [ ] Rollback capability tested
```

**Availability (A series) — if included:**
```
A1: Performance Monitoring
  [ ] SLA defined and monitored
  [ ] Incident response procedure documented and tested
  [ ] Backup and recovery tested (RTO/RPO defined)
```

**Evidence to collect for audit:**
- Access review logs (quarterly)
- Vulnerability scan reports
- Pen test report + remediation evidence
- Change tickets / PR approvals
- Incident response records
- Training completion records

---

## 4. ISO 27001

International standard for Information Security Management Systems (ISMS).

### Key Controls (Annex A)

```
A.5   Information Security Policies — documented, approved, communicated
A.6   Organization of Information Security — roles, responsibilities, separation of duties
A.7   Human Resource Security — background checks, training, offboarding
A.8   Asset Management — inventory, classification, acceptable use
A.9   Access Control — need-to-know, least privilege, MFA, access reviews
A.10  Cryptography — policy for encryption, key management
A.11  Physical Security — data center access, clean desk, screen locks
A.12  Operations Security — malware protection, backup, logging, monitoring
A.13  Communications Security — network controls, data transfer policies
A.14  System Development — security in SDLC, change control, test data
A.15  Supplier Relations — third-party risk, contract requirements
A.16  Incident Management — response plan, reporting, lessons learned
A.17  Business Continuity — BCP/DR plan, tested regularly
A.18  Compliance — legal requirements, privacy, audit
```

---

## 5. Compliance Gap Analysis Template

Use this template when performing a compliance gap review:

```markdown
## Compliance Gap Analysis
**Standard:** PDPA / GDPR / SOC 2 / ISO 27001
**Date:** YYYY-MM-DD
**Scope:** [product / service / organization]

---

### Summary

| Status | Count |
|---|---|
| ✅ Compliant | X |
| ⚠️ Partial | X |
| ❌ Gap | X |
| N/A | X |

---

### Findings

#### ❌ GAP: [Requirement Name]
**Requirement:** What the standard requires
**Current State:** What exists today (or doesn't)
**Risk:** What could happen if not addressed
**Remediation:** Specific steps to become compliant
**Owner:** Who is responsible
**Target Date:** YYYY-MM-DD

#### ⚠️ PARTIAL: [Requirement Name]
**Requirement:** ...
**Current State:** What exists but is incomplete
**Gap:** What's missing
**Remediation:** ...

---

### Remediation Roadmap

| Priority | Finding | Owner | Due Date | Status |
|---|---|---|---|---|
| P1 | | | | |
```
