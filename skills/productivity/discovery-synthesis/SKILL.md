---
name: discovery-synthesis
description: "Synthesizes raw user evidence — interview notes, support tickets, survey responses, call transcripts — into Jobs-to-be-Done findings, each framed as a job with its pains and desired outcomes and backed by verbatim quotes with a count of how many sources support it. Use when turning research notes into findings, running a discovery synthesis, extracting jobs or pains from customer feedback, or building the evidence base before a PRD or a grilling session."
argument-hint: "<paths to notes, tickets, transcripts, or survey exports>"
---

# Discovery Synthesis

Turn a pile of user evidence into findings a team can act on. Every finding is a **job** the user is trying to get done, with the pains in their way and the outcomes they want, and every finding names the sources that support it.

## When to Use

Use this skill when raw user evidence exists and nobody has synthesized it: interview notes, support tickets, survey free-text, call transcripts, app reviews, sales call summaries. It is the start of the pipeline — it runs before `grilling` decides what to do, before `write-a-prd` commits to a solution, and before `prioritize` ranks candidates.

## When Not to Use

- **The unknown is an external fact** — how a library behaves, what a spec says — use `research`. This skill reads people, not documents.
- **The knowledge is in the user's own head** — use `grilling`. This skill synthesizes what other people said.
- **The evidence has not been gathered yet** — tell the user to run `/to-questionnaire` to collect it, then come back.
- **The goal is a session summary** — use `handoff`.

## Artifacts

- Produces: findings at the `discovery` key path — see `references/artifact-paths.md` (default `docs/discovery/<slug>.md`)
- Consumes: the evidence files the user names, `.context/project.md`, `CONTEXT.md`
- Bundled: `references/jtbd-frame.md` — job statement format, pain and outcome definitions, severity and evidence-strength scales; `references/synthesis-template.md` — the findings structure

## Core Rule

Every finding names its evidence. A finding supported by one source is an anecdote and is labelled so. A persona, segment, or motive the sources do not contain is not written — the findings hold what people said, and hypotheses about what they meant go in their own section.

## Workflow

1. **Inventory the sources.** List every file: type, date, count of respondents or tickets, and who they are as far as the source says. Give each source a short id (`I-03`, `T-117`) so every quote can cite one. Confirm the inventory with the user — synthesis over the wrong pile is worthless.
2. **Read everything end-to-end before tagging.** Skim-and-tag produces themes from the first third of the pile.
3. **Tag.** On a second pass, mark each passage as a job, a pain, a desired outcome, a workaround, or a quote worth keeping, with its source id. Load `references/jtbd-frame.md` for what each tag means and the job statement format.
4. **Cluster into candidate jobs.** Group tags by the job the person was trying to get done, not by feature or by product area. A job that appears under different words in different sources is one job — name it once and list the variants.
5. **Write each finding:** the job statement, its pains ranked by severity, the outcomes people asked for, the workarounds they use today, the evidence count, and two or three verbatim quotes with source ids.
6. **Rank findings by evidence strength** — breadth (how many sources) and severity (how much the pain costs the person). Move single-source findings to an Anecdotes section.
7. **Record contradictions and gaps.** Where sources disagree, say so with both sides cited. Where the questions asked could not have surfaced something, name it under Gaps.
8. **Write the artifact** to the `discovery` key path using `references/synthesis-template.md`.
9. **Report:** the top jobs, the strongest pain under each, and the questions this evidence cannot answer.

## Operating Rules

- Quotes are verbatim, with a source id. Paraphrase is analysis, not evidence.
- Counts over adjectives: "7 of 12 interviews" not "most users".
- Redact names, emails, company names, and anything else that identifies a person, in quotes and in the inventory. Replace with the source id.
- Keep hypotheses out of findings. A guess about cause or a proposed solution goes under Hypotheses to Test, with the finding it came from.
- Findings describe what people are trying to do; they never prescribe a feature. The feature is `grilling`'s and `write-a-prd`'s job.

## Reference Map

- `references/jtbd-frame.md`: job statement format, definitions of pain, outcome, and workaround, the severity scale, and the evidence-strength rule.
- `references/synthesis-template.md`: the findings artifact structure, including the anecdotes, contradictions, gaps, and hypotheses sections.

## Review Checklist

- Does every finding carry a source count and at least two cited quotes, or sit under Anecdotes?
- Is every job written as a situation, motivation, and outcome — not as a feature request?
- Are all names and identifiers redacted?
- Are hypotheses and proposed solutions separated from findings?
- Would a reader who doubts a finding know which sources to open?

## Next Step

The synthesis is done when the user has confirmed the source inventory is complete and the top jobs match their own reading of the evidence.

- **If approved:** hand off to `grilling` to decide what to do about the top job, to `write-a-prd` when the solution is already decided, or to `prioritize` when the findings are evidence for candidates that already exist.
- **If not approved:** ask which finding's evidence looks thin or misread, re-read those sources, and revise in place. If the evidence itself is missing — too few sources, or the right people were never asked — stop and tell the user to run `/to-questionnaire` to gather it.
