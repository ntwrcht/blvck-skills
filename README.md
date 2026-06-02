# Agent Skills 🛠️

A collection of specialized expert agent skills for AI assistants (like Gemini CLI and Claude). These skills provide deep domain knowledge, architectural guidance, and standardized workflows to help agents perform complex engineering tasks with high precision.

## 🌟 Available Skills

### Engineering

| Skill Name | Description |
| :--- | :--- |
| [**Angular Engineer**](skills/engineering/angular-engineer/SKILL.md) | Build, modify, review, and debug Angular applications using project conventions, modern Angular patterns, RxJS, Signals, testing, SSR, and Nx guidance. Use when working on Angular components, services, routing, forms, guards, migrations, performance, security, or frontend architecture. |
| [**Debug Mantra**](skills/engineering/debug-mantra/SKILL.md) | Debug failures with a disciplined repro, fail-path trace, hypothesis falsification, and experiment ledger. Use when investigating bugs, flaky tests, crashes, regressions, hangs, or unexplained behavior before proposing a fix. |
| [**GA4 Measurement**](skills/engineering/ga4-measurement/SKILL.md) | Plan, implement, review, and validate GA4/GTM measurement for product flows, funnels, feature adoption, conversion, errors, and performance. Use when designing event taxonomies, dataLayer or gtag tracking, GA4 reports, GTM setup, analytics QA, or measurement plans. |
| [**Git Guardrails for Claude Code**](skills/engineering/git-guardrails-claude-code/SKILL.md) | Install Claude Code PreToolUse hooks that block dangerous git commands before execution. Use when setting up local or global guardrails for git push, force push, reset --hard, clean, branch deletion, checkout ., or restore .. |
| [**Post-mortem**](skills/engineering/post-mortem/SKILL.md) | Write engineering post-mortems for fixed and validated bugs with symptom, root cause, mechanism, fix, validation, and follow-ups. Use when closing a bug, drafting an RCA, documenting a fix, or converting a debug ledger into a maintainer-readable record. |
| [**Python Engineer**](skills/engineering/python-engineer/SKILL.md) | Build, modify, review, and debug Python projects with architecture, packaging, typing, testing, linting, async, data access, and reliability guidance. Use when working on Python application code, libraries, CLIs, services, tooling, refactors, test strategy, or code review. |
| [**Scrutinize**](skills/engineering/scrutinize/SKILL.md) | Review plans, PRs, diffs, design docs, and code changes from an external verification stance. Use when pressure-testing intent, simpler alternatives, traced code paths, behavioral claims, edge cases, tests, or rollout risk. |
| [**Security Audit**](skills/engineering/security-audit/SKILL.md) | Review application security across code, APIs, infrastructure, authentication, authorization, secrets, dependencies, and compliance gaps. Use when assessing vulnerabilities, threat models, pentest findings, security controls, exploitability, impact, or remediation plans. |
| [**Strapi Engineer**](skills/engineering/strapi-engineer/SKILL.md) | Build, modify, review, and debug Strapi applications across content types, controllers, services, routes, policies, lifecycle hooks, plugins, auth, GraphQL, and tests. Use when working on Strapi v4 or v5 backend code, project architecture, schema design, API behavior, or production workflow. |
| [**TDD**](skills/engineering/tdd/SKILL.md) | Develop behavior through red-green-refactor test slices that exercise public interfaces and real code paths. Use when adding features, fixing bugs with regression tests, shaping APIs through examples, or refactoring while preserving observable behavior. |
| [**Technical Trading Strategy**](skills/engineering/technical-trading-strategy/SKILL.md) | Design, review, and implement rule-based technical trading strategies with disciplined backtesting, validation, risk controls, and Python engineering guidance. Use when working on indicator rules, strategy specs, backtest code, execution assumptions, market data, or live-trading readiness. |

### Productivity

