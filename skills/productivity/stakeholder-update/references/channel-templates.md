# Channel Templates

Ask for the channel if it is unclear. Format the same update differently by delivery channel.

Keep the message's decision shape intact across channels:

- First line: outcome, risk, or decision needed
- Middle: only the evidence the audience needs
- End: owner, action, date, or next milestone

## Issue Tracker

Use this for Jira, Linear, GitHub Issues, Azure Boards, or similar tools. Use a structured status comment with bold labels. Keep enough tracking detail for internal readers.

```text
**Status:** [Green / Yellow / Red]
**TL;DR:** [Outcome or risk in one line]
**Impact:** [Who is affected and how]
**Progress:** [What changed since last update]
**Risk / blocker:** [Risk, owner, mitigation]
**Decision / ask:** [Decision needed, recommendation, deadline]
**Next step:** [Concrete next action and date]
```

## Team Chat

Use this for Slack, Microsoft Teams, Discord, Google Chat, or similar tools. Use one compact message. Lead with a bold TL;DR, then 2-4 short bullets. Prefer one primary link.

```text
**TL;DR:** [Most important outcome, risk, or ask]
- Impact: [Who benefits or is affected]
- Progress: [What changed]
- Ask: [Decision/action needed, if any]
- Next: [Owner/action/date]
```

## Noisy or Threaded Chat

When the channel has many parallel conversations, make the topic explicit.

```text
**[Topic] update:** [One-line outcome]
- What changed: [Short summary]
- What we need: [Action or decision, if any]
- Next: [What happens next]
```

## Email

Use a clear subject, short paragraphs, and an explicit ask if one exists.

```text
Subject: [Outcome, risk, or decision needed]

Hi [audience],

[TL;DR paragraph.]

[Progress, risk, or launch detail.]

Next: [What is coming, owner, and any action needed.]
```

## Website or Public Changelog

Use customer-facing language only. Remove internal process, internal tools, project codes, ticket IDs, and team names.

```text
## [Customer benefit or feature name]

[One-sentence summary of what is now possible.]

What's new:
- [Customer-visible change]
- [Customer-visible benefit]

What's next:
- [Expected next improvement or rollout note]
```

## Document or Slides

Use section headings and scannable bullets. Put the decision or status on the first page or first section. Include an appendix only for technical detail that some readers may need.

For slides:

- One message per slide.
- Put the status, decision, or ask in the title.
- Use short bullets and avoid paragraphs.
- Put technical detail in backup slides.

For documents:

- Start with an executive summary.
- Use headings for progress, risks, decisions, and next steps.
- Keep appendices separate from the primary narrative.
