# Agent Skills 🛠️

A collection of specialized expert agent skills for AI assistants (like Gemini CLI and Claude). These skills provide deep domain knowledge, architectural guidance, and standardized workflows to help agents perform complex engineering tasks with high precision.

## 🌟 Available Skills

| Skill Name | Description |
| :--- | :--- |
| **Angular Engineer** | Expert guidance for Angular development, RxJS, Signals, and enterprise patterns. |
| **Strapi Engineer** | Specialized in Strapi headless CMS, content types, plugins, and backend logic. |
| **Security Audit** | Security code review, vulnerability assessment, and compliance (OWASP, GDPR). |
| **GA4 Analytics** | Measurement strategy, GA4 implementation, GTM, and event taxonomy. |

## 🚀 Getting Started

This repository uses a symlinking strategy to "install" skills into your AI assistant's configuration directories.

### Prerequisites

- A supported AI assistant (Gemini CLI or Claude).
- A Unix-like environment (macOS or Linux).

### Installation

To install all available skills:

```bash
chmod +x setup-skills.sh
./setup-skills.sh
```

To install a specific skill:

```bash
./setup-skills.sh angular-engineer
```

To preview changes without making them:

```bash
./setup-skills.sh --dry-run
```

To remove all installed symlinks:

```bash
./setup-skills.sh --remove
```

## 📂 Project Structure

```text
.
├── setup-skills.sh           # Main installation script
└── skills/
    ├── _shared/              # Shared assets and references
    │   └── references/       # Common documentation (e.g., commit conventions)
    ├── <skill-name>/         # Specialized skill folder
    │   ├── SKILL.md          # The core instruction set for the agent
    │   └── references/       # Domain-specific deep-dive documents
    └── ...
```

## 🛠️ How it Works

The `setup-skills.sh` script performs two main actions:

1.  **Skill Linking**: It symlinks each skill folder from this repo into `$HOME/.gemini/skills` and `$HOME/.claude/skills`.
2.  **Reference Injection**: It symlinks shared references (from `_shared/references/`) into the specific skill's `references/` folder, ensuring consistency across different agents.

## 🛡️ Security & Trust

To maintain a secure environment, this project adheres to the following standards:

-   **No Secrets**: Never commit API keys, passwords, or PII to this repository. Use environment variables or local `.env` files (which are ignored by git).
-   **Input Validation**: The `setup-skills.sh` script enforces strict validation on skill names to prevent path traversal and shell injection.
-   **Prompt Injection Awareness**: Skills are powerful instructions. Always peer-review changes to `SKILL.md` files to ensure they don't contain instructions that could exfiltrate data or perform unauthorized actions.
-   **Least Privilege**: Skills should only be granted the minimum context necessary to perform their tasks.
-   **Context Isolation**: Files matching `*_CONTEXT.md` are ignored by git to prevent accidental exposure of project-specific or sensitive metadata.

## 📝 Contributing

1.  Create a new folder in `skills/`.
2.  Add a `SKILL.md` file following the established template.
3.  Add supporting documentation in the `references/` subfolder.
4.  Update the `get_shared_refs` function in `setup-skills.sh` if your skill needs shared assets.
5.  Submit a Pull Request!
