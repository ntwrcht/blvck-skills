---
name: write-story
description: "Backlog item workflow for drafting, rewriting, splitting, reviewing readiness, adding acceptance criteria or Definition of Done, and preparing approved Jira payloads when a Jira MCP/tool is connected."
argument-hint: "<backlog item brief>"
---

# Write Story

Create clear, implementation-ready backlog items that can work in any tracker. Stay generic unless the user names a specific tracker, team convention, template, or field set.

Use this skill as the lightweight path for turning a feature, requirement, or rough idea into backlog-ready work. Do not require full PRD inputs such as goals, metrics, non-goals, launch plan, or detailed business context unless the missing context makes the story outcome unclear.

## When to Use

Use this skill for turning rough notes, PRDs, research findings, bugs, design decisions, incident follow-ups, or verbal ideas into implementation-ready backlog work. It covers epics, stories, tasks, bugs, chores, spikes, acceptance criteria, Definition of Done, Sprint Readiness checks, and approved Jira creation or updates when a Jira MCP/tool is connected.

If the user asks for a stakeholder update, status report, or leadership rewrite instead of a work item, use the more specific update or rewrite skill when available.

## Core Rule

Optimize for handoff quality. A good backlog item tells the next assignee what outcome is needed, why it matters, how done will be judged, and what constraints or unknowns need attention.

Do not invent business facts, customer impact, deadlines, owners, priorities, estimates, or dependencies. Mark unknowns explicitly and ask only when the missing detail blocks a useful draft.

## Workflow

1. Ingest the input and choose the output shape: single item, feature breakdown, or review/rewrite.
2. Choose the item format. Default to user stories for product-facing work; use job stories or WWA when requested or clearly better. Ask one short format question only when team convention matters.
3. Extract the outcome, actor or audience, scope, constraints, dependencies, risks, and missing facts. Mark unknowns instead of inventing.
4. Draft the smallest useful backlog output: one cohesive item, multiple independent items, or an epic with children. For feature breakdowns, target 5-15 items only when the scope justifies it.
5. Add testable acceptance criteria, useful implementation notes, open questions, and optional Definition of Done or Sprint Readiness scoring when requested or relevant.
6. If Jira creation/update is requested and a Jira MCP/tool is connected, follow the Jira Integration workflow. Never create or update Jira issues before the user approves the exact payload.

## Reference Map

Load only the references needed for the current request:

- `references/story-formats.md`: user stories, job stories, WWA, 3 C's, and INVEST checks.
- `references/output-templates.md`: default item format, feature breakdown format, story map, and save-as-markdown behavior.
- `references/item-types-and-splitting.md`: epic/story/task/chore/bug/spike guidance and decomposition rules.
- `references/readiness.md`: acceptance criteria rules, Definition of Done, Sprint Readiness Score, and mental model triggers.
- `references/jira-integration.md`: Jira MCP/tool workflow, exact payload approval, multi-item creation, and field-mapping rules.

Default reference loading:

- For a normal single story or backlog item, load `story-formats.md` and `output-templates.md`.
- For feature decomposition, also load `item-types-and-splitting.md`.
- For readiness, Jira-ready, refinement, or Definition of Done requests, load `readiness.md`.
- For Jira creation, update, or sync requests, load `jira-integration.md` after drafting the items.

## Next Steps

After generating a feature breakdown, offer 2-4 relevant next steps:

- Generate test scenarios for the backlog items.
- Create development or QA dummy data.
- Estimate sprint capacity or phase the work.
- Convert between user stories, job stories, WWA, and generic backlog items.
- Extract an epic summary and child-item list.
- Review the backlog against INVEST or team readiness criteria.
- Create approved items in Jira if a Jira MCP/tool is connected.
- Escalate to a fuller product spec if goals, metrics, scope, rollout, or non-goals need deeper discussion.

## Review Checklist

Before finalizing:

- Is the title action-oriented and searchable?
- Can a new assignee understand the goal without private conversation history?
- Are scope boundaries explicit enough to prevent surprise expansion?
- Are acceptance criteria testable?
- Are dependencies, risks, and unknowns visible?
- Is tracker-specific language avoided unless requested?
- Are invented facts labeled as assumptions or removed?
