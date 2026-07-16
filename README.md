<div align="center">

# 🛠️ Blvck Skills

**A general-purpose library of agent skills for AI coding assistants — Claude Code, Codex, and Gemini CLI.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-informational)](.claude-plugin/plugin.json)
[![Skills](https://img.shields.io/badge/skills-29-success)](#skill-catalog)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#contributing)

</div>

---

## Introduction

AI coding assistants are powerful generalists, but real work demands specialists: an agent that debugs with discipline, reviews with skepticism, or writes a PRD your stakeholders can actually read. Re-typing long prompts every session does not scale to that level of quality.

**Blvck Skills** packages that expertise into **skills** — versioned, installable instruction sets that an agent discovers by name and description, then loads in full only when the task calls for it. Each skill carries deep domain knowledge, architectural guidance, and standardized workflows, so every project you work in gets the same expert behavior with zero prompt repetition.

Install skills per project with the bundled installer, pull them with `npx skills add`, or load the whole library as a **Claude Code plugin**.

## Table of Contents

- [Key Features](#key-features)
- [Skill Catalog](#skill-catalog)
- [Architecture Overview](#architecture-overview)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Security & Trust](#security--trust)
- [Contributing](#contributing)
- [License](#license)

## Key Features

- **29 production-ready skills** spanning daily engineering work (debugging, TDD, review, security) and product workflows (PRDs, stories, stakeholder updates, plan interviews).
- **Multi-CLI support** — one library installs into Claude Code, Codex, and Gemini CLI, each in its native format.
- **Interactive installer with preset bundles** — curated *Project PM* and *Project Dev* scenarios for one-keystroke setup, or a custom picker across the full catalog.
- **Safe, reversible installs** — every copied skill carries an ownership marker; the uninstaller only ever removes what the installer created.
- **Progressive disclosure by design** — agents read a skill's name and two-sentence description first, and load the detailed instructions only when relevant, keeping context lean.
- **Shared reference injection** — common conventions (artifact paths, git workflow, context templates) materialize into each skill that needs them, so behavior stays consistent across skills.
- **Quality gates for the library itself** — bundled scripts lint every public skill description against overly forceful activation wording.

## Skill Catalog

### Engineering

| Skill Name | Description |
| :--- | :--- |
| [**Angular Engineer**](skills/engineering/angular-engineer/SKILL.md) | Builds, modifies, reviews, and debugs Angular applications using project conventions, modern Angular patterns, RxJS, Signals, testing, SSR, and Nx guidance. Use when working on Angular components, services, routing, forms, guards, migrations, performance, security, or frontend architecture. |
| [**Domain Modeling**](skills/engineering/domain-modeling/SKILL.md) | Builds and sharpens a project's domain model by challenging fuzzy language, updating the shared glossary inline, and recording hard architectural decisions as ADRs. Use when pinning down domain terminology, resolving contested terms, recording an architectural decision, or when another skill needs to maintain the domain vocabulary. |
| [**Debug Mantra**](skills/engineering/debug-mantra/SKILL.md) | Debugs failures with a compact repro, fail-path trace, hypothesis falsification, and breadcrumb ledger. Use when investigating a bug or failure needs lightweight structure before proposing a fix. |
| [**Diagnose**](skills/engineering/diagnose/SKILL.md) | Diagnoses hard bugs and performance regressions through a disciplined feedback-loop investigation. Use when a bug, flaky failure, crash, hang, data issue, or slowdown needs reproduction, minimisation, hypotheses, instrumentation, a fix, and a regression test. |
| [**GA4 Measurement**](skills/engineering/ga4-measurement/SKILL.md) | Plans, implements, reviews, and validates GA4/GTM measurement for product flows, funnels, feature adoption, conversion, errors, and performance. Use when designing event taxonomies, dataLayer or gtag tracking, GA4 reports, GTM setup, analytics QA, or measurement plans. |
| [**Git Guardrails**](skills/engineering/git-guardrails/SKILL.md) | Installs Claude Code PreToolUse hooks that block dangerous git commands before execution. Use when setting up local or global guardrails for git push, force push, reset --hard, clean, branch deletion, checkout ., or restore . |
| [**Post-mortem**](skills/engineering/post-mortem/SKILL.md) | Writes engineering post-mortems for fixed and validated bugs with symptom, root cause, mechanism, fix, validation, and follow-ups. Use when closing a bug, drafting an RCA, documenting a fix, or converting a debug ledger into a maintainer-readable record. |
| [**Prototype**](skills/engineering/prototype/SKILL.md) | Builds a throwaway prototype to answer one design question — a hand-driven terminal app to feel out a state model, or several switchable UI variants to explore a look. Use when sanity-checking whether logic or a state model feels right, exploring what a page or component should look like, or feeling out an API shape before committing. |
| [**Python Engineer**](skills/engineering/python-engineer/SKILL.md) | Builds, modifies, reviews, and debugs Python projects with architecture, packaging, typing, testing, linting, async, data access, and reliability guidance. Use when working on Python application code, libraries, CLIs, services, tooling, refactors, test strategy, or code review. |
| [**Scrutinize**](skills/engineering/scrutinize/SKILL.md) | Reviews plans, PRs, diffs, design docs, and code changes from an external verification stance. Use when pressure-testing intent, simpler alternatives, traced code paths, behavioral claims, edge cases, tests, or rollout risk. |
| [**Security Audit**](skills/engineering/security-audit/SKILL.md) | Reviews application security across code, APIs, infrastructure, authentication, authorization, secrets, dependencies, and compliance gaps. Use when assessing vulnerabilities, threat models, pentest findings, security controls, exploitability, impact, or remediation plans. |
| [**Strapi Engineer**](skills/engineering/strapi-engineer/SKILL.md) | Builds, modifies, reviews, and debugs Strapi applications across content types, controllers, services, routes, policies, lifecycle hooks, plugins, auth, GraphQL, and tests. Use when working on Strapi v4 or v5 backend code, project architecture, schema design, API behavior, or production workflow. |
| [**Subagent-Driven Development**](skills/engineering/subagent-driven-development/SKILL.md) | User entry point for executing an approved implementation plan task-by-task, each task built by a fresh subagent and checked by an independent reviewer before the next one starts. Use when the user wants to build out an approved plan, task list, or backlog of engineering work with per-task review and a durable progress record. |
| [**TDD**](skills/engineering/tdd/SKILL.md) | Develops behavior through red-green-refactor test slices that exercise public interfaces and real code paths. Use when adding features, fixing bugs with regression tests, shaping APIs through examples, or refactoring while preserving observable behavior. |
| [**Technical Trading Strategy**](skills/engineering/technical-trading-strategy/SKILL.md) | Designs, reviews, and implements rule-based technical trading strategies with disciplined backtesting, validation, risk controls, and Python engineering guidance. Use when working on indicator rules, strategy specs, backtest code, execution assumptions, market data, or live-trading readiness. |
| [**Triage**](skills/engineering/triage/SKILL.md) | Triages tracker issues through canonical category and state roles, maintainer review, and durable handoff notes. Use when classifying bugs or enhancements, reviewing incoming issues, preparing AFK-agent briefs, requesting reporter info, or managing issue workflow. |

### Productivity

| Skill Name | Description |
| :--- | :--- |
| [**Skill Smith**](skills/productivity/skill-smith/SKILL.md) | Crafts reusable agent skills with invocation design, progressive disclosure, leading words, and bundled resources. Use when the user asks to create a skill, write a skill, build an agent skill, review a SKILL.md, or package skill references, scripts, or examples. |
argument-hint: "<skill idea or draft> |
| [**Write a PRD**](skills/productivity/write-a-prd/SKILL.md) | Synthesizes conversation context and repository understanding into a product requirements document. Use when drafting, writing, or publishing a PRD from existing conversation, technical brief, design discussion, or approved scope. |
argument-hint: "<conversation context or PRD brief> |
| [**Write a Story**](skills/productivity/write-a-story/SKILL.md) | Backlog workflow for drafting, rewriting, splitting, reviewing, and converting plans into implementation-ready work items. Covers user stories, job stories, WWA items, issue breakdowns, acceptance criteria, readiness checks, and approved Jira payloads. |
argument-hint: "<backlog item brief> |
| [**Caveman**](skills/productivity/caveman/SKILL.md) | Ultra-compressed communication mode that drops filler, articles, and pleasantries while keeping technical accuracy. Use when the user says caveman mode, talk like caveman, use caveman, less tokens, be brief, terse mode, or invokes /caveman. |
| [**Grill Me**](skills/productivity/grill-me/SKILL.md) | User entry point for a relentless plan interview. Use when the user asks to be grilled, stress-test a plan, prepare for review, or decide before building. |
| [**Grilling**](skills/productivity/grilling/SKILL.md) | Interviews the user relentlessly about a plan or design, walking down each branch of the decision tree one dependency at a time. Use when grilling a plan, stress-testing a proposal, clarifying vague intent, or resolving decisions before implementation. |
| [**Grill With Docs**](skills/productivity/grill-with-docs/SKILL.md) | User entry point for a grilling session that builds living documentation as decisions crystallize. Use when the user wants to stress-test a plan and simultaneously capture domain vocabulary and architectural decisions. |
| [**Brainstorming**](skills/productivity/brainstorming/SKILL.md) | User entry point for shaping a rough idea into an approved design. Use when the user wants to brainstorm a new feature, component, or product idea before writing a plan or touching code. |
| [**Management Talk**](skills/productivity/management-talk/SKILL.md) | Rewrites engineering updates into clear leadership and cross-functional communication while preserving state, impact, ownership, risks, and next steps. Use when drafting Jira comments, Slack posts, standup notes, emails, meeting talking points, or executive summaries from technical source material. |
| [**Stakeholder Update**](skills/productivity/stakeholder-update/SKILL.md) | Drafts audience-aware stakeholder updates that clarify status, impact, risks, decisions, and next steps. Use when preparing status reports, sprint summaries, launch notes, risk escalations, executive updates, customer progress notes, or multi-audience variants. |
| [**Setup Context**](skills/productivity/setup-context/SKILL.md) | Scaffolds shared project context files in .context/ and configure the output locations pipeline skills write artifacts to (PRDs, stories, designs, ADRs, and more). Use when onboarding skills to a new or existing repo, when skills lack shared project context, or to relocate where a skill's output gets saved. |
| [**Release Scan**](skills/productivity/release-scan/SKILL.md) | Scans one service repository between two tags and produces a standardized Service Release Report used to assemble a customer-facing release note. Use when diffing two tags or versions, working out what shipped between releases, assessing deployment impact or breaking changes, or preparing a release for a dedicated or on-prem customer environment. |
| [**Handoff**](skills/productivity/handoff/SKILL.md) | Compacts the current conversation into a handoff document so a fresh agent can continue the work without losing context. Use when switching sessions, handing off to another agent, ending a long conversation, or preparing a context brief for a follow-up run. |

### Choosing the Right Skill

Install the full portable set by default, then rely on concise descriptions and these boundaries to choose the right skill for the task.

| Situation | Skill |
| :--- | :--- |
| The goal, plan, or decision is unclear and needs an interview before work starts. | [**Grill Me**](skills/productivity/grill-me/SKILL.md) |
| A written plan, PR, diff, design doc, or implementation approach needs independent review. | [**Scrutinize**](skills/engineering/scrutinize/SKILL.md) |
| A bug or failure needs a compact active-debugging discipline before a fix is proposed. | [**Debug Mantra**](skills/engineering/debug-mantra/SKILL.md) |
| A hard bug, flaky failure, crash, hang, production-only issue, data issue, or performance regression needs a full feedback-loop investigation. | [**Diagnose**](skills/engineering/diagnose/SKILL.md) |
| A behavior change should be driven through red-green-refactor tests. | [**TDD**](skills/engineering/tdd/SKILL.md) |
| A fixed and validated bug needs an engineering RCA or post-mortem. | [**Post-mortem**](skills/engineering/post-mortem/SKILL.md) |
| Incoming tracker issues need classification, state movement, reporter follow-up, or AFK-agent handoff. | [**Triage**](skills/engineering/triage/SKILL.md) |
| Technical material needs to be rewritten for leadership, Slack, Jira, email, standup, or meeting notes. | [**Management Talk**](skills/productivity/management-talk/SKILL.md) |
| A status, launch, sprint, risk, decision, customer, or multi-audience update needs audience-aware framing. | [**Stakeholder Update**](skills/productivity/stakeholder-update/SKILL.md) |
| Work is mainly inside a specific stack or domain. | Use the matching engineering skill, and combine it with a workflow skill only when the request also needs debugging, TDD, review, security, measurement, or communication structure. |

> **Looking for the PM OS?** The `pm-os-bootstrap` slash command moved to the separate `ai-system` plugin marketplace repo as the `pm-os` plugin (`/pm-os:setup`, `/pm-os:validate`, `/pm-os:score`).

## Architecture Overview

The library rests on three ideas: **skills as self-contained folders**, **buckets as a shipping boundary**, and **installers that never touch what they don't own**.

### Repository Layout

```text
.
├── .claude-plugin/           # Claude Code plugin manifest
├── scripts/                  # Skill management scripts
│   ├── _skills-lib.sh        # Shared helpers, buckets, and preset bundles
│   ├── blvck-skills.sh       # Entry point for the blvck-skills shortcut command
│   ├── install-skills.sh     # Interactive end-user installer
│   ├── uninstall-skills.sh   # Interactive uninstaller
│   ├── list-skills.sh        # List every SKILL.md with bucket labels
│   ├── sync-shared-refs.sh   # Materialize skills/_shared/ into each skill
│   ├── validate-skills.sh    # Validate frontmatter, links, and catalog sync
│   ├── test-validate-skills.sh # Prove validate-skills.sh rejects what it should
│   ├── setup-command.sh      # Create the blvck-skills shortcut command
│   ├── unsetup-command.sh    # Remove the blvck-skills shortcut command
│   └── deprecated/           # Retired maintainer symlink scripts
└── skills/
    ├── _shared/              # Shared assets and references
    │   └── references/       # Common documentation (e.g., commit conventions)
    ├── engineering/          # Daily code work
    │   └── <skill-name>/     # Specialized skill folder
    │       ├── SKILL.md      # Core instruction set with YAML frontmatter
    │       └── references/   # Domain-specific deep-dive documents
    ├── productivity/         # Daily non-code workflow tools
    ├── misc/                 # Situational, kept around but rarely used
    ├── personal/             # Tied to the maintainer's local setup, not shipped
    ├── in-progress/          # Drafts not yet ready to ship
    └── deprecated/           # No longer used
```

### Core Components

- **Skills** — each skill is a directory holding a `SKILL.md` (YAML frontmatter for `name` and `description`, followed by the instruction body) plus optional `references/` deep-dives and scripts. Agents discover skills by description and load the body on demand.
- **Buckets** — `engineering/`, `productivity/`, and `misc/` are *shippable*; `personal/`, `in-progress/`, and `deprecated/` never leave the repo. The installer, the plugin manifest, and the catalog above all follow this same rule.
- **Installer** — copies selected skill folders into `PROJECT/.claude/skills`, `PROJECT/.codex/skills`, and `PROJECT/.gemini/extensions/blvck-skills/skills` (Gemini CLI discovers skills bundled inside extensions, so a `gemini-extension.json` is generated alongside). It writes a `.blvck-skills-install.json` ownership marker into each copy and a project-level manifest, so the uninstaller only ever removes installer-owned copies. Markers written before the repo rename (`.agent-skills-install.json`) are still recognized.
- **Shared references** — files in `skills/_shared/references/` materialize into each installed skill that declares a need for them, keeping conventions identical across skills.
- **Claude Code plugin manifest** — `.claude-plugin/plugin.json` exposes the same shippable skills as a namespaced plugin.

## Getting Started

### Prerequisites

- A supported AI assistant: **Claude Code**, **Codex**, or **Gemini CLI**.
- A Unix-like environment (macOS or Linux) with `bash` and `git`.

### Installation

**Option 1 — Quick install (no clone).** The community [`skills`](https://github.com/vercel-labs/skills) CLI reads this repo's plugin manifest directly:

```bash
npx skills add github:ntwrcht/blvck-skills
```

Add `-g` for a global (user-level) install, `--agent <agents>` to target specific CLIs (e.g. `claude-code`, `codex`, `gemini-cli`), or `--skill <names>` to install specific skills non-interactively. This path doesn't support bucket-level selection or preset bundles — use the full installer for those.

**Option 2 — Full installer (presets and bucket selection).** Clone the repo and run the interactive installer:

```bash
git clone git@github.com:ntwrcht/blvck-skills.git
cd blvck-skills
./scripts/install-skills.sh
```

The installer walks you through **scenario** (*Project PM*, *Project Dev*, or *Custom*), **CLIs**, **project path**, and **skill selection**, then copies everything into the target project so each project carries its own skill set.

**Option 3 — Claude Code plugin.** Load the whole shippable library without copying files:

```bash
claude --plugin-dir /path/to/blvck-skills
```

**Optional — shortcut command.** Register `blvck-skills` as a global command so you can install from any project directory:

```bash
./scripts/setup-command.sh     # creates ~/.local/bin/blvck-skills
cd /path/to/project
blvck-skills                   # run the installer from anywhere
./scripts/unsetup-command.sh   # remove the shortcut later
```

## Usage

Once installed, skills activate through your assistant's normal flow — the agent matches your request against each skill's description and loads the best fit. You can also invoke a skill explicitly:

```text
> /tdd
> Use the diagnose skill to investigate this flaky integration test.
> Grill me on this migration plan before I start.
```

A typical day with the *Project Dev* bundle:

```text
> /grill-with-docs            # stress-test the plan, capture decisions as ADRs
> /tdd                        # build the change through red-green-refactor slices
> /scrutinize                 # independent review of the resulting diff
> /handoff                    # compact the session for the next agent
```

To remove skills from a project:

```bash
./scripts/uninstall-skills.sh
```

To audit the library itself:

```bash
./scripts/list-skills.sh                    # every SKILL.md with bucket labels
./scripts/validate-skills.sh                # frontmatter, links, catalog sync
./scripts/sync-shared-refs.sh --check       # shared references in sync
```

> **Note on context cost:** installed means *discoverable*, not *loaded*. Agents read only the name and description at startup and pull in the full instruction set when the task warrants it.

## Security & Trust

- **No secrets** — never commit API keys, passwords, or PII. Use environment variables or local `.env` files (git-ignored).
- **Prompt injection awareness** — skills are powerful instructions. Peer-review every change to a `SKILL.md` to ensure it cannot exfiltrate data or perform unauthorized actions.
- **Least privilege** — skills receive only the minimum context necessary for their task.
- **Input validation** — the management scripts operate on known bucket lists and skip non-symlink provider entries to avoid accidental overwrites.
- **Context isolation** — files matching `*_CONTEXT.md` are git-ignored to prevent accidental exposure of project-specific metadata.

## Contributing

Contributions are welcome — new skills, sharper descriptions, and better references all improve the library.

1. Create a new folder in the appropriate bucket under `skills/`.
2. Add a `SKILL.md` following the established template (YAML frontmatter with `name` and `description`).
3. Write the description with enough signal for agent selection: capability first, then a `Use when` sentence with specific trigger keywords, contexts, file types, tools, or outcomes. Avoid forceful activation phrases such as `ALWAYS use`, `MUST use`, `Trigger when`, `Trigger on`, `proactively whenever`, `no exceptions`, and `Do NOT attempt`.
4. Put detailed activation boundaries inside the `SKILL.md` body under a `When to Use` or `When Not to Use` section, with clear boundaries against overlapping skills.
5. Add supporting documentation in the skill's `references/` subfolder.
6. Update `get_shared_refs` in `scripts/_skills-lib.sh` if your skill needs shared assets.
7. For shippable skills, add a linked entry to this `README.md`, the bucket `README.md`, and `.claude-plugin/plugin.json`. Never index `personal/`, `in-progress/`, or `deprecated/` skills.
8. Run the validation pair before opening a PR:

   ```bash
   ./scripts/list-skills.sh
   ./scripts/validate-skills.sh
   ```

9. Submit a pull request — or [open an issue](https://github.com/ntwrcht/blvck-skills/issues) to report bugs and propose ideas.

## License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for the full text.
