---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Here is the design doc we signed off on. Write the requirements from it.

# Design: Scheduled Exports

Users pick a saved report, a cadence (daily, weekly, or monthly), and a destination (email or S3). A scheduler service polls an `export_schedules` table each minute and enqueues jobs. Failures retry three times, then email the schedule owner. Maximum 50 schedules per workspace. We considered per-user timezones and deferred it — everything runs in the workspace timezone.
