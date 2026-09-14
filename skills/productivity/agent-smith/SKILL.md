---
name: agent-smith
description: "Designs specialized subagents as a persona-and-operations definition with an explicit tool and model budget, boundaries against sibling agents, and a delegation test run before the agent ships. Use when creating an agent, writing a subagent, defining an agent persona, reviewing an agent definition file, or planning a roster of specialized agents."
argument-hint: "<agent idea, role, or draft agent file>"
---

# Agent Smith

Design agents a delegating model reaches for correctly, that stay inside their lane, and that carry only the tools and context their job needs.

## When to Use

Use this skill when the user wants to create, draft, review, or sharpen a specialized agent — a named persona that runs in its own context window with its own tool budget and returns work to whoever delegated to it. It covers the agent file — frontmatter, persona, and operations — its tool and model budget, the skills it preloads, roster boundaries, and the delegation test that proves the agent gets picked.

## When Not to Use

**A skill is knowledge the current agent loads. An agent is a colleague the current agent hands the work to.** That distinction decides which tool to reach for:

- Instructions that change how *this* agent performs a task, loaded into the running context — that is a skill. Use `skill-smith`.
- Driving agents that already exist through a multi-step plan — use `subagent-driven-development`.
- A one-off role prompt for a single message, never reused — write the prompt, skip the file.

## Artifacts

- Produces: `<agents-dir>/<name>.md` — the agent file, the one copy that both runs and gets reviewed. `<agents-dir>` is set by **One File, Where the Runtime Reads It**.
- Consumes: the existing agent roster, read for overlap and boundary checks.
- Consumes: the target's skills, read for know-how the agent should preload.

The path is fixed by the agent runtime, so it is not a configurable output location.

## Core Rule

An agent nobody delegates to is a file. Design the routing contract first — name, description, boundaries — then write the persona and workflow that make the delegation pay off.

## Workflow

1. **Name the job, not the topic.** `database` is a topic; `migration-archaeologist` is a job with an output. A name that reads as a role predicts what comes back.
2. **Read the existing roster.** List every sibling agent and its one-line remit. If the new agent's remit is a subset of one already there, extend that agent instead of adding a competitor — two agents that answer the same request make delegation a coin flip.
3. **Set the tool and model budget before writing prose.** See **Tool and Model Budget** below. This decision constrains everything after it: an agent with no write tools cannot promise fixes.
4. **Split the expertise from the know-how.** See **Expert Plus Skills** below. The step is done when every domain rule the agent needs on every run sits in a skill it preloads, or in its body with a reason no skill holds it.
5. **Draft the agent file.** Load `references/agent-template.md` for the frontmatter, the description that drives delegation, the section structure, and a worked example.
6. **Write the boundary section.** Name the sibling agents this one hands off to and what it declines. An agent with no stated edges expands into its neighbours.
7. **Test the delegation.** Load `references/testing-agents.md`. Run the target request without the agent, record what happens, then confirm the agent is picked and returns something the caller can use.
8. **Review against the checklist** below, then register the agent in the roster index if the repo keeps one.

## One File, Where the Runtime Reads It

The agent file is the source of truth: the copy that runs is the copy that gets reviewed, so there is no second copy to drift from it.

| Scope | `<agents-dir>` |
|---|---|
| One project | `.claude/agents/` — check it into version control so the team shares it |
| All the user's projects | `~/.claude/agents/` |
| A plugin | `agents/` at the plugin root — Claude Code ignores `hooks`, `mcpServers`, and `permissionMode` there |

Put the agent beside the target's existing agents; with none yet, use `.claude/agents/`. In a plugin, keep drafts and notes out of `agents/`: Claude Code loads every file there as a live agent.

## Tool and Model Budget

Every agent declares an explicit tool allowlist and a model tier. An agent granted every tool inherits every failure mode, and one left on the default model is priced by accident rather than by judgment.

| Archetype | Tools | Model | Why this budget |
|---|---|---|---|
| Reviewer, auditor, critic | `Read, Grep, Glob` | opus or sonnet | No write access, so findings stay reviewable instead of silently applied |
| Researcher, explorer | `Read, Grep, Glob, WebSearch, WebFetch` | sonnet | Reads widely, returns a synthesis, changes nothing |
| Implementer, fixer | `Read, Edit, Write, Bash, Grep, Glob` | opus | Needs the full loop, and the judgment to stop |
| Mechanical transformer | `Read, Edit, Bash` | haiku | Deterministic reshaping where a bigger model buys nothing |
| Interviewer, planner | `Read, Grep, Glob` | opus | Produces a document, not a diff |

