# Documentation Audit

Report before fixing. An audit that silently rewrites the doc gives the owner no way to judge whether the changes were right.

## 1. Classify the document

| Signals in the file | Type |
| :--- | :--- |
| `openapi:`, `swagger:`, `paths:` | API specification |
| arc42 or C4 section headings, "Building Block", "Deployment View" | Architecture doc |
| "When to run", "Rollback", numbered shell steps | Runbook |
| "FR-", "NFR-", "shall" | Requirements spec |
| "How to", numbered UI steps, screenshots | User documentation |
| Installation, usage, contributing | README |

## 2. Check accuracy against the code first

Staleness is the defect that matters. Before any style check, verify the claims:

- Do the documented endpoints match the routes in the codebase? List those present in one and not the other.
- Do the documented config keys and environment variables still exist?
- Do the commands still work — right script names, right flags, right paths?
- Do the diagrams match the current container and module layout?
- Do internal links resolve, and do referenced files still exist?
- Does the stated version match what the repo actually ships?

A polished document describing a system that no longer exists is worse than no document, because it is believed.

## 3. Universal checks

- [ ] Title says what the document is, specifically
- [ ] Owner or maintaining team named
- [ ] Last-updated date present and plausible
- [ ] Purpose, scope, and intended audience stated up front
- [ ] Acronyms defined on first use
- [ ] Table of contents if longer than roughly three screens
- [ ] Consistent heading hierarchy, no skipped levels
- [ ] No unresolved `TODO` or placeholder text

## 4. Type-specific checks

**API specification**
- [ ] Server URLs for every environment
- [ ] Auth scheme documented, including how to obtain credentials
- [ ] Every route in code present in the spec
- [ ] Request and response examples on non-trivial operations
- [ ] Error responses matching what the handlers raise
- [ ] Pagination and rate limits described where they apply
- [ ] Spec passes a linter

**Architecture doc**
- [ ] System boundary and external dependencies explicit
- [ ] Diagrams present, current, and source-controlled as text
- [ ] At least one runtime flow traced end to end
- [ ] Significant decisions recorded with their alternatives
- [ ] Known debt and risks listed
- [ ] Glossary covers the domain nouns used in the text

**Runbook**
- [ ] Trigger condition stated — when to run, and when not to
- [ ] Prerequisites and required access listed
- [ ] Every step has an expected result
- [ ] Rollback path for every destructive action
- [ ] Escalation contact named
- [ ] Last rehearsal date recorded

**README**
- [ ] What the project is, in one sentence, above the fold
- [ ] Install and run steps that work on a clean machine
- [ ] Required environment variables listed
- [ ] How to run the tests
- [ ] Where fuller documentation lives

## 5. Rank findings

| Severity | Definition |
| :--- | :--- |
| Critical | Actively wrong — a reader following it breaks something or is misled about behavior |
| High | A required section is missing, or coverage has a hole a reader will hit |
| Medium | Correct but hard to use: no examples, poor structure, inconsistent terms |
| Low | Polish — formatting, wording, ordering |

Rank by consequence to the reader, not by how easy it is to fix.

## 6. Report format

```markdown
# Documentation Audit — <document>

**Path:** docs/api/openapi.yaml
**Type:** API specification
**Audited against:** commit 8f11dd9

## Verdict

Fair. Structurally sound but three endpoints have drifted from the code, and
error responses are undocumented throughout. Recommend revision before this is
handed to an external integrator.

## Critical

1. **`POST /tasks/{id}/assign` is undocumented.** Present in
   `TaskController.java:88`, absent from the spec. External callers cannot
   discover it.
2. **`GET /tasks` documents a `sort` parameter the handler ignores.**
   `TaskController.java:41` accepts no such parameter; callers relying on it
   get silently unsorted results.

## High

3. **No error responses on any operation.** Every handler can return 400 and
   401; `GlobalExceptionHandler.java` also maps 409 on duplicate titles.

## Medium

4. **`Task` schema inlined in six places** instead of a single
   `components.schemas` entry — the copies have already diverged on `status`.

## Low

5. No `operationId` on any operation, so client generators emit positional names.

## Quick wins (under an hour)

- Add the missing `assign` endpoint (finding 1)
- Delete the phantom `sort` parameter (finding 2)
- Add `operationId` throughout (finding 5)

## Recommended order

1, 2 → 3 → 4 → 5
```

## 7. Offer, then fix

Present the report and ask what to fix. Apply changes in severity order, and re-verify the corrected claims against the code rather than against the report.
