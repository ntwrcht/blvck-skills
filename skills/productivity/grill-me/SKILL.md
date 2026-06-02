---
name: grill-me
description: "Shape goals, context, decisions, risks, dependencies, and tradeoffs through a focused interview loop. Use when the user asks to be grilled, stress-test a plan, clarify a vague proposal, prepare for review, or decide before implementation."
---

# Grill Me

Turn an unclear plan into resolved decisions by interviewing one dependency at a time.

## When to Use

Use this skill when the user wants to be grilled, stress-test a plan, sharpen a design, prepare for review, choose among tradeoffs, or convert vague intent into a clear goal, context, decision set, and next action.

Use `scrutinize` when the user wants findings on an already written plan, PR, or design doc. Use an implementation skill when the user asks for direct changes instead of an interview.

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

## Workflow

1. Restate the current goal in one sentence. If the goal is unclear, make that the first question.
2. Inspect available artifacts before asking questions that local files, docs, tests, logs, or supplied material can answer.
3. Pick the highest-leverage unresolved branch in the decision frame.
4. Ask exactly one question.
5. Include why it matters and a provisional recommendation when there is enough evidence.
6. Wait for the user's answer, then update the frame and move to the next dependency.
7. When major branches are resolved, summarize agreed decisions, open questions, risks, validation plan, and next action.

## Question Format

Use this shape for each turn:

```text
Question: <one narrow question>
Why it matters: <decision or risk it unlocks>
Recommendation: <provisional answer, or "No recommendation yet" with reason>
```

## Operating Rules

- Do not ask multiple independent questions in one turn.
- Do not perform interrogation theater; every question must unlock a decision, reduce risk, or expose a dependency.
- Prefer evidence over asking when local artifacts can settle the matter.
- Keep recommendations provisional until the user confirms or corrects them.
- Do not implement or write final artifacts until core decisions are resolved or the user redirects.
- Do not create files by default. If asked to save the result, use a clear user-provided or inferred path.
