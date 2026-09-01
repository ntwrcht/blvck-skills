---
name: prototype
description: "Builds a throwaway prototype to answer one design question — a single shareable HTML file to feel out a state model, or several switchable UI variants to explore a look. Use when sanity-checking whether logic or a state model feels right, exploring what a page or component should look like, or feeling out an API shape before committing."
---

# Prototype

A prototype is **throwaway code that answers a question**. The question decides the shape.

## When to Use

Use this skill for "prototype", "spike", "throwaway", "sanity-check this", "does this feel right", "what should this look like", "show me a few options", or "feel out the API / state model before I write it".

Two questions route to two branches — see **Pick a branch**.

## When Not to Use

- **The decision is about terminology or an architectural commitment, not a feeling.** Use `domain-modeling` to pin down contested terms and record an ADR. Prototype answers *"does this model feel right when I push it?"*; domain-modeling answers *"what do we call this, and what did we decide?"* Feel it out here, then record the verdict there.
- **You already know the answer.** No open question, no prototype — write the real code.
- **The output needs to be kept and maintained.** This skill produces disposable code by design; anything durable gets rewritten under normal constraints when the answer is folded in. Throwaway does not mean deleted — see **Rules that apply to both**, rule 6.

## Artifacts

- Produces: throwaway prototype code placed next to the module or page it prototypes for — locality is the convention, there is no fixed output path. Plus the captured answer (commit message, ADR, or issue) and the prototype itself committed to a `prototype/<name>` branch out of main.
- Consumes: nothing.

## Pick a branch

Identify which question is being answered — from the user's prompt, the surrounding code, or by asking if the user is around:

- **"Does this logic / state model feel right?"** → [LOGIC.md](LOGIC.md). Build a single shareable HTML file — free-play buttons plus tabbed guided walkthroughs — that pushes the state machine through cases that are hard to reason about on paper, and that a non-developer can drive.
- **"What should this look like?"** → [UI.md](UI.md). Generate several radically different UI variations on a single route, switchable via a URL search param and a floating bottom bar.

The two branches produce very different artifacts — getting this wrong wastes the whole prototype. If the question is genuinely ambiguous and the user isn't reachable, default to whichever branch better matches the surrounding code (a backend module → logic; a page or component → UI) and state the assumption at the top of the prototype.

## Rules that apply to both

1. **Throwaway from day one, and clearly marked as such.** Locate the prototype code close to where it will actually be used (next to the module or page it's prototyping for) so context is obvious — but name it so a casual reader can see it's a prototype, not production. For throwaway UI routes, obey whatever routing convention the project already uses; don't invent a new top-level structure.
2. **Trivial to run.** A UI prototype starts from one command in the project's task runner — `pnpm <name>`, `python <path>`, `bun <path>`, etc. A logic demo is a single HTML file the user double-clicks. Either way, no thinking required to start it.
3. **No persistence by default.** State lives in memory. Persistence is the thing the prototype is _checking_, not something it should depend on. If the question explicitly involves a database, hit a scratch DB or a local file with a clear "PROTOTYPE — wipe me" name.
4. **Skip the polish.** No tests, no error handling beyond what makes the prototype _runnable_, no abstractions. The point is to learn something fast.
5. **Surface the state.** After every action (logic) or on every variant switch (UI), print or render the full relevant state so the user can see what changed.
6. **Capture it when done.** Fold the validated decision into the real code, then capture the prototype itself as a **primary source**: commit it to a throwaway `prototype/<name>` branch, out of main, and leave a context pointer to that branch on the implementation issue. Capture the answer too — the verdict and the question it settled — in the issue or a commit. The main branch keeps only the validated decision, so nothing rots there, while the exploration stays findable.

## When done

Two things get captured, and they go to different places.

The **answer** is the durable artifact: the verdict plus the question it settled. Write it to a commit message, an ADR, or the implementation issue. If the user is around, that capture is a quick conversation; if not, leave the placeholder so they (or you, on the next pass) can fill in the verdict.

The **prototype** is a primary source, not rubbish. Throwaway means out of main, not deleted: commit it to a `prototype/<name>` branch and leave a context pointer to that branch on the implementation issue. A written-up verdict flattens what the prototype showed; the branch keeps the thing itself re-runnable when someone later asks "why did we decide that?" Main stays clean, because variant components and prototype shells left in main rot fast and confuse the next reader.

## Next Step

The prototype isn't finished until the user has driven it and stated the answer — which variant won, or whether the state model holds under real cases.

- **If approved (answer captured):** fold the validated decision into the real code — lift the pure logic module into its real home, or rewrite the winning UI variant properly into the page — then move the throwaway shell onto the `prototype/<name>` branch and drop it from main, leaving a context pointer on the implementation issue. If the answer settled a contested domain term or forced an architectural call, hand off to `domain-modeling` to record the glossary change or ADR.
- **If not approved (question still open):** add the actions or variants the user asked for and let them drive again — prototypes evolve. If the question itself turned out to be the wrong one, pause and reframe it with the user before building more.

---

_Adapted from the `prototype` skill in `mattpocock-skills`, MIT-licensed © 2026 Matt Pocock._
