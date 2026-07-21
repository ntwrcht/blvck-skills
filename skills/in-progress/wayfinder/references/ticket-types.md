# Ticket Types

Every ticket carries exactly one `wayfinder:<type>` label: `research`, `prototype`, `grilling`, or `task`.

## HITL and AFK

Every ticket is either **HITL** — human in the loop, worked *with* a human who speaks for themselves — or **AFK**, driven by the agent alone.

A HITL ticket resolves only through that live exchange. The agent never stands in for the human's side of it; a grilling agent that answers its own questions has broken this, and the resulting decision is worthless because nobody made it.

## Research (AFK)

Reading documentation, third-party APIs, or local resources like knowledge bases to surface a fact a decision waits on.

Use when knowledge outside the current working directory is required. Resolved by a **subagent** dispatched with `research-prompt.md` — this is the one type safe to run several at a time, because each is read-only and independent. The subagent posts its findings as the ticket's resolution comment, linking sources.

The subagent surfaces the fact; it does not make the decision waiting on that fact.

## Prototype (HITL)

Raise the fidelity of the discussion by making something cheap, rough, and concrete to react to — an outline, a rough take, a stub, or UI and logic code via the `prototype` skill. Link the prototype from the issue as an asset.

Use when "how should it look" or "how should it behave" is the key question, and argument in the abstract has stopped moving.

## Grilling (HITL)

Conversation via the `grilling` and `domain-modeling` skills, one question at a time. **The default case** — reach for it unless another type clearly fits better.

## Task (HITL or AFK)

Manual work that must happen before a *decision* can be made: nothing to decide, prototype, or research, but the discussion is blocked until it is done. Signing up for a service so its API can be judged, provisioning access, moving data so its shape can be seen.

This is the one type that *does* rather than decides, and it earns its place by unblocking a decision, not by delivering the destination. A task that delivers part of the destination is execution, not wayfinding — leave it for the handoff.

The agent drives it alone where it can (AFK); otherwise it hands the human a precise checklist (HITL). Resolved when the work is done. The answer records what was done plus any resulting facts later tickets depend on — where credentials live, new URLs, row counts.
