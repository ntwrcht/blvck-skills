---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Claude never uses my research agent — it just does the research itself in the main chat. Why? Here's the file:

```md
---
name: researcher
description: Research agent. Helps with research tasks.
---
You are an expert researcher. Research the topic thoroughly and be comprehensive.
```
