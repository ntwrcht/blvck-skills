---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Write the PRD for bulk refunds in the support console. Paste it in your reply.

Today a support agent refunds orders one at a time: open the order, click Refund, confirm. During the March outage agents issued 1,840 refunds by hand over two days, and finance found 37 duplicates afterwards. We want agents to select up to 200 orders from a search result and refund them in one action. Refunds above $500 per order still need a team lead's approval, same as today. Finance wants a CSV export of every bulk run. Partial refunds are out of scope for now. We have no baseline for how long a single refund takes.
