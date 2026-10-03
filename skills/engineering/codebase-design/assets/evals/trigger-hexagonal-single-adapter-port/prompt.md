---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

We're going hexagonal. Should I put a port in front of our SendGrid email sender? SendGrid is the only implementation, and right now nothing tests the email path.
