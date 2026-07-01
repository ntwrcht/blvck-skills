---
name: grilling
description: "Interview the user relentlessly about a plan or design, walking down each branch of the decision tree one dependency at a time. Use when grilling a plan, stress-testing a proposal, clarifying vague intent, or resolving decisions before implementation."
---

# Grilling

Walk down the decision tree relentlessly — one branch, one question, one resolved dependency at a time.

## Artifacts

- Produces: goals doc at the `goals` key path (on request) — see `references/artifact-paths.md` (default `docs/goals/<slug>.md`)
- Consumes: `.context/project.md`

## Core Rule

Resolve upstream decisions before downstream details. Ask one question at a time, and offer a recommended answer when evidence supports one.

## Decision Frame

Build and maintain this frame internally during the interview:

- Goal: the outcome, user, and success signal.
- Context: current system, constraints, assumptions, prior decisions, and non-goals.
- Decision: the choice being made now and the options being rejected.
- Tradeoffs: cost, complexity, reversibility, time, quality, performance, security, and maintenance.
- Dependencies: people, systems, data, tools, approvals, and sequence constraints.
- Risks: failure modes, unknowns, blast radius, and ways the plan can be wrong.
- Validation: evidence that will prove the decision worked.
- Rollback: how to undo or limit damage.

Goal and context are upstream of everything else — resolve them first.

## Workflow

1. Restate the current goal in one sentence. If the goal is unclear, make that the first question.
2. Inspect available artifacts before asking questions that local files, docs, tests, logs, or supplied material can answer.
3. Pick the highest-leverage unresolved branch in the decision tree.
4. Ask exactly one question.
5. Include why it matters and a provisional recommendation when there is enough evidence.
6. Wait for the user's answer, then update the frame and move to the next dependency.
7. When major branches are resolved, summarize agreed decisions, open questions, risks, validation plan, and next action.

## Question Format

```text
Question: <one narrow question>
Why it matters: <decision or risk it unlocks>
Recommendation: <provisional answer, or "No recommendation yet" with reason>
```

## Operating Rules

- Do not ask multiple independent questions in one turn.
- Do not perform interrogation theater — every question must unlock a decision, reduce risk, or expose a dependency.
- Prefer evidence over asking when local artifacts can settle the matter.
- Keep recommendations provisional until the user confirms or corrects them.
- Do not implement or write final artifacts until core decisions are resolved or the user redirects.
- Do not create files by default. If asked to save the result, use a clear user-provided or inferred path.

## Next Step

This interview is done when every open decision branch is resolved.

- **If approved (all branches resolved):** hand off to whichever skill triggered the interview — typically `write-a-prd`, `write-a-story`, `brainstorming`, or the relevant implementation skill.
- **If not approved (an open branch remains):** continue interviewing that branch — do not hand off with an unresolved dependency.
