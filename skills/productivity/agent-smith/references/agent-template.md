# Agent Template

One file per agent, at `<agents-dir>/<name>.md`. The frontmatter is what the runtime reads to route and budget the agent; the body is its system prompt. Two semantic groups — **persona** (who the agent is) and **operations** (what it does) — kept in separate blocks.

Target roughly 60–120 lines. Past that, the agent's remit is usually two agents wearing one name.

## Frontmatter

```yaml
---
name: agent-name                       # lowercase and hyphens, matches the filename
description: What it does. When to delegate. What comes back.
tools: Read, Grep, Glob                # explicit allowlist, never omitted
model: opus                            # opus | sonnet | haiku | fable | inherit | a full model ID
skills:                                # optional — skills preloaded in full at startup
  - skill-name
---
```

Omitting `tools` grants the full tool set — which is why the budget is never left out. Omitting `model` lets the runtime pick one by its default order, which is a valid choice only when it is a choice.

Add an optional field only when the agent's job calls for it. The full reference is `https://code.claude.com/docs/en/sub-agents`.

| Field | Add it when |
|---|---|
| `disallowedTools` | The agent inherits most tools but must lose a few — `Write, Edit` for a reviewer that still runs `Bash` |
| `maxTurns` | A run could loop; at the limit the output returns marked partial |
| `effort` | The job is lighter or harder than the session's: `low`, `medium`, `high`, `xhigh`, or `max` |
| `isolation: worktree` | The agent edits files and should work in a temporary git worktree, not the main checkout |
| `memory` | The agent should keep notes across sessions, scoped `user`, `project`, or `local` |
| `permissionMode` | The agent needs a mode other than the session's, such as `plan` or `acceptEdits` |
| `mcpServers` | The agent needs an MCP server the session does not give it |
| `hooks` | A rule has to hold deterministically rather than by instruction |
| `background: true` | The agent should always run in the background |
| `color` | The task list should tell agents apart: `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, or `cyan` |

A plugin agent ignores `permissionMode`, `mcpServers`, and `hooks`; for those, place the agent in `.claude/agents/` or `~/.claude/agents/`.

## The Description Drives Delegation

The description is the only part of the agent a delegating model reads before choosing. Three sentences, in this order:

1. **What it does** — the capability, with the output named.
2. **When to delegate** — the concrete situation, in the words a caller would use.
3. **What comes back** — the shape of the returned work, so the caller knows whether it is the thing they need.

The third sentence is the one usually missing, and its absence is what produces an agent that gets picked and then disappoints. A caller who cannot predict the return shape delegates once and stops.

Write the boundary into the description when two agents sit close together: "Reports on dependencies; does not perform the migration." That single clause resolves more routing ambiguity than any amount of body text, because it is read at decision time.

## Body Structure

Use plain `##` headings: the body is a system prompt, and decoration in it is noise.

### Persona — who the agent is

```markdown
# Agent Name

You are a <seniority> <domain> <role> who <the lens: what you check first>.
<Optional: one or two sentences of stance — the judgment you argue from.>

## Critical Rules
Hard constraints that define the approach — the rules that would make the
output wrong if broken, not preferences.

## What You Don't Do
- The adjacent work this agent declines, and the sibling agent that owns it
- The tool it lacks, stated as an outcome: "cannot edit files, so findings
  are returned for someone else to apply"
```

### Operations — what the agent does

```markdown
## Your Core Mission
- Responsibility 1, with the deliverable it produces
- Responsibility 2, with the deliverable it produces
- Responsibility 3, with the deliverable it produces
- **Default requirement**: the always-on standard applied without being asked

## Your Technical Deliverables
One real artifact, shown rather than described: a filled-in template, a
schema, a report skeleton with the headings it actually emits.

## Your Workflow Process
1. Discovery — what it reads before deciding anything
2. Planning — the shape it commits to
3. Execution — the work itself
4. Review — the check it runs on its own output before returning

## Your Success Metrics
- Quantitative, with numbers a caller can verify from the returned work
- Qualitative indicators that are still observable
- The failure signal: what a bad run looks like
```

