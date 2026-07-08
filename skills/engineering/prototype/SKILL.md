---
name: prototype
description: "Build a throwaway prototype to answer one design question — a hand-driven terminal app to feel out a state model, or several switchable UI variants to explore a look. Use when sanity-checking whether logic or a state model feels right, exploring what a page or component should look like, or feeling out an API shape before committing."
---

# Prototype

A prototype is **throwaway code that answers a question**. The question decides the shape.

## When to Use

Use this skill for "prototype", "spike", "throwaway", "sanity-check this", "does this feel right", "what should this look like", "show me a few options", or "feel out the API / state model before I write it".

Two questions route to two branches — see **Pick a branch**.

## When Not to Use

- **The decision is about terminology or an architectural commitment, not a feeling.** Use `domain-modeling` to pin down contested terms and record an ADR. Prototype answers *"does this model feel right when I push it?"*; domain-modeling answers *"what do we call this, and what did we decide?"* Feel it out here, then record the verdict there.
- **You already know the answer.** No open question, no prototype — write the real code.
- **The output needs to be kept and maintained.** This skill produces disposable code by design; anything durable gets rewritten under normal constraints when the answer is folded in.

## Artifacts

- Produces: throwaway prototype code placed next to the module or page it prototypes for — locality is the convention, there is no fixed output path. Plus the captured answer, written to a commit message, ADR, issue, or a `NOTES.md` beside the prototype.
- Consumes: nothing.

## Pick a branch

Identify which question is being answered — from the user's prompt, the surrounding code, or by asking if the user is around:

- **"Does this logic / state model feel right?"** → [LOGIC.md](LOGIC.md). Build a tiny interactive terminal app that pushes the state machine through cases that are hard to reason about on paper.
- **"What should this look like?"** → [UI.md](UI.md). Generate several radically different UI variations on a single route, switchable via a URL search param and a floating bottom bar.

The two branches produce very different artifacts — getting this wrong wastes the whole prototype. If the question is genuinely ambiguous and the user isn't reachable, default to whichever branch better matches the surrounding code (a backend module → logic; a page or component → UI) and state the assumption at the top of the prototype.

## Rules that apply to both

1. **Throwaway from day one, and clearly marked as such.** Locate the prototype code close to where it will actually be used (next to the module or page it's prototyping for) so context is obvious — but name it so a casual reader can see it's a prototype, not production. For throwaway UI routes, obey whatever routing convention the project already uses; don't invent a new top-level structure.
2. **One command to run.** Whatever the project's existing task runner supports — `pnpm <name>`, `python <path>`, `bun <path>`, etc. The user must be able to start it without thinking.
3. **No persistence by default.** State lives in memory. Persistence is the thing the prototype is _checking_, not something it should depend on. If the question explicitly involves a database, hit a scratch DB or a local file with a clear "PROTOTYPE — wipe me" name.
4. **Skip the polish.** No tests, no error handling beyond what makes the prototype _runnable_, no abstractions. The point is to learn something fast and then delete it.
5. **Surface the state.** After every action (logic) or on every variant switch (UI), print or render the full relevant state so the user can see what changed.
6. **Delete or absorb when done.** When the prototype has answered its question, either delete it or fold the validated decision into the real code — don't leave it rotting in the repo.

## When done

The _answer_ is the only thing worth keeping from a prototype. Capture it somewhere durable (commit message, ADR, issue, or a `NOTES.md` next to the prototype) along with the question it was answering. If the user is around, that capture is a quick conversation; if not, leave the placeholder so they (or you, on the next pass) can fill in the verdict before deleting the prototype.

## Next Step

The prototype isn't finished until the user has driven it and stated the answer — which variant won, or whether the state model holds under real cases.

- **If approved (answer captured):** fold the validated decision into the real code — lift the pure logic module into its real home, or rewrite the winning UI variant properly into the page — then delete the throwaway shell. If the answer settled a contested domain term or forced an architectural call, hand off to `domain-modeling` to record the glossary change or ADR.
- **If not approved (question still open):** add the actions or variants the user asked for and let them drive again — prototypes evolve. If the question itself turned out to be the wrong one, pause and reframe it with the user before building more.

---

_Adapted from the `prototype` skill in `mattpocock-skills`, MIT-licensed © 2026 Matt Pocock._
