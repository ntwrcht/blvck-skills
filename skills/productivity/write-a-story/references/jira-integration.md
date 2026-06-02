# Jira Integration

Use Jira tools only when all of these are true:

- A Jira MCP/tool is available in the current environment.
- The user asks to create, add, post, update, or sync the backlog item in Jira.
- The target project, issue type, and required fields are known or can be discovered through the Jira tool.
- The user has approved the exact issue payload.

Default to draft-only output. Do not create, update, transition, assign, or comment on Jira issues unless the user explicitly confirms after reviewing the payload.

## Workflow

When Jira creation or update is requested:

1. Draft the item or item set in chat first.
2. Determine the target project, issue type, parent epic, labels, priority, assignee, sprint, and required custom fields from user input or Jira metadata.
3. If required Jira fields are missing, ask only for the missing required fields.
4. Show the exact payload that will be sent:
   - Summary/title.
   - Issue type.
   - Project.
   - Description/body.
   - Acceptance criteria.
   - Definition of Done, if included.
   - Priority, estimate, labels, parent, dependencies, and any custom fields.
5. Ask for explicit approval using a direct question such as: "Create these Jira issues with this payload?"
6. Proceed only after a clear approval such as "yes", "approved", "create it", "go ahead", or "add them to Jira".
7. After the Jira tool call, report the created or updated issue keys and links when available.
8. If Jira creation fails, report the failure and keep the approved payload visible so the user can retry or paste it manually.

## Multiple Items

For multiple generated items, ask whether to create:

- One epic with child stories/tasks.
- Separate standalone stories/tasks.
- A smaller selected subset.

Prefer mapping:

- Epic output -> Jira Epic when the project supports it.
- Story output -> Jira Story.
- Bug output -> Jira Bug.
- Spike output -> Jira Task or Spike, depending on available issue types.
- Chore or internal work -> Jira Task unless the user or project convention says otherwise.

Never guess destructive or workflow-changing fields such as sprint commitment, fix version, release version, due date, or assignee. Leave them unset or ask when they are required.