| Skill Name | Description |
| :--- | :--- |
| [**Write a Skill**](skills/productivity/write-a-skill/SKILL.md) | Create, write, review, and improve reusable agent skills. Use when working on skill structure, progressive disclosure, bundled resources, examples, or validation. |
| [**Write a Story**](skills/productivity/write-a-story/SKILL.md) | Backlog story drafting, story splitting, plan-to-issue breakdowns, acceptance criteria, readiness review, and approved Jira payload preparation. |
| [**Caveman**](skills/productivity/caveman/SKILL.md) | Ultra-compressed communication mode that drops filler, articles, and pleasantries while keeping technical accuracy. Use when the user says caveman mode, talk like caveman, use caveman, less tokens, be brief, terse mode, or invokes /caveman. |
| [**Grill Me**](skills/productivity/grill-me/SKILL.md) | Shape goals, context, decisions, risks, dependencies, and tradeoffs through a focused interview loop. Use when the user asks to be grilled, stress-test a plan, clarify a vague proposal, prepare for review, or decide before implementation. |
| [**Management Talk**](skills/productivity/management-talk/SKILL.md) | Rewrite engineering updates into clear leadership and cross-functional communication while preserving state, impact, ownership, risks, and next steps. Use when drafting Jira comments, Slack posts, standup notes, emails, meeting talking points, or executive summaries from technical source material. |
| [**Stakeholder Update**](skills/productivity/stakeholder-update/SKILL.md) | Draft audience-aware stakeholder updates that clarify status, impact, risks, decisions, and next steps. Use when preparing status reports, sprint summaries, launch notes, risk escalations, executive updates, customer progress notes, or multi-audience variants. |

### Misc

Skills kept around but rarely used.

### Personal

Skills tied to my own setup, not promoted.

### In Progress

Drafts not yet ready to ship.

### Deprecated

Skills that are no longer used.

## 🧭 Skill Selection Guide

Use the full portable install by default. Link every shippable skill, then rely on concise descriptions and these boundaries to choose the right skill for the task.

| Situation | Skill |
| :--- | :--- |
| The goal, plan, or decision is unclear and needs an interview before work starts. | [**Grill Me**](skills/productivity/grill-me/SKILL.md) |
| A written plan, PR, diff, design doc, or implementation approach needs independent review. | [**Scrutinize**](skills/engineering/scrutinize/SKILL.md) |
| A bug, crash, flaky test, hang, regression, or unexplained behavior has an unknown cause. | [**Debug Mantra**](skills/engineering/debug-mantra/SKILL.md) |
| A behavior change should be driven through red-green-refactor tests. | [**TDD**](skills/engineering/tdd/SKILL.md) |
| A fixed and validated bug needs an engineering RCA or post-mortem. | [**Post-mortem**](skills/engineering/post-mortem/SKILL.md) |
| Technical material needs to be rewritten for leadership, Slack, Jira, email, standup, or meeting notes. | [**Management Talk**](skills/productivity/management-talk/SKILL.md) |
| A status, launch, sprint, risk, decision, customer, or multi-audience update needs audience-aware framing. | [**Stakeholder Update**](skills/productivity/stakeholder-update/SKILL.md) |
| Work is mainly inside a specific stack or domain. | Use the matching engineering skill, and combine it with a workflow skill only when the request also needs debugging, TDD, review, security, measurement, or communication structure. |

## 🚀 Getting Started

This repository uses a symlinking strategy to "install" shippable skills into your AI assistant's configuration directories.
It also includes a Claude Code plugin manifest for loading the same shippable skills as a namespaced plugin.

### Prerequisites

- A supported AI assistant (Gemini CLI or Claude).
- A Unix-like environment (macOS or Linux).

### Installation

For a new computer, clone this repository and link every shippable skill into the supported agent directories:

```bash
git clone <repo-url>
cd agent-skills
./scripts/link-skills.sh
```

The script installs skills from `engineering/`, `productivity/`, and `misc/`. It does not install skills from `personal/`, `in-progress/`, or `deprecated/`.

Linked means the skill is available for the agent to discover. It should not mean every full `SKILL.md` is loaded into the model context at startup; agents should use the skill name and description to choose a relevant skill, then load that skill's detailed instructions only when needed.

To list every `SKILL.md` in the repo:

```bash
./scripts/list-skills.sh
```

To check that public skill descriptions avoid overly forceful activation wording:

```bash
./scripts/validate-skill-descriptions.sh
```

For my own dev loop, symlink every shippable skill into Claude, Codex, and a local Gemini extension, and inject shared references:

```bash
./scripts/link-skills.sh
```

To unlink every shippable skill from those providers:

```bash
./scripts/un-link-skill.sh
```

To test the Claude Code plugin locally:

```bash
claude --plugin-dir .
```

## 📂 Project Structure