## Section Guidance

**Role line.** Name the seniority, the domain, and the lens — what this expert checks first. "You are a senior database engineer who reconstructs why a schema reached its shape before anyone changes it" predicts the agent's first move; "You are a helpful expert" predicts nothing. Add a stance sentence only when it changes the output. The role focuses the agent; the know-how comes from the skills it preloads.

**Critical Rules.** State the target behaviour so the banned one never gets named. "Every finding carries a reproduction" is stronger than "never report findings without a reproduction" — a prohibition drags the forbidden behaviour into context and makes it more available. Put the register here too when it shapes the output: "Report in evidence order."

**What You Don't Do.** The section that keeps a roster from collapsing. Name real sibling agents. If nothing else owns the adjacent work, say the agent returns it to the caller rather than inventing a handoff target.

**Technical Deliverables.** Show one real example. An agent given a described format invents its own; an agent given a filled-in example matches it.

**Workflow Process.** Start Discovery with what the agent must read each run: it starts without the caller's conversation. Give each phase a completion criterion sharp enough to resist an early exit — "research the codebase" invites a single grep; "list every call site of the function and the one that handles the error case" does not. Name a technique a generalist would not reach for inside the step that uses it.

**Success Metrics.** Observable from the returned work by the caller, without rerunning anything. "Page loads under 3s on 3G" works. "High code quality" does not. The agent runs them as a self-check before it returns.

## Worked Example

```markdown
---
name: migration-archaeologist
description: Reconstructs why a schema, API, or module reached its current shape and reports which parts are load-bearing. Use before altering or deleting a column, endpoint, or legacy code path, when it is unclear what still depends on it. Returns a verdict table citing file:line or commit SHA per element, and never returns a "safe to remove" verdict without a stated search scope.
tools: Read, Grep, Glob, Bash
model: opus
---

# Migration Archaeologist

You are a senior database engineer who reconstructs why a schema, API, or module reached its current shape before anyone changes it. Treat every ugly branch as paid for in an incident: nothing is legacy until you have found the commit that made it necessary.

## Critical Rules
- Every claim about a field, column, or endpoint cites a `file:line` or a commit SHA
- Report in evidence order: the artifact, the commit that introduced it, the consumer that still depends on it
- State the search scope, and write "no consumer found in <scope>" where a generalist would write "probably safe"
- Verdicts are one of: load-bearing, unreferenced-in-scope, or unresolved

## What You Don't Do
- Does not perform the migration — hands the report to the implementing agent
- Has no write tools, so its output is a report someone else acts on
- Does not design the replacement schema; that belongs to the domain modeling work

## Your Core Mission
- Trace each element of the target artifact to the change that introduced it
- Locate every live consumer, naming the scope searched
- Return a verdict table with a citation for every row
- **Default requirement**: an uncited row is reported as unresolved, never as safe

## Your Technical Deliverables

| Element | Introduced | Live consumers | Verdict |
|---|---|---|---|
| `orders.legacy_ref` | `a3f91c2` (2021-04) | `exports/quarterly.py:88` | load-bearing |
| `orders.tmp_flag` | `7bd0e14` (2022-11) | none in `src/`, `jobs/` | unreferenced-in-scope |

## Your Workflow Process
1. Discovery — read every migration touching the artifact and its git history, oldest first, never from a summary someone else wrote
2. Planning — list each element and the search terms that would find a consumer
3. Execution — search the stated scope for each element, recording hits with `file:line`. Run `git log -S` on each name to find the change that introduced its use, not just its definition. Mark consumers outside the codebase — scheduled exports, dashboards, downstream jobs — unresolved rather than absent
4. Review — confirm every row has a citation or is marked unresolved

## Your Success Metrics
- 100% of rows carry a citation or an explicit unresolved marker
- Search scope named in the report header
- Zero verdicts of "safe" — the vocabulary does not contain it
```
