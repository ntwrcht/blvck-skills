# Tracker Mapping

Wayfinder needs four operations from a tracker: **map**, **child of a map**, **blocking**, and **frontier query**. How each is expressed is tracker-specific, so resolve the mapping before charting or working a map.

## Resolving the mapping

1. Read `.context/wayfinder.md`. If it exists, it is authoritative — use it and skip the rest.
2. Read `.context/INDEX.md` and `.context/project.md` for a tracker already declared for this repo.
3. Inspect the repo for a connected tracker: a GitHub or GitLab remote, an existing Jira project reference, a tracker MCP tool already available in the session.
4. If none of the above settles it, ask the user which tracker to use, then write the answer to `.context/wayfinder.md` so later sessions skip this step. Run `setup-context` if the repo has no `.context/` at all.
5. If no tracker is available, fall back to local markdown (below).

## Per-tracker operations

**GitHub** — via `gh` or a GitHub MCP tool. Verified against `gh` 2.96.0; check `gh issue create --help` if a flag is rejected.

- Map: an issue labelled `wayfinder:map`.
- Child: a sub-issue — `gh issue create --parent <map>`, or `gh issue edit <n> --parent <map>`.
- Blocking: the native relationship — `gh issue create --blocked-by 200,201`, or `gh issue edit <n> --add-blocked-by 200`.
- Claim: `gh issue edit <n> --add-assignee @me`.
- Frontier: open sub-issues of the map with no assignee and no open blocker.

Because `gh issue create` takes both `--parent` and `--blocked-by`, tickets created in dependency order need no second pass — only edges pointing at a not-yet-created ticket do.

**GitLab** — via `glab` or a GitLab MCP tool.

- Map: an issue labelled `wayfinder:map`.
- Child: a child item of the map's work item.
- Blocking: a linked issue with the "is blocked by" link type.
- Frontier: open children with no assignee and no open blocking link.

**Jira** — via a connected Jira MCP tool.

- Map: an issue labelled `wayfinder:map`.
- Child: an issue whose parent is the map.
- Blocking: the "is blocked by" issue link.
- Frontier: JQL over open children, `assignee IS EMPTY`, with no unresolved blocker.

**Other trackers** — use available tools only when they support reading issues, creating children, and applying the approved mutations. Confirm the mapping with the user before the first mutation.

## Local-markdown fallback

Use only when no tracker is available. It loses the visual frontier — the main reason blocking is native — so treat it as a stopgap, and offer to migrate to a real tracker before the map grows past a handful of tickets.

- Map: `.context/wayfinder/<slug>.md`, following `map-format.md`.
- Child: `.context/wayfinder/<slug>/NNNN-<ticket-slug>.md`, numbered in creation order.
- Blocking: a `Blocked by:` line in the ticket body listing ticket filenames.
- Claim: an `Assignee:` line in the ticket body.
- Status: a `Status: open | closed` line; the resolution comment appends under a `## Answer` heading.
- Frontier: ticket files that are open, unassigned, and whose every `Blocked by:` entry is closed.

`<slug>` is a short kebab-case name derived from the destination. If a map already exists under that slug, ask whether to resume it or start a new one — never silently overwrite.

Graduating this fallback to a keyed entry in the shared `artifact-paths.md` registry is a prerequisite for shipping this skill out of `in-progress/`.