**Separate the hand from the eye.** An agent that writes code is a poor judge of the code it just wrote — it defends its own choices. Split the reviewer from the implementer rather than granting one agent both budgets.

## Expert Plus Skills

An expert agent is two things: a stance and a body of know-how. Put the stance in the agent and the know-how in skills it preloads.

- **The agent holds the stance** — the domain it argues from, what it looks for, its boundaries, and its output contract.
- **Skills hold the know-how** — conventions, procedures, and reference facts. List them in the `skills` frontmatter field; Claude Code injects each one in full at startup, not only its description.

A subagent starts without the skills its caller has loaded, so name every skill it needs on every run. It can still fire an unlisted skill through the `Skill` tool, which suits know-how only some runs need.

1. Search the target's skills for the domain before writing any rule into the body. If one covers it, preload it — `tidb-engineer` for a TiDB migration reviewer.
2. If the know-how would serve another agent or the main thread, write it as a skill with `skill-smith` and preload that.
3. If it serves only this agent, keep it in the body.

Preload only what every run uses: each skill's full text costs context on every delegation.

## Persona That Earns Its Tokens

Every persona line is context the agent pays for on every run, so each one has to change an output.

- "You are a meticulous senior engineer who cares about quality" changes nothing — every model already answers that way.
- "You report 3–5 issues and refuse to raise one without a `file:line` and a reproduction" changes the shape of every response.

Apply the test to each line: **what would this agent produce differently if the line were deleted?** No answer means no line. This is the same no-op failure that bloats skills, and it costs more here — an agent's persona is reloaded on every delegation.
## Roster Boundaries

Agents overlap silently. Two symptoms, both worth catching before ship:

- **Ambiguous routing** — a request that two agents would both accept. Cure: sharpen one description until the request fits only one, and name the other in the boundary section.
- **Silent expansion** — an agent that starts fixing what it was asked to review, or documenting what it was asked to design. Cure: remove the tool that permits the expansion, not just the permission to use it.

Once a roster passes roughly five agents, keep a one-line remit per agent in an index so the next agent can be checked against it without reading five files.

## Reference Map

Load `references/agent-template.md` when drafting or reviewing an agent file — it holds the frontmatter fields, the three-sentence description, the section structure and per-section guidance, the line budget, and a complete worked example.

Load `references/testing-agents.md` when the agent is drafted and needs proof it works — the three agent-specific failure classes (routing, boundary, contract), scenario formats, and how to close a loophole.

## Review Checklist

Before finalizing:

- Does the name read as a job with an output rather than a topic?
- Does the description say **when to delegate** and **what comes back**, in that order?
- Is there a request two agents in this roster would both accept?
- Is the tool allowlist explicit, and is every listed tool needed for a deliverable the agent actually promises?
- Is the model tier a decision, with a reason someone could argue with?
- Does the agent preload the skills that hold its domain know-how, and only the ones every run uses?
- Does the agent have write access to anything it is also expected to judge?
- Does every persona line change an output — and would deleting it change behaviour?
- Does the boundary section name real sibling agents that exist?
- Are the deliverables concrete — a named format, a real example — rather than a description of a format?
- Are the success metrics observable by the caller from the returned work alone?
- Is the agent one file in the folder the runtime reads, with no second copy to drift from it?
- Was the delegation tested: the agent picked for the request it targets, and passed over for the neighbouring request it should decline?

## Next Step

Do not write the agent file or register the agent until the user has reviewed the draft.

- **If approved:** write it to `<agents-dir>/<name>.md` per **One File, Where the Runtime Reads It**, add the agent to the roster index if the repo keeps one, and run the delegation test in `references/testing-agents.md` against the live agent.
- **If not approved:** revise the draft in place. If the objection is overlap with an existing agent, return to step 2 and decide whether to extend that agent instead. If the objection is that the remit is too broad to test, split it into two agents and draft the narrower one first.
