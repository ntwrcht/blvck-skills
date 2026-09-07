---
name: grilling
description: "Shapes a rough idea or stress-tests an existing plan by interviewing the user as a decision tree — proposing approaches before asking, asking each round of unblocked questions together with a recommended answer, and writing the approved design. Use when brainstorming a new feature or product idea, grilling a plan, stress-testing a proposal, clarifying vague intent, resolving decisions before implementation, or capturing domain terms and ADRs as the decisions land."
argument-hint: "<idea to shape, or plan to stress-test> [with docs]"
---

# Grilling

Map the plan as a **decision tree** and work it in **rounds** until the frontier is empty. When there is no plan yet, propose the options first — never ask the user to invent them.

## When to Use

Use this skill in two situations that share one mechanic:

- **Shaping.** The user has an idea, feature request, or product concept and no plan: "let's build X", "I want to add Y", "help me figure out how to do Z". It runs before any implementation-shaped step — before code, scaffolding, or a task list.
- **Stress-testing.** A plan, design, or proposal already exists and has open decisions: sharpening it, choosing among tradeoffs, pinning down dependencies, or turning vague intent into a clear goal and next action.

## When Not to Use

- **A written plan, PR, or design doc needs findings rather than an interview** — use `scrutinize`. Scrutinize reviews an artifact from the outside; grilling questions its author from the inside.
- **The user asked for a direct change, a quick answer, or a small well-understood edit** — make the change. Interviewing here is theater.
- **The blocking knowledge sits in another person's head** — use `to-questionnaire`. **It sits in external docs or a library's source** — use `research`.

## Artifacts

- Produces: design doc at the `design` key path — see `references/artifact-paths.md` (default `docs/design/<slug>.md`). Written by default after a shaping session; on request after a stress-test.
- Produces, in docs mode: glossary entries in `CONTEXT.md` and ADRs, both through `domain-modeling`
- Consumes: `.context/project.md`, `CONTEXT.md`, recent commits
- Bundled: `references/spec-reviewer-prompt.md` — dispatch template for the design review

## Docs Mode

When the user asks for the session "with docs", or wants the decisions captured rather than only resolved, run `domain-modeling` alongside the interview. As each round settles a term, challenge it against the glossary and record the canonical one; as each hard, surprising, real-tradeoff decision lands, record it as an ADR. The interview mechanics below do not change — docs mode only adds the writing-down as the frontier shrinks.

Plain mode is the default. Offer docs mode once at the start when the plan touches domain vocabulary or an architectural commitment, then respect the answer.

## Core Rule

Resolve upstream decisions before downstream details. Propose options before asking the user to choose. Ask the whole frontier each round, and give every question a recommended answer. No implementation-shaped step starts until the user has approved the outcome — a simple idea gets a short design, not no design.

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

1. Read available context before asking anything: `.context/project.md`, `CONTEXT.md`, recent commits, and the plan if one exists.
2. Restate the current goal in one sentence. If the goal is unclear, the first round is about the goal and nothing else.
3. Dispatch sub-agents for any facts the frontier needs from the environment.
4. **Options round** *(shaping only)*. Once goal and context are settled, open the next round with 2–3 concrete approaches and their tradeoffs. Lead with a recommendation and why. Then ask the questions each approach unblocks. Never more than three approaches — more slows the decision without adding clarity. If the idea spans independent subsystems, say so here and split it into separate designs rather than one.
5. Compute the frontier: every decision whose prerequisites are settled.
6. Ask the whole frontier in one round, in the format below, with a recommended answer on every question.
7. Wait for the user's answers. Fold sub-agent findings in as they report.
8. Recompute the frontier and ask the next round. Repeat.
9. When the frontier is empty, summarize agreed decisions, open risks, the validation plan, and the next action.
10. **Write the design** *(shaping by default, stress-test on request)*. Write the summary as a design doc to the `design` key path, sections scaled to the decision's complexity. Then dispatch an independent reviewer using `references/spec-reviewer-prompt.md` and resolve what it finds. Do not skip the review, even for a short design.

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
- Do not rewrite or refactor unrelated code or docs while shaping — stay scoped to what serves this idea.

## Reference Map

- `references/spec-reviewer-prompt.md`: dispatch template for the independent design review in step 10.

## Next Step

The session is done when the frontier is empty and, where a design was written, the reviewer's findings are resolved. Do not act on the plan until the user confirms you have reached a shared understanding.

- **If approved (frontier empty, understanding confirmed):** hand off to `write-a-prd` for formal requirements, to `write-a-story` for backlog items, or directly to an implementation skill (`tdd`, `angular-engineer`, `next-engineer`, `python-engineer`, `strapi-engineer`, `supabase-engineer`) for small scope. For a multi-task build, tell the user to run `/subagent-driven-development`.
- **If not approved (the frontier still has entries, or the design was rejected):** run the next round, or revise the design in place using the bundled reviewer loop — do not hand off with an unresolved dependency.
