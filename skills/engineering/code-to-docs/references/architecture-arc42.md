# Architecture Documentation (arc42)

arc42 is a twelve-section template for describing a system's architecture. Use it as a checklist of questions, not a form to fill — an empty section is worse than an absent one.

## The twelve sections

| # | Section | Answers | Extract from |
| :--- | :--- | :--- | :--- |
| 1 | Introduction and Goals | What is this system for, and who cares? | README, service description, top-level config |
| 2 | Constraints | What was non-negotiable? | Runtime versions, licences, platform lock-in, compliance config |
| 3 | Context and Scope | Where does the boundary sit, and what crosses it? | External clients, outbound HTTP calls, queues, third-party SDKs |
| 4 | Solution Strategy | What are the few decisions that shaped everything else? | Framework choice, persistence choice, sync vs async, deployment target |
| 5 | Building Block View | What are the parts, and what does each own? | Package structure, service classes, module boundaries |
| 6 | Runtime View | How do the parts collaborate for the important flows? | Trace 2–4 key request paths end to end |
| 7 | Deployment View | What runs where? | Dockerfile, IaC, Kubernetes manifests, CI workflows |
| 8 | Crosscutting Concepts | What patterns repeat everywhere? | Auth middleware, error handling, logging, validation, transactions |
| 9 | Architectural Decisions | Which choices are worth explaining? | Existing ADRs, comments that justify a choice, unusual patterns |
| 10 | Quality Requirements | What must the system be good at? | Timeouts, retries, cache config, rate limits, SLO config |
| 11 | Risks and Technical Debt | What is known to be fragile? | TODO/FIXME/HACK comments, deprecated deps, disabled tests |
| 12 | Glossary | What do the domain nouns mean? | Entity names, enum values, recurring identifiers |

## Sizing

**Small service (one deployable, under ~20 endpoints).** Write sections 1, 3, 5, 7, and 12. Fold 4 and 8 into 5. Skip the rest. Target 2–4 pages.

**Substantial system (several containers, or regulated).** Write all twelve. Sections 6 and 9 are where the value is — the runtime traces and the decisions are what a new engineer cannot get from reading code.

**Skip arc42 entirely** for a CRUD app or a throwaway prototype. A README section and one C4 Container diagram carry the same information at a tenth of the maintenance cost.

## Mapping to C4

| arc42 section | Diagram |
| :--- | :--- |
| §3 Context and Scope | C4 Level 1 — System Context |
| §5 Building Block View | C4 Level 2 — Container, then Level 3 — Component |
| §6 Runtime View | Sequence diagram per traced flow |
| §7 Deployment View | Deployment diagram |

Write the prose and the diagram together. A diagram with no accompanying paragraph gets misread; a paragraph with no diagram gets skipped.

## Extraction discipline

- **Trace, don't summarize.** For §6, follow one real request from the route handler through every service and query it touches. A generic "the controller calls the service which calls the repository" is a no-op sentence.
- **Cite the file.** Each building block in §5 names the package or directory it corresponds to, so a reader can jump straight there.
- **Externals are what leave the process.** In §3, count outbound HTTP clients, queue producers and consumers, third-party SDKs, and scheduled jobs. Internal modules are §5, not §3.
- **Debt is evidence-based.** §11 lists what the repo shows — skipped tests, pinned-back dependencies, TODO clusters — not what you suspect.

## Open Questions

Close the document with an explicit list of what could not be determined from code: production topology, actual traffic shape, why a decision was made, whether a code path is still live. Format each as a question addressed to a maintainer, not as a hedge in the body text.

```markdown
## Open Questions

1. `LegacyPaymentAdapter` is wired in `PaymentConfig` but no route reaches it — is it still called by a scheduled job, or is it dead?
2. §7 assumes a single replica; the Kubernetes manifest sets `replicas: 3`. Which is production?
3. No ADR explains the split between `orders` and `fulfilment` schemas. Was this a team boundary or a scaling decision?
```
