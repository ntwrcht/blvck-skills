# Writing the Instructions

Sentence-level rules for a skill's body, each traced to Anthropic's published guidance. `SKILL.md` carries the one-line rule; this file carries a before/after and the source for each.

**Load this when** drafting or reviewing a skill's prose, or fixing a finding from the sentence pass.

## Contents

- What to Write — rules 1–3
- How to Phrase — rules 4–10
- Structure — rules 11–13
- A Worked Rewrite
- Sources

## What to Write

### 1. Only what the model does not already know

Keep a sentence only if removing it would cause a mistake.

- **Before:** "PDF files are a common format that holds text and images. To extract the text, you will need a library."
- **After:** "Extract text with `pdfplumber`; `pypdf` scrambles multi-column layouts."

"Only add context Claude doesn't already have." [BP] · "Would removing this cause Claude to make mistakes?" [CCBP]

### 2. Specificity matched to fragility

A fragile operation — a migration, a release, a file format a parser reads — gets the exact command. Judgment work — a review, a design, prose — gets the goal, the reason, and a heuristic. When unsure, write the general form: current models do worse under over-prescription.

- **Before (judgment, over-prescribed):** "Step 1: read the first function. Step 2: check its names. Step 3: check its error handling…"
- **After:** "Review the diff for correctness first, then naming. Report 3–5 findings, each with `file:line`."
- **Before (fragile, under-specified):** "Run the migration."
- **After:** "Run exactly `./migrate.sh --verify`, with no other flags."

"Match the level of specificity to the task's fragility and variability." [BP] · "Skills developed for prior models are often too prescriptive… and can degrade output quality" [Fable 5]

### 3. One default, with an escape hatch

- **Before:** "You can use pypdf, pdfplumber, PyMuPDF, or pdf2image."
- **After:** "Use `pdfplumber`. For a scanned PDF with no text layer, use `pdf2image` with OCR instead."

"Don't present multiple approaches unless necessary" [BP]

## How to Phrase

### 4. Open with an imperative verb

The verb decides what comes back: "suggest changes" gets suggestions, "change" gets edits.

- **Before:** "It would be good if the tests were run before committing."
- **After:** "Run the tests before committing."

"Prefer using the imperative form in instructions." [SC] · "Can you suggest some changes" yields suggestions, "Change this function" yields edits [PBP]

### 5. The reason, in one clause, instead of a MUST

A reason lets the agent generalize to cases the rule never named. One clause is enough; a paragraph of justification is narration.

- **Before:** "NEVER use ellipses."
- **After:** "Write no ellipses — a text-to-speech engine reads the output and cannot pronounce them."

"Claude is smart enough to generalize from the explanation." [PBP] · "explain to the model why things are important in lieu of heavy-handed musty MUSTs" [SC] · "State what to do rather than narrating how or why" [CC]

### 6. Say what to do, and name the alternative

A bare prohibition pulls the banned behaviour into context (see `principles.md`, Steering by the Positive) and leaves the model to pick a replacement of its own. Naming the alternative picks it for the model.

- **Before:** "Don't use markdown."
- **After:** "Write in flowing prose paragraphs."

"Tell Claude what to do instead of what not to do" [PBP] · generic "don't" instructions "tend to shift the model to a different fixed palette" [Opus 4.8]

### 7. A concrete bar instead of an adjective

- **Before:** "Write a thorough, high-quality summary."
- **After:** "Summarize in 3–5 bullets, each naming one decision and its owner."

"Be concrete about where the bar is rather than using qualitative terms like 'important'" [Opus 4.8]

### 8. Explicit scope

The agent applies an instruction only where it is stated.

- **Before:** "Add a docstring to the `parse` function." — meant for every public function
- **After:** "Add a docstring to every public function in `parser.py`."

"It does not silently generalize an instruction from one item to another… state the scope explicitly" [Opus 4.8] [Sonnet 5]

### 9. Every qualifier is obeyed literally

"Be conservative", "only if you are sure", and "don't nitpick" each change the output. Write one only when you want its effect.

