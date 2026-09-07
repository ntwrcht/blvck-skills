---
name: to-questionnaire
description: "Turns a decision the user cannot answer alone into a Markdown questionnaire aimed at the one person who can, interviewing them about the send rather than the subject. Use when knowledge sits with someone else, when preparing discovery questions for a stakeholder or domain expert, or when drafting an async request for information."
argument-hint: "<the decision you can't answer alone>"
disable-model-invocation: true
---

# To Questionnaire

Turn something the user cannot answer alone into a **questionnaire**: a Markdown document they hand to one person to fill in async, or work through together in a meeting. The recipient holds knowledge the user lacks; the questionnaire pulls it out of them.

## Grill the Send, Not the Subject

This is the move that makes the skill work. A normal `grilling` session interrogates the *subject* — which is exactly what the user cannot answer here, or they would not need the questionnaire.

So interview the user only about the **send**, which they can always answer: who it goes to, and what they need back. The questions in the document then target the **gap** between what the recipient knows and what the user needs.

## When to Use

Use when the blocking knowledge sits with another person: a domain expert, a customer, a partner team, a stakeholder with context the user lacks. Also use when preparing discovery questions ahead of a meeting.

## When Not to Use

- **The user can answer it themselves with enough pushing** — use `grill-me`. This skill is the inverse: it mines someone else, not the user.
- **The goal is reporting outward, not pulling inward** — use `stakeholder-comms`. That skill tells people things; this one asks them.
- **The unknown is a fact in a document, not in a person's head** — use `research`.

## Artifacts

- Produces: questionnaire at the `questionnaire` key path — see `references/artifact-paths.md` (default `docs/questionnaires/<slug>.md`)
- Consumes: `.context/project.md`, `CONTEXT.md`

## Workflow

1. **Who is it going to?** Ask, in one exchange, the recipient's role, expertise, and relationship to the user. This fixes the questionnaire's tone and how much context it must carry. Done when you know who the recipient is and what they know that the user does not.
2. **What do you need back?** Ask, in one exchange, the specific decisions or facts the user cannot resolve alone and needs from this person. Done when you have a concrete list of what the user must walk away able to do or decide.
3. **Write the questionnaire.** Draft questions aimed at the gap from steps 1–2, following the structure below. Write it to the `questionnaire` key path and report the path. Done when the file exists and every item the user named in step 2 is covered by a question.

## Document Structure

Frame it as a **discovery questionnaire**: the user lacks context, the recipient holds it.

Order questions most-important-first — async means you may only get one pass. Group them under `##` headings by theme once there are more than a handful.

```markdown
# <Questionnaire title>

**Purpose:** why this questionnaire exists and the decision riding on it.

**From:** <the user>, **To:** <the recipient>, **How your answers will be used:** <where they go>

## Context

One paragraph orienting a recipient who was not in the user's head. Enough to answer well, not a page.

## How to answer

Deadline and rough effort. Partial answers and "I don't know" are useful — flag anything you are unsure of rather than skipping it.

## <Theme heading>

### <One question, one idea, never compound>

_Why this matters: <one line, only where the question could be misread or invite a throwaway answer>._

>

## Anything else?

A closing catch-all: anything we did not ask that we should know?
```

Every question is one idea, never compound, with an answer stub (`>`) directly beneath it.

## Next Step

The questionnaire is not finished until the user has read it as the recipient would and confirmed it asks for what they actually need.

- **If approved:** the user sends it. When answers come back, hand off to `grilling` to work the decision the answers unblocked, or to `write-a-prd` / `write-a-story` if the answers complete a product artifact.
- **If not approved:** ask which item from step 2 the draft failed to cover, or which question the recipient could not answer, and revise in place — do not send a questionnaire the user cannot picture the recipient answering.

---

_Adapted from the `to-questionnaire` skill in `mattpocock-skills`, MIT-licensed © 2026 Matt Pocock._
