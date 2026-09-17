---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Split this feature into issues.

Scheduled exports: users pick a saved report, a cadence (daily, weekly, monthly), and a destination (email or S3). A scheduler enqueues jobs each minute. Failures retry three times, then email the owner. Maximum 50 schedules per workspace.
