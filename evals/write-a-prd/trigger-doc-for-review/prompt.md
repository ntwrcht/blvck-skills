---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

I need something the team can review before we build this — the problem, what we are actually shipping, and what we are explicitly not doing.

Our onboarding has 4 steps and 60% of signups drop at step 3, which is company details. We want to make steps 3 and 4 skippable and ask for that information later, the first time the user hits a feature that needs it. Sales wants company size captured at signup; we are saying no for now. We cannot change the auth step.
