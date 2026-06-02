# Agent Skills 🛠️

A collection of specialized expert agent skills for AI assistants (like Gemini CLI and Claude). These skills provide deep domain knowledge, architectural guidance, and standardized workflows to help agents perform complex engineering tasks with high precision.

## 🌟 Available Skills

### Engineering

| Skill Name | Description |
| :--- | :--- |
| [**Angular Engineer**](skills/engineering/angular-engineer/SKILL.md) | Build, modify, review, and debug Angular applications using project conventions, modern Angular patterns, RxJS, Signals, testing, SSR, and Nx guidance. Use when working on Angular components, services, routing, forms, guards, migrations, performance, security, or frontend architecture. |
| [**Debug Mantra**](skills/engineering/debug-mantra/SKILL.md) | Structured debugging workflow for reproducing, tracing, and falsifying bugs. |
| [**GA4 Measurement**](skills/engineering/ga4-measurement/SKILL.md) | Plan, implement, review, and validate GA4/GTM measurement for product flows, funnels, feature adoption, conversion, errors, and performance. Use when designing event taxonomies, dataLayer or gtag tracking, GA4 reports, GTM setup, analytics QA, or measurement plans. |
| [**Git Guardrails for Claude Code**](skills/engineering/git-guardrails-claude-code/SKILL.md) | Set up Claude Code hooks that block dangerous git commands before they execute. |
| [**Post-mortem**](skills/engineering/post-mortem/SKILL.md) | Engineering writeup format for fixed and validated bugs. |
| [**Python Engineer**](skills/engineering/python-engineer/SKILL.md) | Python project guidance for architecture, structure, typing, naming, linting, testing, and packaging. |
| [**Scrutinize**](skills/engineering/scrutinize/SKILL.md) | External review workflow for plans, PRs, diffs, design docs, and code changes. |
| [**Security Audit**](skills/engineering/security-audit/SKILL.md) | Security review workflow for code, APIs, infrastructure, authentication, secrets, and compliance. |
| [**Strapi Engineer**](skills/engineering/strapi-engineer/SKILL.md) | Strapi project guidance for content types, plugins, controllers, services, policies, RBAC, and GraphQL. |
| [**TDD**](skills/engineering/tdd/SKILL.md) | Test-driven development workflow using red-green-refactor behavior slices. |
| [**Technical Trading Strategy**](skills/engineering/technical-trading-strategy/SKILL.md) | Technical trading strategy research and engineering guidance for rule design, Python backtesting, validation, risk controls, and implementation review. |

### Productivity

| Skill Name | Description |
| :--- | :--- |
| [**Write a Skill**](skills/productivity/write-a-skill/SKILL.md) | Create, write, review, and improve reusable agent skills. Use when working on skill structure, progressive disclosure, bundled resources, examples, or validation. |
| [**Write a Story**](skills/productivity/write-a-story/SKILL.md) | Backlog story drafting, story splitting, acceptance criteria, readiness review, and approved Jira payload preparation. |
| [**Caveman**](skills/productivity/caveman/SKILL.md) | Ultra-compressed communication mode that drops filler, articles, and pleasantries while keeping technical accuracy. Use when the user says caveman mode, talk like caveman, use caveman, less tokens, be brief, terse mode, or invokes /caveman. |
| [**Grill Me**](skills/productivity/grill-me/SKILL.md) | Pressure-test plans and designs through focused interview loops that resolve decisions, risks, dependencies, and tradeoffs. Use when the user asks to be grilled, stress-test a plan, or sharpen a design before implementation. |
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

## 🚀 Getting Started

This repository uses a symlinking strategy to "install" shippable skills into your AI assistant's configuration directories.
It also includes a Claude Code plugin manifest for loading the same shippable skills as a namespaced plugin.

### Prerequisites

- A supported AI assistant (Gemini CLI or Claude).
- A Unix-like environment (macOS or Linux).

### Installation

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
