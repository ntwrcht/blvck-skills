---
name: write-user-docs
description: "Writes learning-oriented documentation for people outside the team — user manuals, how-to guides, getting-started pages, CLI references, and developer tutorials — with goal-shaped titles, numbered steps, and verification checkpoints. Use when producing a product user guide, help-center or knowledge-base article, quickstart, command reference, or step-by-step tutorial."
argument-hint: "<product or topic, and the doc type>"
---

# Write User Docs

Produce documentation someone follows to get something done. The test is not whether the page is accurate — it is whether a reader who has never seen the product reaches the end with the task completed.

## When to Use

Use when the audience sits outside the team that built the thing: end users of a product, developers integrating with an API, or operators picking up a CLI. Common phrasings: "write a user manual", "create a how-to guide", "we need a quickstart", "document this CLI", "write a tutorial for our API", "help-center article".

## When Not to Use

- The doc describes a system rather than teaching a task — use `code-to-docs` for architecture, API specs, diagrams, and runbooks.
- The reader is a maintainer of this codebase — that is a README or an architecture doc.
- The user holds the context and wants to co-write a spec, proposal, or RFC — use `doc-coauthoring`.
- The output is a requirement or backlog item — use `write-a-prd` or `write-a-story`.
- An audience needs a status or outcome summary rather than instructions — use `stakeholder-comms`.

## Artifacts

- Produces: the document at the `user-docs` key path — see `references/artifact-paths.md` (default `docs/user/<slug>.md`).
- Consumes: the product or codebase, existing docs to stay consistent with, and whatever the user supplies — screenshots, style guides, prior articles.

## Core Rule

Write to the reader's goal, not the product's structure. "How to assign a task to a teammate" is a title; "The Task Detail Panel" is a feature list. Every procedure ends with the reader able to confirm it worked.

## Workflow

1. Pin down four things before writing: the **doc type**, the **reader** and what they already know, the **goal** they finish with, and the **prerequisites** they need first. Ask if any is unclear — guessing the reader's starting knowledge is the failure mode that wastes the most work.
2. Pick the shape. Manuals, how-to guides, and getting-started pages → load `references/manual-structure.md`. Developer tutorials, CLI references, and API integration guides → load `references/howto-and-tutorials.md`.
3. Walk the actual product or codebase for the flow being documented. Every step, field name, button label, flag, and command comes from what is really there.
4. Draft the steps. Numbered, one action each, UI labels and commands in bold or code. State the expected result after any step whose success is not self-evident.
5. Add the parts writers skip: what happens next, troubleshooting for the two or three ways this actually goes wrong, and links to the adjacent task.
6. Mark where visuals belong with a concrete caption — `[Screenshot: the New Task dialog, Title field highlighted]`. Do not describe an image as though it were already there.
7. Run the fresh-reader pass: read the draft as someone with only the stated prerequisites. Every assumed term, skipped click, or unexplained result is a defect. Fix and re-read.
8. Verify the code. Every command and snippet must run as written, with imports and setup included.

## Reference Map

- `references/manual-structure.md` — section layouts for user manuals, how-to guides, getting-started pages, and knowledge-base articles, plus the plain-language and accessibility rules.
- `references/howto-and-tutorials.md` — developer tutorial progression, checkpoint pattern, CLI reference layout, and API integration guide structure.
- `references/artifact-paths.md` — where the document is written.

## Next Step

The draft is finished when someone who matches the target reader follows it start to finish without asking a question. Say plainly that this has not happened yet and that the fresh-reader pass in step 7 is a substitute, not a replacement.

- **If approved:** hand off to `code-to-docs` when the same product also needs an API spec, architecture doc, or runbook underneath the user-facing layer.
- **If not approved:** revise in place against the specific step where the reader got stuck — a failure at step 4 usually means the prerequisites in step 1 were wrong, so re-check those before rewriting prose. If the product behavior itself is what confused the reader, say so rather than papering over it with more words.
