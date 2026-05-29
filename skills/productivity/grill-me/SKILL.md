---
name: grill-me
description: >
  Plan and design pressure-testing workflow that resolves decisions, risks, and
  tradeoffs one question at a time, using codebase or artifact checks when
  available.
---

# Grill Me

Interview the user about a plan or design until the important decisions, dependencies, risks, and tradeoffs are explicit.

## Workflow

1. Restate the plan or design in one concise sentence. If the goal is unclear, make the first question about the goal.
2. Build an internal decision tree: goal, constraints, users, success criteria, alternatives, dependencies, risks, rollout, validation, and rollback.
3. Ask one question at a time.
4. For each question, provide a recommended answer with rationale before asking the user to confirm or correct it.
5. If a question can be answered by inspecting the codebase, docs, config, tests, logs, or supplied artifacts, inspect those first instead of asking.
6. Follow dependencies: do not ask downstream questions until the upstream decision they depend on is resolved.
7. When enough branches are resolved, summarize the agreed decisions, remaining open questions, and highest risks.

## Question Style

Each turn should contain:

- The next question.
- Why the question matters.
- Recommended answer.

Keep the question narrow enough for the user to answer directly. Avoid dumping a questionnaire.

## Operating Rules

- Be persistent but not performative. The goal is shared understanding, not interrogation theater.
- Do not skip obvious codebase checks.
- Do not accept vague answers when they block a later decision. Ask a sharper follow-up.
- Do not propose implementation until the core decisions are resolved.
- Do not generate files by default.
- If the user explicitly asks to save the resolved decisions, ask for or infer a clear destination path before writing.
