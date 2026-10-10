---
max_turns: 5
allowed_tools: [Skill, Read, Glob]
---

/wait-what

I asked why my memoized `<Chart>` component keeps re-rendering, and this was your previous reply:

> Inline obj prop -> new ref each render -> memo'd child re-renders. useMemo it.
