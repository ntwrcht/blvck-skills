# Map and Ticket Format

The map is a single issue labelled `wayfinder:map` — the canonical artifact. Its tickets are child issues of it.

The map is an **index**, not a store. It lists the decisions made and points at the tickets holding their detail. A decision lives in exactly one place — its ticket — so the map gists and links, never restates.

## Map body

The whole map at low resolution, loaded once per session. Open tickets are deliberately absent: they are open child issues, found by query.

```markdown
## Destination

What reaching the end of this map looks like — the spec, decision, or change this
effort is finding its way to. One or two lines; every session orients to it before
choosing a ticket.

## Notes

Domain; skills every session should consult; standing preferences for this effort.

## Decisions so far

- Closed ticket title, linked to its issue — one-line gist of the answer

## Not yet specified

- In-scope fog that cannot be ticketed yet; graduates as the frontier advances

## Out of scope

- Work ruled beyond the destination, linked to its closed ticket; never graduates
```

## Ticket body

Each ticket is a child issue of the map, sized to one 100K-token agent session. The tracker's issue id is its identity.

```markdown
## Question

The decision or investigation this ticket resolves.
```

The answer is not part of the body — it arrives as a resolution comment when the ticket closes. Assets created while resolving a ticket are linked from the issue, never pasted into it.

Each ticket carries a `wayfinder:<type>` label — see `ticket-types.md`.

## Claiming

A session claims a ticket by assigning it to the dev driving the map, **first**, before any work, so concurrent sessions skip it. That assignee *is* the claim: an open, unassigned ticket is unclaimed.

## Blocking and the frontier

Blocking uses the tracker's native dependency relationship — essential because it renders the frontier visually in the tracker's own UI, so the human sees what is takeable without opening the map. Only a tracker lacking native blocking falls back to a body convention; see `tracker-mapping.md`.

A ticket is **unblocked** when every ticket blocking it is closed. The **frontier** is the set of open, unblocked, unclaimed children — the edge of the known.

## Not yet specified

The written form of the fog: the suspected question, the area to revisit later. Everything here is in scope, just not sharp enough to ticket. Write it as loosely or as fully as the view allows; it doubles as a signpost for collaborators reading where the effort is headed.

It excludes what is already decided, what is already a live ticket, and what is out of scope.

When a resolution sharpens a patch into a statable question, graduate it into a ticket and delete the patch — it must not live in two places.

## Out of scope

Work consciously ruled beyond *this* effort. Scope, not sharpness, lands it here. Out-of-scope work never graduates — the frontier stops at the destination — so it returns only if the destination is redrawn, and then as a fresh map, not a resumption.

Ruling something out of scope is a scoping act, not a step on the route. When an existing ticket turns out to sit past the destination — mis-scoped while charting, or exposed by a later resolution — **close it**, because a closed ticket is unambiguously off the frontier, and leave one line in **Out of scope**: the gist, why it is out, and a link to the closed ticket.

It stays out of **Decisions so far**, which records the route actually walked. A scope boundary is not a step on it.
