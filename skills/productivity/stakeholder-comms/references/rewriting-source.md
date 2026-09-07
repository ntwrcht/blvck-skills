# Rewriting Existing Source

Rules for the **source-exists branch**: a ticket, postmortem, thread, engineer's draft, or commit series already carries the facts, and the work is register and audience, not discovery.

The job is translation, not authorship. Every fact in the output traces back to the source. If a fact is missing from the source, it stays missing from the output — ask, or say it is unknown.

## Preserve

State, impact, owner, next step, validation status, risk, workaround, and tracking references. These are the load-bearing content; losing one of them makes the rewrite useless to a reader who has to act.

Keep verbatim: Jira keys, PR numbers, release versions, customer or workload names, product names, team names, and owners.

## Strip

Function names, file paths, struct fields, code expressions, commit SHAs, environment variables, and line numbers — unless the user asks for an appendix that carries them.

## Translate

- Turn mechanism into one or two cause-and-effect sentences, without overstating certainty.
- Keep concept-level technical terms that carry real meaning for this audience: race condition, regression, queue, driver, kernel, synchronization, cache, rollout, rollback.
- Preserve unknowns as unknowns. "Root cause is still under investigation" is a fact; a confident-sounding paraphrase of a guess is not.
- Stay blameless, concrete, and active-voice.

## Never invent

Impact, owner, validation status, ETA, risk, mitigation, or recommendation. A rewrite that adds a plausible-sounding ETA is worse than one that says the ETA is unknown, because the reader cannot tell which parts came from the source.

## Audience default

Write for managers, directors, VPs, PMs, TPMs, release managers, support leads, and cross-functional partners — readers who understand product and system concepts but do not need to read code. Do not make the copy customer-facing, marketing-oriented, legal, finance, or true ELI5 unless the user asks for that audience explicitly; `references/audience-rules.md` carries the sanitization rules when they do.

## Review

- Does the first line answer what changed, or what state the work is in?
- Are impact, owner, next step, and risk explicit when the source knows them?
- Are tracking references preserved?
- Is code-level detail removed or translated, not just shortened?
- Are unknowns represented honestly?
