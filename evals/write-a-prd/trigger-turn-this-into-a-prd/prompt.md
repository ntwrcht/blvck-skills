---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Can you turn everything we just decided into a PRD?

Here is what we landed on in the meeting:
- Support agents re-type the same customer details into three systems for every refund. It takes about 6 minutes per refund, and we do about 400 refunds a week.
- We are building one refund form that writes to all three systems.
- Agents only. No customer-facing self-serve refunds this round.
- The billing API has a 5 calls/sec rate limit we have to respect.
- We are not touching the partial-refund rules.
