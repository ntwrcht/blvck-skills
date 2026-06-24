# Out-of-Scope Knowledge Base

The `.out-of-scope/` directory in a repo stores persistent records of rejected feature requests. It preserves institutional memory and helps deduplicate later requests that match prior decisions.

Use it only for rejected enhancements, not bugs.

## Directory Structure

```text
.out-of-scope/
|-- dark-mode.md
|-- plugin-system.md
`-- graphql-api.md
```

Create one file per concept, not per issue. Multiple issues requesting the same thing belong in the same file.

## File Format

Write files in a relaxed, readable style, closer to a short design note than a database entry. Use paragraphs, examples, and code snippets when they make the reasoning clearer.

```markdown
# Dark Mode

This project does not support dark mode or user-facing theming.

## Why this is out of scope

The rendering pipeline assumes a single color palette defined in
`ThemeConfig`. Supporting multiple themes would require:

- A theme context provider wrapping the entire component tree
- Per-component theme-aware style resolution
- A persistence layer for user theme preferences

This is a significant architectural change that does not align with the
project's focus on content authoring.

## Prior requests

- #42 - "Add dark mode support"
- #87 - "Night theme for accessibility"
```

## Naming

Use a short, descriptive kebab-case filename for the concept: `dark-mode.md`, `plugin-system.md`, `graphql-api.md`. The name should be recognizable without opening the file.

## Writing the Reason

The reason should be substantive and durable. Good reasons reference project scope, technical constraints, architecture, strategy, or product philosophy. Avoid temporary reasons such as current bandwidth.

## When to Check

During triage context gathering, read `.out-of-scope/*.md` when present. Match by concept similarity, not just keyword. For example, "night theme" may match `dark-mode.md`.

When there is a likely match, surface it to the maintainer:

```text
This resembles `.out-of-scope/dark-mode.md`; the prior rejection was based on runtime theme architecture. Should this issue follow that decision or proceed through normal triage?
```

The maintainer may confirm, reconsider, or decide the request is related but distinct.

## When to Write

When an enhancement is approved as `wontfix`:

1. Check for a matching `.out-of-scope/` file.
2. If one exists, append the new issue to its prior requests.
3. If none exists, create a file with the concept name, decision, reason, and first prior request.
4. Post a tracker comment explaining the decision and linking or naming the `.out-of-scope/` file.
5. Close or resolve the issue with the mapped `wontfix` role.

## Updating or Removing

If the maintainer changes their mind about a previously rejected concept, update or delete the `.out-of-scope/` file. Historical issues do not need to be reopened automatically; the new issue proceeds through normal triage.
