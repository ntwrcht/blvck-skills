---
name: wait-what
description: "Re-pitches the message that just failed to land, adding the missing context and dropping the jargon. Use when a reply lost the reader through unexplained jargon, a skipped step, or missing context; the user runs it with /wait-what."
argument-hint: "(nothing — the last message is the target)"
disable-model-invocation: true
---

# Wait, What

That did not land. Re-pitch that, going back to where the reader got lost.

Give a little more context than before, write in ASD-STE100 Simplified Technical English, and use the ubiquitous language from `CONTEXT.md` — follow `CONTEXT-MAP.md` to the right one if the repo has more than one. Where the repo has neither, take the nouns from the reader's own messages, and open with the re-pitch itself.

## When to Use

Use when a message lost the reader: unexplained jargon, a leap the reader could not follow, or an answer that assumed context they did not have.

## When Not to Use

- **The reader wants it shorter, not clearer** — use `caveman`. That skill strips words; this one adds the missing context while cutting the jargon. Reaching for the wrong one makes a confusing message shorter and more confusing.
- **The message was clear and simply wrong** — correct it. A re-pitch of a wrong answer is still wrong.

## Artifacts

- Produces: nothing — the re-pitch is a new reply in the conversation
- Consumes: `CONTEXT.md`, `CONTEXT-MAP.md`

## Why It Is This Short

The mechanism is the name. Concision skills fail by growing: a 400-line skill about being clear still leaves the model verbose. So this one is a single precise leading word and almost nothing else.

Naming the *output* (`/tldr`, `/no-fluff`) makes the model clip words and lose the reader further. Naming the **listener's state** asks for both halves at once — fewer words *and* the context that was missing.

## Next Step

This skill repairs one message; it has no pipeline stage after it, so it needs no handoff. The cure for messages that keep failing to land is a shared vocabulary built up front: when the user has fired `/wait-what` three times in one conversation, end that re-pitch with one line suggesting `/grilling` with docs to establish one in `CONTEXT.md`.

---

_Adapted from the `wait-what` skill in `mattpocock-skills`, MIT-licensed © 2026 Matt Pocock._
