---
name: code-to-docs
description: "Reverse-engineers technical documentation from an existing codebase — architecture overviews, OpenAPI specs, C4 and sequence diagrams, and operational runbooks — and audits technical docs that already exist. Use when documenting an inherited or undocumented service, extracting an API spec from route handlers, drawing system diagrams from code, writing a deployment or incident runbook, or reviewing existing technical docs for gaps."
argument-hint: "<path to document, or the doc to audit>"
---

# Code to Docs

Read a codebase and produce the technical documentation it never had: what the system is, what its API surface looks like, how it is shaped, and how to operate it. Every claim traces to a file the agent actually read.

## When to Use

Use when documentation must be derived from code rather than from the user's head: an inherited service with no docs, an OpenAPI spec that has drifted from its route handlers, a C4 or sequence diagram for onboarding, a deployment or incident runbook, or a gap audit of existing technical docs. Common phrasings: "document this service", "what does this codebase do", "generate an OpenAPI spec", "draw the architecture", "write a failover runbook", "audit our API docs".

## When Not to Use

- The knowledge lives with the user, not in the repo — use `doc-coauthoring` for a spec, proposal, or RFC.
- The output is a product requirement or backlog item — use `write-a-prd` or `write-a-story`.
- The audience is end users rather than developers or operators — use `write-user-docs`.
- A single architectural decision needs recording, or terminology needs pinning down — use `domain-modeling` for ADRs and the glossary.
- The ask is a code review or risk assessment rather than a description — use `scrutinize` or `security-audit`.
- The system is being rewritten. Document the new design, not the code being deleted.

## Artifacts

- Produces: architecture doc at the `architecture` key path, OpenAPI spec at `openapi`, diagrams under `diagrams-dir`, runbooks at `runbook`, audit reports at `doc-audit` — see `references/artifact-paths.md`.
- Consumes: the codebase, plus `.context/project.md`, `.context/engineering.md`, `.context/adr/`, and `CONTEXT.md` when present.

## Core Rule

Document what the code does, not what it was supposed to do. Cite the file behind each claim, and mark anything inferred rather than read as an explicit open question — a confident wrong architecture diagram costs more than a missing one.

## Workflow

1. Name the target and the audience. Pick the deliverables: architecture, API spec, diagrams, runbook, audit. Do not produce all five by reflex.
2. Detect the stack. Glob for manifest files, then grep to confirm the framework signature. Load `references/framework-detection.md`.
3. Read outward from the entry point: startup and config, then routes, then data model, then services, then auth, then deployment files. Stop at the depth the chosen deliverables need.
4. Note every gap as you go — behavior you could not confirm from code becomes an "Open Questions" section, never a guess.
5. Write the deliverables:
   - Architecture doc → load `references/architecture-arc42.md`
   - OpenAPI spec → load `references/openapi-extraction.md`
   - Diagrams → load `references/diagrams-c4.md`
   - Runbook → load `references/runbooks.md`
6. For an audit of existing docs, skip steps 3–5 and load `references/audit-checklist.md`: classify the doc, run the checklist, rank findings by severity, and report before fixing anything.
7. Verify before handing over. Every path, endpoint, table, and command in the output must exist in the repo. Runbook commands stay unexecuted — they are for a human to run.

## Reference Map

- `references/framework-detection.md` — manifest and grep signatures per stack, and what each one exposes for extraction.
- `references/architecture-arc42.md` — the arc42 section set, which sections to skip for small services, and how sections map to C4 levels.
- `references/openapi-extraction.md` — route handler to OpenAPI 3.1 mapping, plus the completeness checklist for a spec.
- `references/diagrams-c4.md` — diagram selection matrix, C4 levels, and Mermaid syntax for each type.
- `references/runbooks.md` — runbook template, the four runbook categories, and the rollback and verification rules.
- `references/audit-checklist.md` — per-doc-type quality checklists, severity ranking, and the audit report format.
- `references/artifact-paths.md` — where each artifact is written.

## Next Step

Generated docs are a draft until someone who knows the system confirms them. Present the open questions list alongside the artifact and ask for a correctness pass.

- **If approved:** hand off to `write-user-docs` when the same system also needs end-user or tutorial material, or to `domain-modeling` to promote recurring terms into the glossary and any discovered decisions into ADRs.
- **If not approved:** correct the artifact in place against the reviewer's notes and re-verify the disputed claims against the code. If the review shows the target or audience was wrong, restart at step 1 rather than patching.