- **Before (security review):** "Be conservative and only flag issues you are sure of." — cuts recall
- **After:** "Flag every issue that could plausibly be exploited, each marked high, medium, or low confidence."

Qualifiers such as "be conservative" lower the number of findings reported [Opus 4.8] [Sonnet 5]

### 10. One term per concept

A synonym reads as a new thing.

- **Before:** "Collect the use cases… for each scenario… every example should…"
- **After:** "use case" in every sentence.

"Choose one term and use it throughout the Skill" [BP] · A leading word is the deliberate version of this rule — one term repeated on purpose (see `principles.md`).

## Structure

### 11. Numbered steps where order matters, branches where the path splits

- **Before:** "Read the schema and write the migration and test it and also check whether the table exists."
- **After:**
  1. If the table does not exist, create it from `schema.sql` and go to step 3.
  2. Write the migration.
  3. Run the migration against the test database.

For a fragile multi-step job, add a checklist the agent copies into its reply and a validate → fix → repeat loop.

"Provide instructions as sequential steps… when the order or completeness of steps matters" [PBP] · "Guide Claude through decision points" [BP] · "Run validator → fix errors → repeat" [BP]

### 12. Show the format

One concrete example beats a description of it. When giving several, give 3–5 and vary them so none gets copied. Scale a template's strictness to the reader: "use exactly this template" for output a program parses, "a sensible default — adjust as needed" for prose.

- **Before:** "Output a table of findings with severity."
- **After:**

  | Severity | File | Finding |
  |---|---|---|
  | High | `auth.py:42` | Token compared with `==`, open to a timing attack |

The skill's own style leaks into its output: a body written as dense bullets gets bullet-heavy answers.

"Examples convey the desired style and level of detail to Claude more clearly than descriptions alone." [BP] · "Include 3–5 examples"; vary them so the model "doesn't pick up unintended patterns" [PBP] · "Removing markdown from your prompt can reduce the volume of markdown in the output" [PBP]

### 13. Emphasis only as a targeted fix

Write plain sentences. When an eval shows one instruction being skipped, give it a reason first (rule 5); emphasize that line alone only if the reason does not land.

- **Before:** "CRITICAL: You MUST ALWAYS run the linter. NEVER skip tests. IMPORTANT: …"
- **After:** "Run the linter before each commit — CI rejects unlinted code."

"add emphasis such as 'IMPORTANT' to that line alone. If you emphasize many lines, none of them stands out" [CCBP] · "If you find yourself writing ALWAYS or NEVER in all caps… that's a yellow flag" [SC] · aggressive "CRITICAL: You MUST" language makes current models overtrigger [PBP]

## A Worked Rewrite

**Before:**

> It's very important that you review the code thoroughly. You should try to look for bugs and maybe style issues if possible. Don't be too nitpicky. You can use grep or read the files or use git diff. ALWAYS be helpful.

**After:**

> Review the diff from `git diff main...HEAD`. Report correctness bugs first, then style issues that break the repo's lint config. Give 3–5 findings, each with `file:line`, what breaks, and a one-line fix. If there are no bugs, say so and name the riskiest change you checked.

What changed: a no-op dropped ("be helpful", rule 1); one default tool (rule 3); a concrete bar (rule 7); an explicit scope (rule 8); the recall-cutting qualifier gone (rule 9); a branch for the empty result (rule 11); the caps gone (rule 13).

## Sources

Checked 2026-09. Model-specific claims apply to the named models; confirm them with the skill's own evals before relying on them elsewhere.

- [BP] [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [SC] [Anthropic's skill-creator](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md)
- [CC] [Claude Code skills](https://code.claude.com/docs/en/skills)
- [CCBP] [Claude Code best practices](https://code.claude.com/docs/en/best-practices)
- [PBP] [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- [Opus 4.8] [Prompting Claude Opus 4.8](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-4-8)
- [Sonnet 5] [Prompting Claude Sonnet 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5)
- [Fable 5] [Prompting Claude Fable 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5)
