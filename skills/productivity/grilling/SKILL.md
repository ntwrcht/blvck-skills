---
name: grilling
description: "Interviews the user relentlessly about a plan or design, mapping it as a decision tree and asking each round of unblocked questions together until nothing is left assumed. Use when grilling a plan, stress-testing a proposal, clarifying vague intent, or resolving decisions before implementation."
---

# Grilling

Map the plan as a **decision tree** and work it in **rounds** until the frontier is empty.

## When to Use

Use this skill when a plan, design, or proposal has open decisions that should be resolved before work starts: stress-testing a proposal, sharpening a design, choosing among tradeoffs, pinning down dependencies, or turning vague intent into a clear goal and next action.

## When Not to Use

- **A written plan, PR, or design doc needs findings rather than an interview** — use `scrutinize`. Scrutinize reviews an artifact from the outside; grilling questions its author from the inside.
- **The idea is still rough and has no shape yet** — use `brainstorming`. Brainstorming generates the options; grilling resolves them. If there is nothing to interrogate, there is nothing to grill.
- **The user asked for a direct change, a quick answer, or a small well-understood edit** — make the change. Interviewing here is theater.

## Artifacts

- Produces: goals doc at the `goals` key path (on request) — see `references/artifact-paths.md` (default `docs/goals/<slug>.md`)
- Consumes: `.context/project.md`

## Core Rule

Resolve upstream decisions before downstream details. Ask the whole frontier each round, and give every question a recommended answer.

## The Decision Tree

Every decision branches into the decisions that hang off it. The **frontier** is every decision whose prerequisites are already settled — the questions you can ask *now* without guessing at answers you have not heard yet.

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round.

A question whose answer depends on another question still open in *this* round belongs to a *later* round, not this one. That test is what keeps a round from becoming a questionnaire.

## Decision Frame

Use this frame to find the branches — each dimension is a place unasked questions hide:

- Goal: the outcome, user, and success signal.
- Context: current system, constraints, assumptions, prior decisions, and non-goals.
- Decision: the choice being made now and the options being rejected.
- Tradeoffs: cost, complexity, reversibility, time, quality, performance, security, and maintenance.
- Dependencies: people, systems, data, tools, approvals, and sequence constraints.
- Risks: failure modes, unknowns, blast radius, and ways the plan can be wrong.
- Validation: evidence that will prove the decision worked.
- Rollback: how to undo or limit damage.

Goal and context are upstream of everything else — they are the first round.

## Facts Are Your Job

Finding *facts* is your job, never the user's. When a frontier question needs a fact from the environment — the filesystem, the codebase, docs, logs, tools — dispatch a sub-agent to find it. Never ask the user for anything you could look up yourself.

Do not block on it. A running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now.

The *decisions* are the user's. Put each to them and wait.

## Workflow

1. Restate the current goal in one sentence. If the goal is unclear, the first round is about the goal and nothing else.
2. Dispatch sub-agents for any facts the frontier needs from the environment.
3. Compute the frontier: every decision whose prerequisites are settled.
4. Ask the whole frontier in one round, in the format below, with a recommended answer on every question.
5. Wait for the user's answers. Fold sub-agent findings in as they report.
6. Recompute the frontier and ask the next round. Repeat.
7. When the frontier is empty, summarize agreed decisions, open risks, the validation plan, and the next action.

## Round Format

```text
❓ **Q1** — **<question title>**: <question body, which may run to several paragraphs and may offer multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** — **<question title>**: <question body>

➡️ <your recommended answer>
```

Number the questions and separate them with a horizontal rule. One round per turn, then stop and wait.

## Operating Rules

- Ask the whole frontier in one round — batching independent questions is the point. Splitting them across turns spends the user's turns for nothing.
- Keep dependent questions out of the current round. If Q2's answer only makes sense once Q1 is settled, Q2 is next round.
- Every question must unlock a decision, reduce risk, or expose a dependency. No interrogation theater.
- Give every question a recommendation, and keep it provisional until the user confirms or corrects it.
- Look it up before asking it. A question the environment can answer is a sub-agent task, not a round entry.
- Do not implement or write final artifacts until the frontier is empty or the user redirects.
- Do not create files by default. If asked to save the result, use a clear user-provided or inferred path.

## Next Step

The session is done when the frontier is empty: every branch of the decision tree visited, nothing left silently assumed. Do not act on the plan until the user confirms you have reached a shared understanding.

- **If approved (frontier empty, understanding confirmed):** hand off to whichever skill triggered the interview — typically `write-a-prd`, `write-a-story`, `brainstorming`, or the relevant implementation skill.
- **If not approved (the frontier still has entries):** run the next round — do not hand off with an unresolved dependency.
