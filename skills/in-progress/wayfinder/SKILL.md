---
name: wayfinder
description: "Charts work too large for one agent session as a map of decision tickets on the issue tracker, then resolves them one ticket at a time until the route to the destination is clear. Use when a loose idea spans multiple sessions, when planning needs a durable shared artifact, or when open decisions must be sequenced before implementation starts."
disable-model-invocation: true
argument-hint: "<loose idea to chart, or the map to work>"
---

# Wayfinder

Chart work too large for one agent session as a map of decision tickets on the issue tracker, then resolve them one at a time until the way to the destination is clear.

Wayfinding finds the way; it does not charge at the destination. Name the **destination** first — the spec, decision, or change this effort is heading for — because it fixes the scope of every ticket that follows.

## When to Use

Use this skill when a loose idea is too big to hold in one agent session and the route to it is still foggy: multi-session planning, a decision backlog that needs sequencing, or an effort several people pick up in parallel. The map is domain-agnostic — engineering work, course content, anything with open decisions and a destination.

## When Not to Use

- **The whole journey fits in one session** — use `brainstorming` for a rough idea, or `grill-me` to resolve a plan's open branches. If charting surfaces no fog, you don't need a map.
- **A plan is already approved and needs building** — use `subagent-driven-development`. Wayfinder runs before a plan exists.
- **Issues already on the tracker need classifying** — use `triage`. Wayfinder creates tickets; triage sorts incoming ones.
- **One long session needs compacting for the next agent** — use `handoff`. Wayfinder holds state across many sessions; handoff carries one across a boundary.

## Artifacts

- Produces: tracker state — one map issue labelled `wayfinder:map` plus its child decision tickets, via connected tool
- Consumes: `.context/wayfinder.md` (tracker mapping), `.context/project.md`, `CONTEXT.md`
- Bundled: `references/map-format.md`, `references/ticket-types.md`, `references/tracker-mapping.md`, `research-prompt.md` — dispatch template for research tickets

## Core Rule

Plan, don't do. Every ticket resolves a decision, not a slice of a build, and the map is done when nothing is left to decide. The pull to just do the work signals you have reached the edge of the map and it is time to hand off. An effort can override this in its map **Notes** — carrying execution into the map itself — but absent that, produce decisions, not deliverables.

## Refer by Name

Every map and ticket is an issue, so it has a name — its title. In everything the human reads, refer to it by that name, never a bare id or number. A wall of `#42, #43, #44` is illegible; names read at a glance. A name wraps its link, so the id rides inside it and never stands in for it.

## Fog of War

The map is deliberately incomplete. Beyond the live tickets lies fog — decisions you can tell are coming but cannot yet pin down, because they hang on questions still open. Resolving a ticket clears the fog ahead of it, graduating whatever became specifiable into fresh tickets.

**Fog or ticket?** The test is whether you can state the question precisely now, not whether you can answer it. A sharp question is a ticket even when blocked; anything blurrier stays in the map's **Not yet specified** section. Do not pre-slice fog into ticket-sized pieces — one patch may graduate into several tickets, or none.

Fog gathers only *toward* the destination. Work past the destination is not fog, it is **out of scope**, and it gets its own section. See `references/map-format.md`.

## Workflow: Chart the Map

The user invokes with a loose idea.

1. Establish the tracker mapping before writing anything — see `references/tracker-mapping.md`.
2. **Name the destination.** Run `grilling` and `domain-modeling` to pin down what this map is finding its way to. Scope settles first.
3. **Map the frontier.** Grill again, breadth-first: fan across the whole space rather than deep down one thread, surfacing the open decisions and the steps takeable now. If this surfaces no fog, stop — the journey fits one session and needs no map. Ask the user how they want to proceed.
4. **Create the map**, labelled `wayfinder:map`, using `references/map-format.md`: destination and notes filled in, decisions empty, fog sketched into **Not yet specified**.
5. **Create the tickets you can specify now** as child issues. Create in dependency order so each ticket can name its blockers at creation; a second pass wires only the edges pointing at tickets that did not exist yet.
6. **Dispatch the research tickets** in parallel as subagents using `research-prompt.md`; each posts its findings as its own resolution comment.
7. Stop. Charting is one session's work and resolves nothing by hand.

## Workflow: Work the Map

The user invokes with a map. A ticket is optional — without one, you pick.

1. Load the map — the low-resolution view, not every ticket body.
2. Choose a ticket from the frontier: open, unblocked, unclaimed. **Claim it first** by assigning it to yourself before any work, so concurrent sessions skip it.
3. Resolve it, zooming as needed: fetch the full body of a related or closed ticket on demand, and invoke the skills the map's **Notes** name. Default to `grilling` and `domain-modeling`.
4. Post the answer as a resolution comment, close the ticket, and append a one-line gist plus link to the map's **Decisions so far**.
5. Graduate any fog the answer sharpened into new tickets, clearing each graduated patch from **Not yet specified**. Rule out of scope anything the answer put past the destination. Update or delete tickets the decision invalidated.

Expect concurrent sessions — the user may work unblocked tickets in parallel.

## Operating Rules

- Never resolve more than one ticket per session, research tickets excepted.
- Never restate a decision on the map. The map indexes; the ticket holds.
- A HITL ticket resolves only through live exchange — never answer the human's side of it.
- Show the planned tracker mutation and get approval before applying it. Batch the ticket set at charting time rather than asking per issue.
- Every comment or issue posted to a tracker must start with `> *This was generated by AI during wayfinding.*`

## Reference Map

- `references/map-format.md`: load when creating or updating the map or a ticket body.
- `references/ticket-types.md`: load when labelling a new ticket or choosing how to resolve one.
- `references/tracker-mapping.md`: load at the start of every session to resolve map, child, blocking, and frontier operations for this repo's tracker.
- `research-prompt.md`: load when dispatching a subagent against a `wayfinder:research` ticket.

## Next Step

The map is done when no tickets remain and nothing is left to decide.

- **If approved:** hand off to `write-a-prd` or `write-a-story` to turn the resolved decisions into requirements. Building the result is the user's call, not a route you can take — `subagent-driven-development` is user-invoked, so name it as their next step rather than invoking it.
- **If not approved:** an open ticket remains — keep working the map one ticket per session. If the destination itself was wrong, redraw it as a fresh map rather than resuming this one.
