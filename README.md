# Agent Skills 🛠️

A collection of specialized expert agent skills for AI assistants (like Gemini CLI and Claude). These skills provide deep domain knowledge, architectural guidance, and standardized workflows to help agents perform complex engineering tasks with high precision.

## 🌟 Available Skills

### Engineering

| Skill Name | Description |
| :--- | :--- |
| [**Angular Engineer**](skills/engineering/angular-engineer/SKILL.md) | Expert guidance for Angular development, RxJS, Signals, and enterprise patterns. |
| [**Debug Mantra**](skills/engineering/debug-mantra/SKILL.md) | Four-step debugging discipline: reproduce, trace the fail path, falsify hypotheses, and track every run as a breadcrumb. |
| [**GA4 Analytics**](skills/engineering/ga4-analytics/SKILL.md) | Measurement strategy, GA4 implementation, GTM, and event taxonomy. |
| [**Git Guardrails for Claude Code**](skills/engineering/git-guardrails-claude-code/SKILL.md) | Set up Claude Code hooks that block dangerous git commands before they execute. |
| [**Post-mortem**](skills/engineering/post-mortem/SKILL.md) | Engineering record for a fixed and validated bug: root cause, mechanism, fix, validation, and follow-ups. |
| [**Scrutinize**](skills/engineering/scrutinize/SKILL.md) | Outsider-perspective review of plans, PRs, diffs, and code changes: question intent, trace real paths, and verify claims. |
| [**Security Audit**](skills/engineering/security-audit/SKILL.md) | Security code review, vulnerability assessment, and compliance (OWASP, GDPR). |
| [**Strapi Engineer**](skills/engineering/strapi-engineer/SKILL.md) | Specialized in Strapi headless CMS, content types, plugins, and backend logic. |
| [**TDD**](skills/engineering/tdd/SKILL.md) | Test-driven development with a red-green-refactor loop, public-interface tests, and incremental behavior slices. |

### Productivity

| Skill Name | Description |
| :--- | :--- |
| [**Grill Me**](skills/productivity/grill-me/SKILL.md) | One-question-at-a-time plan/design interrogation with recommended answers and codebase-first checks. |
| [**Management Talk**](skills/productivity/management-talk/SKILL.md) | Rewrite engineering content for leadership, PMs, release managers, Slack, email, standup, and meeting channels. |

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

For my own dev loop, symlink every shippable skill into Claude, Codex, and Gemini, and inject shared references:

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

1.  **Skill Linking**: It symlinks each grouped skill folder from this repo into `$HOME/.claude/skills`, `$HOME/.codex/skills`, and `$HOME/.gemini/skills` using the skill directory name.
2.  **Reference Injection**: It symlinks shared references (from `_shared/references/`) into the specific skill's `references/` folder, ensuring consistency across different agents.

The dev-loop scripts use these provider targets:

- `$HOME/.claude/skills`
- `$HOME/.codex/skills`
- `$HOME/.gemini/skills`

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
3.  Add supporting documentation in the `references/` subfolder.
4.  Update the `get_shared_refs` function in `scripts/_skills-lib.sh` if your skill needs shared assets.
5.  Submit a Pull Request!
