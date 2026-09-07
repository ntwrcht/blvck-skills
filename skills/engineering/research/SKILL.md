---
name: research
description: "Investigates a question against high-trust primary sources in a background agent and captures the findings as a cited Markdown file. Use when a topic needs researching, docs or API facts need gathering, a library's real behaviour needs confirming, or reading legwork should run in the background while other work continues."
---

# Research

Answer a question from **primary sources** — the documents that own the claim — and leave a cited record behind.

## When to Use

Use this skill when a question needs reading rather than reasoning: how a library actually behaves, what an API really returns, what a spec requires, whether a claim in a blog post holds up. It suits questions that are AFK-friendly, where the answer is worth keeping and the reading is worth delegating.

## When Not to Use

- **The question is about this codebase** — read the code. This skill is for external sources; a repo question is a search, not a research task.
- **The answer is a decision, not a fact** — use `grilling`. Research settles what is true; grilling settles what to do about it.
- **The work is implementation with reading attached** — use `subagent-driven-development`. That skill delegates building; this one delegates reading.

## Artifacts

- Produces: findings at the `research` key path — see `references/artifact-paths.md` (default `docs/research/<slug>.md`)
- Consumes: `.context/project.md`

## Core Rule

Follow every claim back to the source that owns it. A secondary write-up is a lead, not a source.

## Workflow

Spin up a **background agent** to do the research, so the session keeps working while it reads.

Its job:

1. **Investigate against primary sources** — official docs, source code, specs, first-party APIs — not a secondary write-up of them. When a blog post or answer thread supplies the lead, follow it to the document that owns the claim and cite that instead.
2. **Write the findings to a single Markdown file**, citing each claim's source inline. A claim with no citation does not go in the file.
3. **Say what it could not settle.** An open question named explicitly is worth more than a confident guess, and it tells the reader where to pick up.
4. **Save it to the `research` key path**, matching whatever convention the repo already uses for such notes if one differs. Report where the file landed.

## Source Trust

Rank sources by who owns the claim:

1. The spec, RFC, or standard that defines the behaviour.
2. First-party documentation and the project's own source code.
3. First-party changelogs, release notes, and issue threads.
4. Third-party write-ups — usable as leads, cited only when nothing first-party covers the point, and flagged as second-hand when they are.

Note the version, date, or commit a claim is true of. A fact with no version attached goes stale silently.

## Next Step

The findings file is the deliverable. The user reading it and confirming it answers the question is the approval gate.

- **If approved:** hand off to whichever skill raised the question — `grilling` when the fact unblocks a decision, an implementation skill when it unblocks code, or back to `grilling` if the fact reopens the option space. If the finding settles a hard, surprising trade-off, hand off to `domain-modeling` to record an ADR.
- **If not approved:** ask which claim is thin or which question went unanswered, then run another pass narrowed to that gap — do not broaden the topic.

---

_Adapted from the `research` skill in `mattpocock-skills`, MIT-licensed © 2026 Matt Pocock._
