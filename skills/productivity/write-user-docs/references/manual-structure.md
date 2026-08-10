# Manuals, How-To Guides, and Getting Started

Four end-user document types. They differ by how much the reader already knows and how much they want to read.

| Type | Reader arrives | Reader leaves with | Length |
| :--- | :--- | :--- | :--- |
| Getting started | Knows nothing, wants proof it works | One small thing done, in under five minutes | 1–2 screens |
| How-to guide | Has a specific task in mind | That task done | 1 screen |
| Knowledge-base article | Searched a problem | The problem resolved | 1 screen |
| User manual | Needs a reference to return to | A place to look things up | Many sections |

## Getting started

Optimize for time-to-first-success. Everything that is not on the shortest path to a working result belongs elsewhere.

```markdown
# Getting Started with <product>

<One sentence: what this product does and who it is for.>

By the end of this page you will have <the concrete first result>. It takes
about five minutes.

## Before you begin
- <account, install, or permission — each one checkable>

## 1. <First action>
<Command or click. Expected result immediately after.>

## 2. <Second action>
...

## You should now see
<The observable proof it worked.>

## Next steps
- <Link to the natural second task>
- <Link to core concepts>
```

Rules: no more than five steps, no branching, no optional detours, no configuration that has a working default. If the quickstart cannot fit in five minutes, the honest fix is usually to shrink the promised result.

## How-to guide

One task per guide. A guide covering "managing tasks" will be abandoned; "how to reassign a task" will be followed.

```markdown
# How to <do the specific thing>

<One or two sentences: what this accomplishes and when you would want it.>

## Before you begin
- <prerequisite>

## Steps

1. <Action>. 
   [Screenshot: <what it shows, what is highlighted>]
2. <Action>. Enter a **Title** — this is the only required field.
3. Click **Save**.

## What happens next
<The observable result, and any side effect the reader should expect —
notifications sent, other people who now see this, state that changed.>

## Troubleshooting

**<Symptom the reader would describe>**
<Cause and fix.>

## Related
- <Adjacent task>
```

## Knowledge-base article

Same skeleton as a how-to guide, plus search metadata and a feedback loop. Title it as the reader would phrase the problem — "Why can't I see the New Task button?" outperforms "Task permissions".

Add above the body: category, tags (action verbs, feature names, user roles), and last-updated date. Add below it: a related-articles list and a helpfulness prompt. Track which articles get negative feedback and which searches return nothing — those are the content gaps.

## User manual

```markdown
1. Introduction — what the product is, who it is for, what this manual covers
2. Getting started — the five-minute first success
3. Feature sections — one per user goal, each self-contained
4. Troubleshooting — organized by symptom
5. FAQ
6. Glossary
7. Support — how to reach a human
```

Organize the feature sections by what the reader is trying to do, not by the navigation menu. "Collaborating with your team" is a section; "Settings" is not. Each section must be readable on its own — nobody reads a manual front to back, so a section that depends on an earlier one needs an explicit link, not an assumption.

## Writing rules

- **Second person, active, present.** "Click **Save**" — not "the Save button should be clicked", not "the system will save".
- **One action per numbered step.** Two actions in one step is where readers lose their place.
- **Bold the interface, code the terminal.** `**Save**`, `` `npm install` ``.
- **Fifteen to twenty words per sentence.** One idea each.
- **Say the result.** After any step whose success is invisible, state what the reader should see.
- **Numbered for sequences, bulleted for sets.** Bulleted steps read as optional.
- **Define jargon on first use, or link to the glossary.** No unexplained internal terms — "SLA tier" means nothing outside the company.
- **Concrete examples.** "Draft Q4 blog post", not "Task Name 1".

## Visuals

Mark placement with a caption specific enough that someone else could take the shot: `[Screenshot: project dashboard, red box around the + New Task button]`. Never write as though an image exists when it does not.

- Screenshot every step where the reader must find something on screen
- Annotate — a box or arrow on the target element
- Animated GIF for multi-step flows, under ten seconds
- Video under two minutes, captioned
- Keep zoom and window size consistent across a set

## Accessibility

- Descriptive alt text on every image — what it shows, not "screenshot"
- Heading levels in order, no skipping, no bold text standing in for a heading
- Never rely on color alone: "the red **Delete** button" needs the label too
- Describe the keyboard path where one exists
- Captions and a transcript for video
- Contrast of at least 4.5:1 in any diagram or annotation you produce
