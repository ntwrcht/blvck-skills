---
name: kode-thai
description: Runs an iterative audit-and-fix loop over Thai prose against the kien-thai rule set, repeating passes until one produces zero new edits. Use when the user invokes /kode-thai, asks for an audit loop or repeated review passes on Thai writing, or says variants of "ตรวจวนๆ", "วน audit", "ขัดภาษาไทยให้สุด", or "แก้ไปเรื่อยๆ จนกว่าจะไม่เจอที่ผิด".
---

# kode-thai

โคตรไทย — invoke kien-thai in a loop until the prose stops changing.

## Why this exists

Single-pass review misses issues that only surface after earlier fixes shift
sentence shape. A connective collapses, the next sentence's framing changes, a
new awkward seam appears. Loop until clean.

## When to Use

Use when Thai prose needs passes repeated to convergence rather than one review: `/kode-thai`,
"ตรวจวนๆ", "วน audit", "ขัดภาษาไทยให้สุด", "แก้ไปเรื่อยๆ จนกว่าจะไม่เจอที่ผิด".

Use `kien-thai` on its own for a single pass. That skill is the rule set; this one only drives
it to a fixed point — see **Relationship to kien-thai**. `kien-thai`'s scope limits apply here
unchanged, so prose shorter than a paragraph, UI strings, and non-Thai content stay out of the
loop. Check **Token cost** before starting on anything over ~1000 words.

## Artifacts

- Produces: the target Thai prose file, edited in place until an audit pass finds nothing. No
  separate artifact, so it is outside the shared artifact-paths registry.
- Consumes: the target file, plus `kien-thai`'s `SKILL.md` and all eight of its references

## Protocol

1. Invoke the `kien-thai` skill and load it in full — its `SKILL.md` plus all
   eight of its references (ai-tells, craft, grammar, style-rules, register,
   examples, exemplars, forbidden-phrases). Don't skip references. Both audit
   and fix passes need depth — this is a deep language-analysis job, not
   mechanical scanning. When the register is known and context is tight, scope
   register, examples, and exemplars to that register; load the rest in full.

2. Read the target file end-to-end before editing anything. Skim-and-fix
   produces shallow passes.

3. Audit pass. Deep-read end-to-end first, then list every issue. Cite each
   issue with the rule's slug (e.g. `f4/targhak-closure`, `wrong-classifier`,
   `f6/ko-resumptive`) and quote the offending text inline. As a pre-check,
   scan `forbidden-phrases.md` against the prose — un-backticked occurrences
   only (use/mention exemption). If everything passes, output a single line
   `CLEAN` — no prose, no commentary.

4. Fix pass. Apply the listed edits.

5. Re-read the edited file end-to-end. Diff-level review misses paragraph-flow
   problems that only show on full re-read.

6. Repeat steps 3–5 until one audit pass produces zero new issues.

7. Stop only on a clean pass — not on "good enough", not on "running out of
   obvious things". If you think it's done, run one more audit pass to confirm.

## Stop condition

The loop ends when an audit pass surfaces zero edits. A pass that finds one
issue and fixes it doesn't end the loop — the next pass might surface a new
issue caused by that fix. Only a fully clean pass terminates.

## Token cost

Each pass reloads kien-thai (~tens of thousands of tokens of skill +
references) plus the full target file. For long prose this compounds fast.
Warn the user before starting on files over ~1000 words so they can decide
whether to scope the loop to a section.

## Best input

The loop audits any Thai prose, but it earns the most over a draft written by a
model that carries the native Thai distribution rather than translating into it
— see kien-thai's "Honest limits". Auditing Thai against the seven frames is
language judgment, not a mechanical transform, so this half stays with the
agent regardless of who drafted.

## Relationship to kien-thai

`kien-thai` is the rule set. `kode-thai` is the loop. This skill adds no new
rules — it enforces that kien-thai's rules get applied to convergence. If the
audit surfaces a pattern no kien-thai rule covers, trace the gap to a specific
passage and name it in the report rather than inventing a rule mid-loop; a new
rule belongs in kien-thai, argued from evidence, not synthesized on vibes.

## Next Step

The loop ends on a clean audit pass and hands the author a converged draft to
read.

- **If approved** — the prose is done; hand off to the skill that owns the
  destination format if the piece still needs one (`write-user-docs` for a
  guide, `stakeholder-comms` for an update).
- **If not approved** — the objection is voice or register, not rule
  compliance, since the rules already converged. Name the target register from
  kien-thai's `register.md`, then re-run this loop against that register. If no
  register fits the reader's intent, pause and ask the author who the reader is
  and how formal the piece should sound.
