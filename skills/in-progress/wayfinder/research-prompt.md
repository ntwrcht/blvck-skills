# Research Prompt Template

Use this template when dispatching the subagent that resolves a `wayfinder:research` ticket.

**Dispatch when:** a ticket labelled `wayfinder:research` is on the frontier. These are the one type safe to run several at a time — each is read-only and independent, so fire the whole batch in parallel rather than one per session.

**The subagent surfaces facts, it does not make the decision.** A research ticket exists because a decision downstream is waiting on a fact. Answer the question asked; leave the judgment to the ticket that depends on it.

```
Subagent:
  description: "Research: [TICKET_NAME]"
  prompt: |
    You are resolving one research question for a planning map. Your job is to
    surface facts a later decision depends on — not to make that decision.

    ## Question

    [TICKET_QUESTION]

    ## Why it is being asked

    [ONE_LINE_FROM_THE_MAP_DESTINATION_OR_BLOCKED_TICKET]

    ## What to do

    Read documentation, third-party API references, local knowledge bases, or
    the codebase — whatever settles the question. Prefer primary sources over
    summaries, and prefer checking over assuming.

    ## What to report

    - **Answer** — the fact, stated plainly in two or three sentences.
    - **Sources** — a link or file path per claim. An unsourced claim is a guess.
    - **Confidence** — high, medium, or low, and what would raise it.
    - **Surprises** — anything you found that the question did not anticipate but
      that changes the picture. This is often worth more than the answer.
    - **Still unknown** — what you could not settle, and why.

    Do not recommend a course of action. Do not modify any files.
```

## Recording the result

Post the subagent's report as the ticket's resolution comment, prefixed with the AI disclaimer, then close the ticket and gist it into the map's **Decisions so far**.

If the report's **Surprises** or **Still unknown** sections opened new questions, graduate them — sharp ones become tickets, blurry ones go to **Not yet specified**.

If the answer came back low-confidence and a downstream decision genuinely cannot proceed without it, do not close the ticket. Re-scope the question and dispatch again, or convert it to a `task` ticket if the fact requires access nobody has yet.
