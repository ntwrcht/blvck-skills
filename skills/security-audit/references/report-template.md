# Security Report Template

## Table of Contents
1. Executive Summary Template
2. Finding Template
3. Severity Scoring Guide
4. Remediation Roadmap Template

---

## 1. Executive Summary Template

```markdown
# Security Audit Report

**Product / System:** _______________
**Audit Type:** Penetration Test / Code Review / Configuration Audit / Compliance Gap
**Scope:** _______________
**Period:** YYYY-MM-DD to YYYY-MM-DD
**Prepared by:** _______________
**Report version:** 1.0

---

## Executive Summary

[2–3 sentence overview of what was tested and the overall security posture]

### Finding Summary

| Severity | Count | Remediated | Open |
|---|---|---|---|
| Critical | X | X | X |
| High | X | X | X |
| Medium | X | X | X |
| Low | X | X | X |
| Info | X | X | X |
| **Total** | **X** | **X** | **X** |

### Key Risk Areas

1. **[Risk area]** — brief description of systemic issue
2. **[Risk area]** — ...
3. **[Risk area]** — ...

### Positive Observations

- [Security control that is working well]
- [Good practice observed]

---

## Scope & Methodology

**In scope:**
- [Systems, endpoints, features tested]

**Out of scope:**
- [Explicitly excluded items]

**Testing approach:**
- [Black box / Grey box / White box]
- [Tools used]
- [Timeframe and conditions]
```

---

## 2. Finding Template

```markdown
---

## [SEVERITY-###] Finding Title

**Severity:** Critical / High / Medium / Low / Info
**Status:** Open / Remediated / Accepted Risk
**Category:** Injection / Broken Auth / IDOR / XSS / Misconfiguration / etc.
**CWE:** CWE-XXX
**OWASP:** Axx:2021 — Category Name
**Affected Component:** File path / endpoint / service name

---

### Description

[Technical explanation of the vulnerability — what it is and how it works.
Assume the reader is technical but may not know this specific area.
2–4 sentences.]

### Impact

[What an attacker can achieve if this is exploited. Be specific.
"An attacker can read all users' private messages" not "data may be exposed."
Include business impact: data breach, service disruption, financial loss, reputation.]

### Evidence

[Sanitized code snippet, request/response, or configuration showing the issue.
Remove any real credentials, PII, or production-specific identifiers.]

```code
// Vulnerable code or request here
```

### Steps to Reproduce (if applicable)

1. Step one
2. Step two
3. Observed result

### Remediation

[Specific, actionable fix. Include code example where relevant.
"Sanitize input" is not sufficient — explain exactly how.]

```code
// Corrected code here
```

### References

- [OWASP link]
- [CWE link]
- [Relevant documentation]
```

---

## 3. Severity Scoring Guide

Use this framework consistently. Document your reasoning for every severity assignment.

| Severity | Exploitability | Authentication Required | Impact | Example |
|---|---|---|---|---|
| **Critical** | Trivial / automated | None | Full system compromise, mass data breach | Unauthenticated SQL injection |
| **High** | Moderate skill | None or low-privilege user | Significant data exposure, privilege escalation | IDOR exposing all user records |
| **Medium** | Specific conditions | Authenticated user | Limited data exposure, partial functionality | CSRF on profile update |
| **Low** | Difficult, requires chaining | Authenticated | Minimal direct impact | Information disclosure in error |
| **Info** | Not directly exploitable | N/A | Best practice gap, defense in depth | Missing security header |

**CVSS Base Score mapping (optional):**
- Critical: 9.0–10.0
- High: 7.0–8.9
- Medium: 4.0–6.9
- Low: 0.1–3.9

---

## 4. Remediation Roadmap Template

```markdown
## Remediation Roadmap

### Immediate (within 48 hours)
Address Critical findings that are actively exploitable.

| ID | Finding | Owner | Status |
|---|---|---|---|
| | | | |

### Short-term (within 2 weeks)
High severity findings.

| ID | Finding | Owner | Target Date | Status |
|---|---|---|---|---|
| | | | | |

### Medium-term (within 1 sprint / 2 weeks)
Medium severity findings.

| ID | Finding | Owner | Target Date | Status |
|---|---|---|---|---|
| | | | | |

### Backlog
Low and Info findings — prioritize by effort vs. risk reduction.

| ID | Finding | Notes |
|---|---|---|
| | | |

---

### Verification Process

For each remediated finding:
1. Developer implements fix in feature branch
2. Security reviewer verifies fix addresses root cause (not just symptom)
3. Finding status updated to "Remediated" with commit reference
4. Re-test in staging before marking as closed
```
