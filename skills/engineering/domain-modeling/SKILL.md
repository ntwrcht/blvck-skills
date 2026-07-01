---
name: domain-modeling
description: "Build and sharpen a project's domain model by challenging fuzzy language, updating the shared glossary inline, and recording hard architectural decisions as ADRs. Use when pinning down domain terminology, resolving contested terms, recording an architectural decision, or when another skill needs to maintain the domain vocabulary."
---

# Domain Modeling

Actively build and sharpen the project's domain model as you design. Challenge terms, invent edge-case scenarios, and write the glossary and decisions down the moment they crystallize.

Merely *reading* `CONTEXT.md` for vocabulary is not this skill — that is a one-line habit any skill can do. This skill is for when you are *changing* the model, not consuming it.

## Artifacts

- Produces: `CONTEXT.md` (domain glossary, fixed at repo root); ADRs at the `adr-dir` key path — see `references/artifact-paths.md` (default `.context/adr/`)
- Consumes: `.context/project.md`, `CONTEXT.md`, `CONTEXT-MAP.md`, `.context/output-paths.md` (if present, for the `adr-dir` override)

> `CONTEXT.md` is the domain glossary — terminology only, no implementation details. If your project also has `.context/project.md` (a broader onboarding brief), the two coexist: read `.context/project.md` for goals and tech stack; write `CONTEXT.md` for domain vocabulary.

## File Structure

Most repos have a single context:

```
/
├── CONTEXT.md
├── .context/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `CONTEXT-MAP.md` exists at the root, the repo has multiple contexts. The map points to where each one lives:

```
/
├── CONTEXT-MAP.md
├── .context/
│   └── adr/
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   └── .context/adr/
│   └── billing/
│       ├── CONTEXT.md
│       └── .context/adr/
```

Create files lazily — only when you have something to write. If no `CONTEXT.md` exists, create one when the first term is resolved. If no `.context/adr/` exists (or whatever path `adr-dir` resolves to — see `references/artifact-paths.md`), create it when the first ADR is needed.

## During the Session

### Challenge against the glossary

When the user uses a term that conflicts with existing language in `CONTEXT.md`, call it out immediately: "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term: "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent edge cases that force precision about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?" The user decides which side is authoritative.

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch — capture terms as they crystallize. Use the format in [references/CONTEXT-FORMAT.md](./references/CONTEXT-FORMAT.md).

`CONTEXT.md` is terminology only. Do not treat it as a spec, a scratch pad, or a repository for implementation decisions.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **Result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [references/ADR-FORMAT.md](./references/ADR-FORMAT.md). Write it to the `adr-dir` key path (default `.context/adr/`) — see `references/artifact-paths.md`.

## Completion Criteria

Offer to close the session when:

- Major domain entities and their relationships are named and written to `CONTEXT.md`
- Contested or overloaded terms from the session are resolved
- Any decisions that met the ADR gate are recorded

When these are met, summarize: agreed terms, deferred terms, ADRs written, and the next open question if one remains.

## When Not to Use

- Reading existing vocabulary to orient a task — any skill can read `CONTEXT.md` directly
- Scaffolding the `.context/` folder for a new project — use `setup-context` instead
- Reviewing or stress-testing a plan without changing the model — use `scrutinize` or `grilling` instead

## Next Step

Do not close the session until the user confirms the glossary and ADR updates are correct.

- **If approved:** continue with whichever skill triggered this session — an implementation or planning skill. This skill is usually used as a subroutine of another skill, not run standalone.
- **If not approved:** if a term is still contested, keep iterating with `grilling` before recording the decision — do not close the session until approval is explicit.
