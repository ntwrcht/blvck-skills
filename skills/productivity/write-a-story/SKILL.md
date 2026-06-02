---
name: write-a-story
description: "Backlog workflow for drafting, rewriting, splitting, reviewing, and converting plans into implementation-ready work items. Covers user stories, job stories, WWA items, issue breakdowns, acceptance criteria, readiness checks, and approved Jira payloads."
argument-hint: "<backlog item brief>"
---

# Write a Story

Shape rough product, engineering, or operational work into implementation-ready backlog stories and issue breakdowns. Keep the output tracker-neutral unless the user names a tracker, team convention, template, or field set.

## When to Use

Use this skill when the user wants to draft, rewrite, split, review, or prepare backlog work. It covers epics, stories, tasks, bugs, chores, spikes, issue breakdowns, acceptance criteria, Definition of Done, Sprint Readiness checks, and approved Jira creation or updates when a Jira MCP/tool is connected.

Good inputs include rough notes, PRDs, research findings, bugs, design decisions, incident follow-ups, verbal ideas, existing Jira text, or a request such as "write a story", "make this Jira-ready", "split this feature", "turn this plan into issues", "add acceptance criteria", or "is this sprint-ready?"

## When Not to Use

Do not use this skill for narrative fiction, brand storytelling, stakeholder updates, status reports, leadership rewrites, full product specs, or one-off implementation plans unless the requested output is a backlog item.

## Core Rule

Optimize for handoff quality. A good backlog item tells the next assignee what outcome is needed, why it matters, how done will be judged, and what constraints or unknowns need attention.

Do not invent business facts, customer impact, deadlines, owners, priorities, estimates, or dependencies. Mark unknowns explicitly and ask only when the missing detail blocks a useful draft or a tracker payload.

## Workflow

1. Ingest the input and choose the output shape: single item, feature breakdown, or review/rewrite.
2. Identify the decision that shapes the story: actor, outcome, scope boundary, value, readiness target, or tracker action.
3. Answer from available context first. Ask one concise question only when that decision would materially change the draft.
4. Choose the item format. Default to user stories for product-facing work; use job stories, WWA, or generic backlog items when requested or clearly better.
5. Draft the smallest useful backlog output: one cohesive item, multiple independent items, or an epic with children. For feature breakdowns, target 5-15 items only when the scope justifies it.
6. Add testable acceptance criteria, implementation notes, dependencies, risks, open questions, and Definition of Done or Sprint Readiness scoring when requested or relevant.
7. If Jira creation/update is requested and a Jira MCP/tool is connected, follow the Jira Integration workflow. Never create or update Jira issues before the user approves the exact payload.

## Reference Map

Load only the references needed for the current request:

- `references/story-formats.md`: user stories, job stories, WWA, 3 C's, and INVEST checks.
- `references/output-templates.md`: default item format, feature breakdown format, story map, and save-as-markdown behavior.
- `references/item-types-and-splitting.md`: epic/story/task/chore/bug/spike guidance and decomposition rules.
- `references/readiness.md`: acceptance criteria rules, Definition of Done, Sprint Readiness Score, and mental model triggers.
- `references/jira-integration.md`: Jira MCP/tool workflow, exact payload approval, multi-item creation, and field-mapping rules.
- `references/to-issues.md`: tracer-bullet vertical issue slicing, HITL/AFK classification, user review, and dependency-ordered issue publishing.

Default loading:

- For a normal single story or backlog item, load `story-formats.md` and `output-templates.md`.
- For feature decomposition, also load `item-types-and-splitting.md`.
- For readiness, Jira-ready, refinement, or Definition of Done requests, load `readiness.md`.
- For Jira creation, update, or sync requests, load `jira-integration.md` after drafting the items.
- For plan-to-issue conversion, implementation ticket creation, or tracer-bullet slicing, load `to-issues.md`; if the source plan is too vague to slice, use `grill-me` first.

## Output Rules

- Keep titles action-oriented and searchable.
- Prefer observable acceptance criteria over implementation checklists.
- Label assumptions and unknowns instead of smoothing them over.
- Keep tracker-specific language out unless requested.
- Preserve user-provided team conventions, templates, field names, and issue hierarchy.
- Save to a file or create/update Jira only after the user asks for that action.

## Follow-up Options

After generating a feature breakdown, offer 2-4 relevant follow-ups:

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
