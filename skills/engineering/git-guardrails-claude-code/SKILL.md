---
name: git-guardrails-claude-code
description: >
  Set up Claude Code hooks to block dangerous git commands before they execute,
  including git push, reset --hard, clean, branch -D, checkout ., and restore ..
  Use when the user wants to prevent destructive git operations, add git safety
  hooks, or block git push/reset in Claude Code.
---

# Git Guardrails for Claude Code

Set up a Claude Code `PreToolUse` hook that blocks dangerous git commands before
Claude executes them.

## Blocked Commands

The bundled hook blocks:

- `git push`, including force push variants.
- `git reset --hard`.
- `git clean -f` and `git clean -fd`.
- `git branch -D`.
- `git checkout .`.
- `git restore .`.

When blocked, Claude receives a message saying the command is not authorized.

## Workflow

### 1. Ask Scope

Ask whether to install the hook for:

- This project only: `.claude/settings.json`.
- All projects: `~/.claude/settings.json`.

### 2. Copy the Hook

Use the bundled script:

- [scripts/block-dangerous-git.sh](scripts/block-dangerous-git.sh)

Copy it to the target location:

- Project: `.claude/hooks/block-dangerous-git.sh`.
- Global: `~/.claude/hooks/block-dangerous-git.sh`.

Make it executable:

```bash
chmod +x <path-to-script>
```

### 3. Merge the Hook Setting

If the settings file already exists, merge into `hooks.PreToolUse`; do not
overwrite unrelated settings or hooks.

Project setting:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

Global setting:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

### 4. Customize Patterns

Ask whether the user wants to add or remove blocked patterns. Edit the copied
script if they do.

### 5. Verify

Run a blocked-command check:

```bash
printf '%s\n' '{"tool_input":{"command":"git push origin main"}}' | <path-to-script>
```

Expected result:

- Exit code `2`.
- A `BLOCKED:` message printed to stderr.
