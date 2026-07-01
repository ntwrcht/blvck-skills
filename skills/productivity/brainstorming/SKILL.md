---
name: brainstorming
description: "User entry point for shaping a rough idea into an approved design. Use when the user wants to brainstorm a new feature, component, or product idea before writing a plan or touching code."
disable-model-invocation: true
argument-hint: "<idea or feature to shape>"
---

# Brainstorming

Turn a rough idea into a written, approved design — propose options, don't just ask the user to invent them.

## When to Use

Use this skill when the user has an idea, feature request, or product concept with no existing plan and wants it shaped into a design: "let's build X", "I want to add Y", "help me figure out how to do Z". It runs before any implementation-shaped step — before code, before scaffolding, before a plan.

## When Not to Use

- The user explicitly asks for a quick answer or a small, well-understood change — respect that and skip the design step.
- A plan, PR, or design doc already exists and the ask is to review or stress-test it, not generate one from scratch.

## Artifacts

- Produces: design doc at the `design` key path — see `references/artifact-paths.md` (default `docs/design/<slug>.md`)
- Consumes: `.context/project.md`, `CONTEXT.md`
- Bundled: `spec-reviewer-prompt.md` — dispatch template for step 6

## Core Rule

Propose options before asking the user to invent them. No implementation-shaped step — code, scaffolding, config, or a plan — starts until the user has approved a written design; a simple idea gets a short design, not no design.

## Workflow

1. Read available context (`.context/project.md`, `CONTEXT.md`, recent commits) before asking anything.
2. Ask clarifying questions one at a time — purpose, constraints, success criteria. Prefer multiple-choice when it fits; open-ended is fine too.
3. Once the goal is clear, propose 2-3 concrete approaches with tradeoffs. Lead with a recommendation and why.
4. Present the design in sections scaled to its complexity; confirm each section before moving to the next.
5. Write the approved design to the `design` key path (see `references/artifact-paths.md`).
6. Dispatch an independent reviewer subagent using `spec-reviewer-prompt.md` against the written design. Resolve any issues it finds before moving on.
7. Report the design as written and approved. Stop there — what happens next is the user's call.

## Operating Rules

- One question at a time during step 2.
- Don't propose more than 3 approaches; more options slow the decision without adding clarity.
- Don't skip the reviewer dispatch, even for a short design.
- If the idea spans multiple independent subsystems, say so before going deeper — help split it into separate designs instead of cramming everything into one.
- Don't rewrite or refactor unrelated code or docs while shaping the design — stay scoped to what serves this idea.

## Next Step

No implementation-shaped step — code, scaffolding, config, or a plan — starts until the user has approved a written design.

- **If approved:** hand off to `write-a-prd` for formal requirements, or directly to an implementation skill (`tdd`, `angular-engineer`, `python-engineer`, `strapi-engineer`, `subagent-driven-development`) for small scope.
- **If not approved:** revise the design in place using this skill's own reviewer loop (the bundled `spec-reviewer-prompt.md`) — do not proceed to `write-a-prd` or any code until approval is explicit.
