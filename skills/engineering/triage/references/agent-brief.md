# Writing Agent Briefs

An agent brief is a structured tracker comment posted when an issue moves to `ready-for-agent`. It is the authoritative specification an AFK agent works from. The original issue body and discussion are context; the agent brief is the contract.

For `ready-for-human`, use the same structure and add why the work cannot be delegated to an AFK agent.

## Principles

### Durability over precision

The issue may sit in `ready-for-agent` for days or weeks. Write the brief so it stays useful even if files are renamed, moved, or refactored.

- Describe interfaces, types, and behavioral contracts.
- Name specific types, function signatures, or config shapes when they matter.
- Avoid file paths and line numbers.
- Avoid assuming the current implementation structure will remain unchanged.

### Behavioral, not procedural

Describe what the system should do, not how to implement it.

- Good: "The `SkillConfig` type should accept an optional `schedule` field of type `CronExpression`."
- Bad: "Open `src/types/skill.ts` and add a schedule field on line 42."

### Complete acceptance criteria

Every brief must have concrete, testable acceptance criteria. Each criterion should be independently verifiable.

### Explicit scope boundaries

State what is out of scope. This prevents gold-plating and incorrect assumptions about adjacent work.

## Template

```markdown
## Agent Brief

**Category:** bug / enhancement
**Summary:** one-line description of what needs to happen

**Current behavior:**
Describe what happens now. For bugs, this is the broken behavior.
For enhancements, this is the status quo the feature builds on.

**Desired behavior:**
Describe what should happen after the agent's work is complete.
Be specific about edge cases and error conditions.

**Key interfaces:**
- `TypeName` - what needs to change and why
- `functionName()` return type - what it currently returns vs what it should return
- Config shape - any new configuration options needed

**Acceptance criteria:**
- [ ] Specific, testable criterion 1
- [ ] Specific, testable criterion 2
- [ ] Specific, testable criterion 3

**Out of scope:**
- Thing that should not be changed or addressed in this issue
- Adjacent feature that might seem related but is separate
```

## Bug Example

```markdown
## Agent Brief

**Category:** bug
**Summary:** Skill description truncation drops mid-word, producing broken output

**Current behavior:**
When a skill description exceeds 1024 characters, it is truncated at exactly
1024 characters regardless of word boundaries. This produces descriptions
that end mid-word.

**Desired behavior:**
Truncation should break at the last word boundary before 1024 characters
and append "..." to indicate truncation.

**Key interfaces:**
- `SkillMetadata.description` - no type change needed, but processing logic
  should respect word boundaries
- Any function that reads `SKILL.md` frontmatter and extracts descriptions

**Acceptance criteria:**
- [ ] Descriptions under 1024 characters are unchanged
- [ ] Descriptions over 1024 characters are truncated at the last word boundary
- [ ] Truncated descriptions end with "..."
- [ ] The total length including "..." does not exceed 1024 characters

**Out of scope:**
- Changing the 1024 character limit itself
- Multi-line description support
```

## PR Example

For a PR, "Current behavior" describes the state of the diff, and the brief asks the agent to finish or fix it rather than build from scratch.

```markdown
## Agent Brief

**Category:** enhancement
**Summary:** Finish the contributor's `--json` output flag for `triage list`

**Current behavior:**
The PR adds a `--json` flag that serializes the issue list to JSON. The happy
path works and the diff matches the project's command structure. Two gaps
remain: errors are still printed as human text (not JSON), and the new flag has
no test coverage.

**Desired behavior:**
With `--json`, all output — including errors — is well-formed JSON on stdout,
and the command's exit codes are unchanged. The existing human-readable output
is untouched when the flag is absent.

**Key interfaces:**
- The command's error path should emit `{ "error": string }` under `--json`
  instead of the plain-text error
- Reuse the existing serializer the PR already added; don't introduce a second

**Acceptance criteria:**
- [ ] `triage list --json` emits valid JSON for both success and error cases
- [ ] Exit codes match the non-JSON command
- [ ] A test covers the `--json` success output and one error case
- [ ] Default (non-JSON) output is byte-for-byte unchanged

**Out of scope:**
- Adding `--json` to any other command
- Changing the JSON shape of the success payload the PR already defined
```

## Bad Brief Pattern

Avoid briefs that say only "fix the bug", point to stale file paths or line numbers, omit category, lack acceptance criteria, or skip scope boundaries.

## Needs-Info Notes

Use this template when moving an issue to `needs-info`. Capture resolved facts so future triage does not repeat work. Questions must be specific and actionable.

```markdown
## Triage Notes

**What we've established so far:**

- point 1
- point 2

**What we still need from you (@reporter):**

- question 1
- question 2
```
