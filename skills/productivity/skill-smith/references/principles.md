# Skill Smith — Principles

The WHY behind the decisions where wrong judgment is expensive and the rule alone doesn't explain the reasoning.

## Progressive Disclosure

**Why it matters beyond length:** Moving reference out of `SKILL.md` isn't primarily a token optimisation — it protects the information hierarchy. When steps and reference share the same level, the agent's attention spreads across both. Steps it should act on and facts it should consult become peers; attending to either becomes a coin-flip. Pushing reference behind a pointer restores the hierarchy: steps are primary, reference is secondary, reached only when the pointer fires.

**The judgment call:** Push material down when a branch exists that doesn't need it. If every run through the skill needs a piece of content, keep it inline — a pointer that always fires is just indirection with extra cost. If only some runs need it, disclose it: the branches that don't need it stop paying for it.

**Pointer wording decides reliability:** A context pointer's wording — not its target — determines when and how reliably the agent reaches the material. A must-have reference behind a weakly worded pointer is a variance bug. Fix the wording first; pull the material back inline only if sharpening the pointer fails.

## Leading Words

**Why one token beats a sentence:** A leading word works because it recruits priors the model already holds from pretraining. The model doesn't need to be taught what _fog of war_ means — it already has a dense network of associations (limited visibility, acting under uncertainty, incomplete information). Repeating the token activates that network each time, anchoring the same behaviour across the skill in fewer tokens than any sentence could.

**The judgment call:** Hunt for restatements — the same behavioural principle spread across two or three sentences. That is the signal a leading word exists. When you find one, ask: is there a pretrained word that already carries this concept? If yes, collapse to it. If no pretrained word fits, coin one and define it once — but know you are spending definition tokens that a pretrained word gives free.

**A weak leading word is a no-op:** If the word doesn't change the agent's behaviour past its default, it earns nothing. The fix is a stronger word, not a different technique.

## Completion Criteria

**Why vagueness is the root cause of premature completion:** Premature completion happens because the agent's attention slips toward being done rather than doing the work. A vague criterion ("understanding reached", "list produced") gives way under that pull — the agent declares done and moves on. A sharp, checkable criterion holds: the agent can test done from not-done and resists the pull regardless of how many steps follow.

**The judgment call — order of fixes:** Sharpen the criterion first. It is local and cheap. Only when the criterion is irreducibly fuzzy and you actually observe early exit do you split the step to hide what follows. Splitting only works across a real context boundary (a user-invoked handoff or a subagent dispatch) — an inline call leaves later steps visible and clears nothing.

**Applies to flat reference too:** A body of reference with no steps can still carry a completion criterion — "every rule applied", not "rules consulted". That bar drives legwork even without a step structure to enforce it.

**Clarity and demand are two different levers.** *Clarity* asks whether the agent can tell done from not-done. *Demand* asks how much the criterion requires. "Every modified model accounted for" forces thorough work where "produce a change list" does not — same clarity, different demand. Demand is what drives **legwork**: the digging the agent does inside the work, latent in the criterion's wording rather than written out as its own step. The strongest criteria are both checkable and exhaustive.

## Single Source of Truth

**Why duplication costs more than tokens:** Keep each meaning in one authoritative place, so changing the behaviour is a one-place edit. Duplication costs maintenance, but the subtler cost is rank: repeating a meaning inflates its prominence on the information hierarchy past what it actually deserves, so the agent weights it above material that matters more. (This is the accidental inverse of a leading word, which repeats a *token* on purpose and never the meaning.)

**The environment is a source of truth too.** `package.json` scripts, config files, the directory layout, `--help` output — these are authoritative on their own. A document that restates them is a **cache**: a copy of a lookup. A cache earns its load only when the lookup is expensive.

**The judgment call:** Cache what the agent cannot find by looking — the unwritten convention, the reason behind a choice, the gotcha no config confesses. Leave the one-file, one-command lookups to the environment, where they cannot go stale. A skill that lists the test command when `package.json` already names it has bought nothing and taken on a stale-copy risk.

## Steering by the Positive

**Why prohibition backfires:** Steering by negation drags the forbidden behaviour into context and makes it *more* available, not less. *Don't think of an elephant*, and the elephant is all there is. The negation is a weak modifier that the strongly-activated concept overruns, so the ban half-reads as an instruction to do the thing.

**The judgment call:** Prompt the positive. State the target behaviour ("write one-line comments") so the banned one is never spoken. A prohibition earns its place only as a hard guardrail you cannot phrase positively — and even then, pair it with the positive target so attention lands on what to do.

**Negative space is the same lever, unspoken.** Every decision a skill declines to make gets delegated to the agent's priors rather than left neutral. Read a draft for its *silences* and decide each omission deliberately: fill it, or leave it open as a real branch the agent is meant to choose within.

## Failure Modes

Four ways a skill degrades. Each has a distinct diagnostic and a distinct cure — treating them as one problem gets the wrong fix.

**Sediment** — stale layers that settle because adding feels safe and removing feels risky, until you must core down through them to find what is still live. *Diagnostic:* a line that no longer bears on what the skill does, because the behaviour or world it describes has changed. *Cure:* prune on a schedule, not on suspicion. Shorter documents stay relevant more easily.

**Sprawl** — the document is simply too long, even when every line is live and unique. *Diagnostic:* nothing is stale, nothing is duplicated, and it is still exhausting to read. Attention thins across the excess, and every extra line is one more to keep relevant. *Cure:* the information hierarchy — disclose reference behind pointers, and split by branch or sequence so each path carries only what it needs. Not pruning; there is nothing dead to cut.

**Duplication** — the same meaning in more than one place. *Diagnostic:* changing the behaviour would require editing two spots. *Cure:* pick the authoritative home and point at it from the other. Distinct from *scattering*, which fragments one meaning across many places rather than repeating it; the cure there is co-location.

**No-ops** — an instruction the model already obeys by default, paying load to say nothing. *Diagnostic:* does this line change behaviour versus the default? The test is model-relative, not reader-relative — two people who disagree about a no-op disagree about the *default*, and settle it by running the skill, not by debate. *Cure:* delete the whole sentence rather than trim words from it. The test grades leading words too: a word too weak to beat the default (*be thorough*, when the agent is already thorough-ish) is a no-op, and the fix is a stronger word (*relentless*), not a different technique.
