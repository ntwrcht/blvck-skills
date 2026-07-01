---
name: security-audit
description: "Review application security across code, APIs, infrastructure, authentication, authorization, secrets, dependencies, and compliance gaps. Use when assessing vulnerabilities, threat models, pentest findings, security controls, exploitability, impact, or remediation plans."
---

# Security Audit

Review systems like a senior application security engineer: identify what can go wrong, explain the exploitability and impact, and provide concrete remediation without generating weaponizable attack code.

## When to Use

Use this skill for security code review, API security review, auth and authorization checks, secrets handling, dependency risk, infrastructure misconfiguration, compliance gap analysis, threat modeling, pentest finding review, and remediation planning.

Use a general code-review skill when the request is mostly about correctness, maintainability, or performance. Use a debugging workflow when the user needs to reproduce and fix a functional bug before assessing security impact.

## Artifacts

- Produces: findings at the `security-findings` key path — see `references/artifact-paths.md` (default `.context/security-findings/<slug>.md`, on request)
- Consumes: `.context/project.md`, `.context/security.md`, `.context/engineering.md`, `.context/adr/`

## Core Rule

Every finding must be grounded in evidence and must explain trust boundary, exploitability, blast radius, business impact, and the specific fix.

## Workflow

1. Define scope from the request: target files, endpoints, services, infrastructure, compliance regime, data sensitivity, and whether the system is internet-facing.
2. Inspect local context before asking questions. Read `.context/INDEX.md`, then relevant domain files such as `.context/project.md`, `.context/security.md`, `.context/engineering.md`, `.context/learning.md`, and `.context/adr/`, plus security docs, configs, routes, auth code, dependency manifests, IaC, and prior findings when relevant.
3. If scope is ambiguous, state reasonable assumptions and continue with the highest-risk surfaces first. Ask only when a missing answer would materially change severity or remediation. If the user asks to bootstrap reusable context, use `skills/productivity/setup-context/references/domains.md`.
4. Trace untrusted input across trust boundaries: request entry, parsing, validation, authn, authz, business logic, storage, outbound calls, logging, and response shaping.
5. Check controls in context rather than by checklist alone. A weakness is a finding only when exploitability and impact are defensible.
6. Classify severity using the framework below, and make the reasoning explicit.
7. Provide remediation that is specific enough to implement. Prefer code-level or configuration-level fixes when the affected stack is known.
8. Sanitize secrets, tokens, PII, hostnames, and customer data from evidence and output.
9. Validate fix recommendations against the codebase or configuration when possible, then note residual risk and test coverage gaps.

## Severity Framework

| Severity | Exploitability | Impact | Example |
|---|---|---|---|
| Critical | Easy, remote, no auth | Full compromise or mass data breach | Public SQL injection exposing all users |
| High | Moderate effort or low-privilege auth | Significant exposure or privilege escalation | IDOR reading other users' records |
| Medium | Specific preconditions | Limited exposure or meaningful abuse | CSRF on a non-critical state change |
| Low | Difficult or requires chaining | Minimal direct impact | Detailed production error disclosure |
| Info | No direct exploit path | Defense-in-depth or hygiene gap | Missing security header |

## Finding Format

```markdown
## [Severity] Finding Title

**Category:** Injection / Broken Auth / IDOR / XSS / Misconfiguration / etc.
**Location:** File path, endpoint, component, or config key
**Status:** Open / Fixed / Accepted Risk / Needs Triage

### Description
What the issue is and how it works technically.

### Evidence
Sanitized code, request behavior, configuration, or dependency data proving the issue.

### Impact
What an attacker can achieve, including affected data, users, systems, and business impact.

### Severity Reasoning
Trust boundary, exploitability, blast radius, and likelihood.

### Remediation
Specific implementation steps, safer patterns, tests, and rollout notes.

### References
OWASP, CWE, vendor docs, or project docs when useful.
```

## Reference Map

Load only the reference needed for the current audit surface:

- `references/code-review-security.md`: application code, auth logic, crypto, secrets, dependency review, logging.
- `references/api-security.md`: endpoints, tokens, authorization, rate limits, data exposure, API keys.
- `references/web-vulnerabilities.md`: frontend rendering, forms, browser security, XSS, CSRF, OWASP web risks.
- `references/infrastructure.md`: cloud config, deployment, network exposure, secrets management, IaC.
- `references/compliance.md`: PDPA, GDPR, SOC2, ISO 27001, PCI-DSS gap analysis.
- `references/report-template.md`: formal security report, pentest findings, executive summary, remediation roadmap.
- `references/context-template.md`: optional `.context/` domain structure for reusable project context.

## Safety Boundaries

- Do not provide exploit scripts, credential stuffing flows, malware, persistence mechanisms, or instructions that enable unauthorized access.
- Do not run active scans, fuzzers, exploit tools, or network probes unless the user has explicitly authorized the target and the environment.
- Do not expose secrets or sensitive data in findings; redact and describe instead.
- When user intent is unclear, keep output defensive: explain risk, safe validation steps, and remediation.

## Review Checklist

- Scope, assumptions, and excluded areas are stated.
- High-risk trust boundaries were inspected before low-risk hygiene issues.
- Each finding includes evidence, impact, severity reasoning, and remediation.
- Findings avoid generic advice such as "sanitize input" without implementation detail.
- Output is ordered by severity and business risk.
- Any unverified claim is labeled as an assumption or residual risk.

## Next Step

Do not treat the review as complete until the user confirms no blocking findings remain unaddressed.

- **If approved:** no blocking findings remain, or all were fixed — proceed to ship, handing off to `triage`, `post-mortem` (if issues were found and fixed), or `management-talk`/`stakeholder-update` for the summary.
- **If not approved:** hand blocking findings back to the implementation skill that owns the affected code, then re-run this skill.
