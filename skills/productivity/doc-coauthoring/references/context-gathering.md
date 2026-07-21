# Stage 1 — Context Gathering

Goal: close the gap between what the user knows and what the agent knows, so later guidance is smart instead of generic.

## Meta Questions

Open with these five. Tell the user shorthand is fine and they can dump information in whatever order it comes out.

1. What type of document is this — spec, decision doc, proposal, something else?
2. Who is the primary audience?
3. What should happen after someone reads it?
4. Is there a template or required format?
5. Any constraints, deadlines, or context to know up front?

## Templates and Existing Docs

- If the user names a doc type, ask whether they have a template to share.
- If they link a doc in a connected store (Drive, Confluence, SharePoint), read it directly with the available integration. If no integration is connected, say so and ask for a paste.
- If they are editing an existing doc, read its current state before proposing anything.
- If that doc contains images without alt-text, flag it: when a reader pastes the doc into an agent, the images are invisible. Offer to write alt-text from images they paste into the conversation.

## Info Dumping

Ask for everything they have, unorganized. Name the categories so they remember what they know:

- Background on the problem and how it got here
- Related discussions, threads, or channels
- Alternatives considered and why they were rejected
- Organizational context — team dynamics, past incidents, politics
- Timeline pressure and constraints
- Technical architecture and dependencies
- Stakeholder concerns and who will push back

Offer three ways to deliver it: dump stream-of-consciousness, point at channels or docs to read, or link files. If connectors or MCP servers are available, say which ones and offer to pull directly. If none are connected and the environment supports them, mention that connectors can be enabled in settings.

Before searching any connected tool for an unfamiliar entity, ask first and wait for confirmation.

## Clarifying Questions

When the dump slows or the user signals they are done, ask 5-10 numbered questions targeting the gaps. Ground each one in something they actually said — generic questions signal the dump was not read.

Tell them shorthand answers are fine: `1: yes, 2: see #payments-eng, 3: no, backwards compat`. Links, channel pointers, and more dumping are all acceptable answers.

Repeat the batch if the answers open new gaps. Two rounds is normal; a third means the doc is probably bigger than one document.

## Exit Condition

Context is sufficient when questions can probe edge cases and trade-offs without needing the basics re-explained. Ask whether the user wants to add anything else before drafting starts, and move to Stage 2 when they are ready.
