---
name: to-questionnaire
description: "Turns a decision the user cannot answer alone into a Markdown questionnaire aimed at the one person who can, interviewing them about the send rather than the subject. Use when knowledge sits with someone else, when preparing discovery questions for a stakeholder or domain expert, or when drafting an async request for information."
argument-hint: "<the decision you can't answer alone>"
disable-model-invocation: true
---

# To Questionnaire

Turn something the user cannot answer alone into a **questionnaire**: a Markdown document they hand to one person to fill in async. The recipient holds knowledge the user lacks; the questionnaire pulls it out of them.

## Grill the Send, Not the Subject

This is the move that makes the skill work. A normal `grilling` session interrogates the *subject* — which is exactly what the user cannot answer here, or they would not need the questionnaire.

So interview the user only about the **send**, which they can always answer: who it goes to, and what they need back. The questions in the document then target the **gap** between what the recipient knows and what the user needs.

## When to Use

Use when the blocking knowledge sits with another person: a domain expert, a customer, a partner team, a stakeholder with context the user lacks.

## When Not to Use

- **The user can answer it themselves with enough pushing** — use `grilling`. This skill is the inverse: it mines someone else, not the user.
- **The goal is reporting outward, not pulling inward** — use `stakeholder-comms`. That skill tells people things; this one asks them.
- **The unknown is a fact in a document, not in a person's head** — use `research`.

## Artifacts

- Produces: questionnaire at the `questionnaire` key path — see `references/artifact-paths.md` (default `docs/questionnaires/<slug>.md`)
- Consumes: `.context/project.md`, `CONTEXT.md`

## Workflow

1. **Ask about the send, in one round.** Read `.context/project.md` and `CONTEXT.md` first, where they exist, to pre-fill recommendations. Follow `references/asking-the-user.md`: recommend an answer from whatever the conversation and context already say, number the questions, accept shorthand, and skip any question the user already answered. Ask:
   - **Who is it going to?** The recipient's role, expertise, and relationship to the user — this fixes the questionnaire's tone and how much context it must carry.
   - **What do you need back?** The specific decisions or facts the user cannot resolve alone and needs from this person.

   Ask about the subject itself only for a fact the Context paragraph needs and the conversation lacks — at most one question. Leave out any menu of subject topics to cover; which topics matter is what the recipient answers. Done when you know who the recipient is, what they know that the user does not, and have a concrete list of what the user must walk away able to do or decide.
2. **Draft the questions.** Aim them at the gap from step 1, following the structure below. Lead each item from step 1 with the question that settles it, worded in the user's terms — for "does Stripe's invoice format satisfy our auditors", ask about Stripe's format, not what an invoice must contain in general. If answering needs material the recipient must see, such as a sample invoice, and the user has not provided it, name it in the question as "the sample invoice we'll attach", never "I've attached", and put it first in a **Before you send** checklist after the questionnaire, so the user attaches it before sending. If a question joins two asks with *and* or *or*, split it or cut one — the recipient answers the first half and skips the second. Keep at most two questions per item from step 1, plus the closing catch-all, so the recipient can answer in one pass. Done when every item from step 1 has a question, no question carries two asks, and the count is within that cap.
3. **Write the questionnaire.** Write it to the `questionnaire` key path and report the path. Done when the file exists.

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

## Reference Map

- `references/asking-the-user.md`: the house style the intake round follows.

## Next Step

The questionnaire is not finished until the user has read it as the recipient would and confirmed it asks for what they actually need.

- **If approved:** the user sends it. When answers come back, hand off to `grilling` to work the decision the answers unblocked, or to `write-a-prd` / `write-a-story` if the answers complete a product artifact.
- **If not approved:** ask which item from step 1 the draft failed to cover, or which question the recipient could not answer, and revise in place — do not send a questionnaire the user cannot picture the recipient answering.

---

_Adapted from the `to-questionnaire` skill in `mattpocock-skills`, MIT-licensed © 2026 Matt Pocock._