```text
.
├── scripts/                  # Skill management scripts
│   ├── link-skills.sh        # Link shippable skills and shared references
│   ├── list-skills.sh        # List every SKILL.md with bucket labels
│   └── un-link-skill.sh      # Remove provider symlinks for shippable skills
└── skills/
    ├── _shared/              # Shared assets and references
    │   └── references/       # Common documentation (e.g., commit conventions)
    ├── engineering/          # Daily code work
    │   └── <skill-name>/     # Specialized skill folder
    │       ├── SKILL.md      # Core instruction set with YAML frontmatter
    │       └── references/   # Domain-specific deep-dive documents
    ├── productivity/         # Daily non-code workflow tools
    ├── misc/                 # Kept around but rarely used
    ├── personal/             # Tied to my own setup, not promoted
    ├── in-progress/          # Drafts not yet ready to ship
    ├── deprecated/           # No longer used
    └── ...
```

Each skill is its own directory containing a `SKILL.md` file with YAML frontmatter for `name` and `description`, plus any bundled scripts or reference files.

## 🛠️ How it Works

The `scripts/link-skills.sh` script performs two main actions:

1.  **Skill Linking**: It symlinks each grouped skill folder from this repo into `$HOME/.claude/skills` and `$HOME/.codex/skills` using the skill directory name. For Gemini, it creates a local extension at `$HOME/.gemini/extensions/agent-skills` and symlinks skills into that extension's `skills/` directory.
2.  **Reference Injection**: It symlinks shared references (from `_shared/references/`) into the specific skill's `references/` folder, ensuring consistency across different agents.

The dev-loop scripts use these provider targets:

- `$HOME/.claude/skills`
- `$HOME/.codex/skills`
- `$HOME/.gemini/extensions/agent-skills/skills`

Gemini CLI discovers skills bundled inside extensions, so the script also writes `$HOME/.gemini/extensions/agent-skills/gemini-extension.json`.
Any old symlinks in `$HOME/.gemini/skills` are removed when they are safe symlinks; non-symlink entries are skipped.

For those scripts, shippable skills are skills in `engineering/`, `productivity/`, and `misc/`. Skills in `personal/`, `in-progress/`, and `deprecated/` are listed but not linked.
The Claude plugin manifest follows the same shippable-skill rule, so plugin installs do not include personal, draft, or deprecated skills.

## 🛡️ Security & Trust

To maintain a secure environment, this project adheres to the following standards:

-   **No Secrets**: Never commit API keys, passwords, or PII to this repository. Use environment variables or local `.env` files (which are ignored by git).
-   **Input Validation**: The management scripts use known bucket lists and skip non-symlink provider entries to avoid accidental overwrites.
-   **Prompt Injection Awareness**: Skills are powerful instructions. Always peer-review changes to `SKILL.md` files to ensure they don't contain instructions that could exfiltrate data or perform unauthorized actions.
-   **Least Privilege**: Skills should only be granted the minimum context necessary to perform their tasks.
-   **Context Isolation**: Files matching `*_CONTEXT.md` are ignored by git to prevent accidental exposure of project-specific or sensitive metadata.

## 📝 Contributing

1.  Create a new folder in the appropriate bucket under `skills/`.
2.  Add a `SKILL.md` file following the established template.
3.  Write the YAML `description` and README entry with enough signal for agent selection. Prefer two sentences: capability first, then `Use when` with specific trigger keywords, contexts, file types, tools, or outcomes. Avoid phrases such as `ALWAYS use`, `MUST use`, `Trigger when`, `Trigger on`, `proactively whenever`, `no exceptions`, and `Do NOT attempt`.
4.  Put detailed activation boundaries inside the `SKILL.md` body under a `When to Use` or `When Not to Use` section, with clear boundaries against overlapping skills.
5.  Add supporting documentation in the `references/` subfolder.
6.  Update the `get_shared_refs` function in `scripts/_skills-lib.sh` if your skill needs shared assets.
7.  For skills in `engineering/`, `productivity/`, or `misc/`, add a linked entry to the top-level `README.md`, the bucket `README.md`, and `.claude-plugin/plugin.json`. Do not add `personal/`, `in-progress/`, or `deprecated/` skills to those shippable indexes.
8.  Run `./scripts/list-skills.sh` and `./scripts/validate-skill-descriptions.sh`.
9.  Submit a Pull Request!
