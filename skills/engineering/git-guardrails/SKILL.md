---
name: git-guardrails
description: "Installs Claude Code PreToolUse hooks that block dangerous git commands before execution. Use when setting up local or global guardrails for git push, force push, reset --hard, clean, branch deletion, checkout ., or restore ."
compatibility: Designed for Claude Code
---

# Git Guardrails for Claude Code

Set up a Claude Code `PreToolUse` hook that blocks high-risk git commands before Claude executes them.

## When to Use

Use this skill when the user wants Claude Code git safety hooks, local project guardrails, global guardrails, or protection from destructive commands such as push, force push, hard reset, clean, branch deletion, checkout dot, or restore dot.

This skill installs Claude Code hooks only. For ordinary repository policy, server-side git hooks, GitHub branch protection, or CI rules, provide separate guidance.

## Artifacts

- Produces: `.claude/settings.json` (hook entries merged in)
- Consumes: nothing

## Core Rule

Preserve existing Claude settings. Merge hook entries; never overwrite unrelated settings, hooks, or user scripts.

## Blocked Commands

The bundled hook blocks:

- `git push`, including force-push variants.
- `git reset --hard`.
- `git clean -f` and `git clean -fd`.
- `git branch -D`.
- `git checkout .`.
- `git restore .`.

## Workflow

1. **Choose scope.** Ask for project-only `.claude/settings.json` or global `~/.claude/settings.json` unless the user already specified it.
2. **Copy the hook.** Use [scripts/block-dangerous-git.sh](scripts/block-dangerous-git.sh). Copy it to `.claude/hooks/block-dangerous-git.sh` for project scope or `~/.claude/hooks/block-dangerous-git.sh` for global scope.
3. **Make it executable.** Run `chmod +x <hook-path>`.
4. **Merge settings.** Add a `hooks.PreToolUse` entry with matcher `Bash` and command pointing at the hook. Keep existing hooks and settings.
5. **Customize if requested.** Edit the copied script only for requested additions or removals.
6. **Verify.** Pipe a blocked command payload into the hook and confirm exit code `2` with a `BLOCKED:` stderr message.

## Settings Snippets

Project command:

```json
"command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-dangerous-git.sh"
```

Global command:

```json
"command": "~/.claude/hooks/block-dangerous-git.sh"
```

Verification command:

```bash
printf '%s\n' '{"tool_input":{"command":"git push origin main"}}' | <hook-path>
```

## Operating Rules

- Ask before choosing local versus global scope when unspecified.
- Read existing settings before editing them.
- Preserve unrelated JSON keys and hook entries.
- Do not weaken blocked patterns unless the user explicitly asks.
- Report the installed path, settings path, and verification result.
