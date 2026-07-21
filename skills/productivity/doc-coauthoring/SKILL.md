---
name: doc-coauthoring
description: "Co-authors a document with the user section by section — gathering their context, brainstorming and curating each section, then testing the draft against a fresh reader with no context. Use when writing a proposal, technical spec, decision doc, RFC, design doc, or similar long-form content where the user holds the context."
argument-hint: "<doc type or topic to co-author>"
---

# Doc Co-Authoring

Guide the user through writing one document they own, in three stages: close the context gap, build the doc section by section, then test it on a reader who knows nothing.

## When to Use

Use when the user wants to write a substantial document and is the one holding the context: "write a doc", "draft a proposal", "create a spec", "write this decision up", or a named type such as design doc, decision doc, or RFC. It fits when the audience is other people — or their agents — and a blind spot costs a confused reader.

## When Not to Use

- The conversation or repo already carries enough context to synthesize a draft without interviewing — use `write-a-prd` for a PRD, `write-a-story` for backlog items, `post-mortem` for an RCA.
- The idea or decision itself is unsettled — use `brainstorming` to shape it or `grilling` to force the open questions, then come back to write it up.
- Source material exists and only needs reframing for an audience — use `management-talk` or `stakeholder-update`.
- A draft already exists and the ask is review rather than authoring — use `scrutinize`.

## Artifacts

- Produces: the document at the path the user names in Stage 1 (default `docs/<slug>.md`), or edits an existing file in place. Not in the shared artifact-paths registry — the target is the user's own doc, often one that already exists.
- Consumes: whatever the user supplies — templates, linked docs, channels, prior drafts.

## Core Rule

The user owns the doc. Close the context gap before writing a word of it: no section gets drafted before its clarifying questions are answered, and the doc is not done until a reader with zero context has been tested against it.

## Workflow

1. Offer the workflow — name the three stages and what each one buys. If the user declines, write freeform and don't re-offer.
2. **Stage 1 — Context gathering.** Ask the meta questions (doc type, audience, intended impact, template, constraints), take the user's info dump, then ask 5-10 numbered clarifying questions. Load `references/context-gathering.md`.
3. Exit Stage 1 only when questions can probe edge cases and trade-offs without needing basics re-explained. Ask whether to add more context or start drafting.
4. Agree the section list, then write the file as a scaffold of headers with placeholders.
5. **Stage 2 — Refinement and structure.** Run the per-section loop: clarify, brainstorm, curate, gap-check, draft, refine. Start with the section holding the most unknowns; leave summaries for last. Load `references/section-loop.md`.
6. **Stage 3 — Reader testing.** Predict what readers will ask, then dispatch subagents that see only the document and one question each. Load `references/reader-testing.md`.
7. Fix every gap reader testing exposes by looping back to step 5 for the failing sections. Re-test after fixing.
8. Hand ownership back: tell the user to do a final read themselves and to verify facts, links, and technical details. They are responsible for the doc's quality.

## Operating Rules

- **Edit surgically.** Change the file with targeted edits; never reprint the whole document into the conversation.
- **Ask for change requests, not edits.** Tell the user to say what to change rather than editing the file themselves — their phrasing teaches style for the next section. If they do edit directly, keep the change and read it as a preference signal.
- **Keep brainstorms in the conversation.** Option lists never go into the document file.
- **Close gaps immediately.** When the user names an entity, project, or doc that isn't understood, ask right then. Gaps compound.
- **Pull rather than paste when tools allow.** If connectors or MCP servers are available for the channels and doc stores the user names, offer to read them directly; otherwise ask for a paste.
- **Prune on plateau.** After three iterations with no substantial change to a section, ask what can be cut without losing information.
- **Give the user an exit.** They can skip a stage or move faster at any point. If they sound frustrated, name it and offer a shorter path rather than pushing through the full loop.

## Reference Map

- `references/context-gathering.md`: Stage 1 — meta questions, info-dump prompts, template and image handling, clarifying-question batch, exit condition.
- `references/section-loop.md`: Stage 2 — section ordering, scaffold creation, the six-step per-section loop, quality checks, whole-document pass.
- `references/reader-testing.md`: Stage 3 — reader-question prediction, subagent test protocol and prompt, no-subagent fallback, exit condition.

## Review Checklist

- Does every section answer questions a reader would actually ask, not just the ones the author found interesting?
- Is anything in the doc unexplained jargon, an unstated assumption, or a claim only the author can verify?
- Do the sections agree with each other — no contradictions, no repeated content?
- Does every sentence carry weight, or is there generic filler that survived because cutting felt risky?
- Has a fresh reader been tested against the doc and stopped surfacing new gaps?

## Next Step

The user does the final read and approves — the doc is theirs, not the agent's.

- **If approved:** hand off to `write-a-story` when the doc is a spec or proposal that needs implementation items, or to `stakeholder-update` or `management-talk` to announce it to a specific audience.
- **If not approved:** loop back to Stage 2 for the failing sections and re-run reader testing. If the feedback shows the underlying decision was never settled, stop writing and escalate to `grilling`.
