# Jobs-to-be-Done Frame

The unit of a finding is a **job**: progress a person is trying to make in a situation. Products get hired to do jobs; features come and go. Synthesizing at the job level keeps findings true after the current UI is gone.

## Job statement

```text
When <situation>, I want to <motivation>, so I can <expected outcome>.
```

- **Situation** is the trigger — what was happening when the need showed up. It is the most-skipped part and the most useful: it says when the product gets hired.
- **Motivation** is what the person is trying to do, in their words, free of any solution.
- **Expected outcome** is how they would know it worked.

A statement that names a feature ("I want a dashboard") is a solution, not a job. Ask what the dashboard would let them do, and write that.

## Tags

| Tag | Meaning | Test |
|---|---|---|
| Job | Progress the person is trying to make | Would still be true if the product disappeared |
| Pain | Something blocking or taxing that progress today | The person loses time, money, confidence, or standing |
| Outcome | How they would judge the job done well | Measurable or observable by the person |
| Workaround | What they do today instead | Evidence the job is real and the pain is worth paying for |
| Quote | Verbatim words worth keeping | Carries the pain or the job in the person's own language |

## Severity scale for pains

| Score | Meaning |
|---|---|
| 3 | Blocks the job — the person gives up, escalates, or leaves |
| 2 | Taxes the job — significant time, money, or a workaround every time |
| 1 | Annoys — noticed, tolerated |

Score from what the person said or did, not from how the pain sounds.

## Evidence strength

Rank findings by **breadth × severity**: breadth is the count of distinct sources supporting the finding, severity is the highest pain score under it.

- Two or more sources: a finding.
- One source: an anecdote. Keep it, label it, do not rank it with findings.
- Counts are over distinct sources, not mentions — one interview repeating a pain five times is one source.
