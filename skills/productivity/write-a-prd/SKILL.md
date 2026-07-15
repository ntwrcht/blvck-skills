---
name: write-a-prd
description: "Synthesizes conversation context and repository understanding into a product requirements document. Use when drafting, writing, or publishing a PRD from existing conversation, technical brief, design discussion, or approved scope."
argument-hint: "<conversation context or PRD brief>"
---

# Write a PRD

Turn the current conversation context and relevant codebase understanding into one product requirements document that is ready for review or issue-tracker publishing.

## When to Use

Use this skill when the user wants to create, write, draft, or publish a PRD from existing context. Good trigger phrases include "to PRD", "turn this into a PRD", "create a PRD from this context", "write a PRD", and "publish this as a PRD".

Use `write-a-story` after the PRD is approved when the user wants child stories, tasks, sprint-ready backlog items, issue splitting, or acceptance-criteria-heavy implementation tickets.

## When Not to Use

Do not use this skill for backlog-only work, status updates, stakeholder summaries, post-mortems, narrative docs, or implementation plans unless the requested output is a PRD artifact.

Do not publish to any external issue tracker unless a compatible tool is available and the user explicitly approves the exact payload.

## Artifacts

- Produces: PRD at the `prd` key path — see `references/artifact-paths.md` (default `docs/prd/<slug>.md`)
- Consumes: goals doc at the `goals` key path (if present, default `docs/goals/<slug>.md`), `.context/project.md`, `.context/engineering.md`, `.context/adr/`

## Core Rule

Synthesize without interviewing by default. Use the current conversation, repository evidence, domain vocabulary, ADRs, and known constraints; label unknowns instead of inventing facts.

## Workflow

1. Gather context from the conversation and inspect the repository if needed. Read `.context/INDEX.md` when present, then relevant domain files such as `.context/project.md`, `.context/engineering.md`, and `.context/adr/`. Prefer existing domain terms, product vocabulary, local architecture boundaries, and relevant ADRs.
2. Identify the product scope, actor set, user-facing value, implementation constraints, non-goals, dependencies, and open risks.
3. Sketch testing seams at the highest practical behavior boundary. Prefer existing seams to new ones.
4. Pause to confirm testing seams only when repo evidence is weak, the feature crosses multiple modules, or choosing the wrong seam would materially change the PRD.
5. Load `references/prd-template.md` and write one PRD artifact. Keep user stories comprehensive but scoped; avoid padding.
6. If tracker publishing is requested, prepare one tracker-neutral PRD issue payload with the `ready-for-agent` label.
7. Show the exact title, body, labels, tracker target, and any required fields. Publish only after explicit user approval.

## Publishing Rules

- Create one PRD artifact or issue only.
- Keep the payload tracker-neutral unless the user or connected tool provides a specific tracker convention.
- Use Jira as a supported path only when a Jira MCP/tool is connected and required fields can be resolved.
- Never guess destructive or workflow-changing fields such as sprint, assignee, due date, fix version, release, or priority.
- If publishing fails, report the failure and keep the approved payload visible for retry or manual use.

## Reference Map

- `references/prd-template.md`: exact PRD sections, formatting rules, user story guidance, implementation-decision guidance, and testing-decision guidance.

## Review Checklist

- Does the PRD reflect known conversation and repo context without invented business facts?
- Are problem, solution, scope, non-goals, dependencies, and risks clear?
- Are user stories comprehensive but scoped to the feature?
- Are implementation decisions stable enough to avoid brittle file-path details?
- Are testing seams tied to external behavior and existing codebase prior art?
- Has the user approved the exact tracker payload before publishing?

## Next Step

Publish only after explicit user approval.

- **If approved:** hand off to `write-a-story` to break the PRD into implementation-ready backlog items.
- **If not approved:** revise the PRD in place, or recommend `grilling` first if the feedback shows the underlying goals were never nailed down.
