# Developer Tutorials, CLI Docs, and Integration Guides

The reader is technical but new to *this* thing. They will copy every code block, so every code block must run.

## Tutorial vs reference

A tutorial teaches by building something; it is read once, in order. A reference answers a lookup; it is read a hundred times, never in order. Mixing them produces a document that fails at both — a reference interrupted by narrative, or a tutorial no one can follow because it keeps listing options.

If you catch yourself writing "you can also…" in a tutorial, that sentence belongs in the reference.

## Developer tutorial

````markdown
# Build a <thing> with <product>

## What you will build
<One paragraph, and ideally a screenshot or sample output of the finished result.>

## What you need
- <language/runtime and version>
- <account or API key, and how to get one>
- Familiarity with <assumed knowledge, stated honestly>

## 1. Set up the project
<Commands from empty directory to running skeleton. Under five minutes.>

### Checkpoint
```bash
curl http://localhost:3000/health
```
Expect `{"status":"ok"}`. If you see a connection error, the server did not
start — check the terminal running `npm run dev`.

## 2. <First real capability>
<Explain why this step exists before showing how. Then the code.>

## 3. <Builds on step 2>
...

## Test it
<How the reader proves the whole thing works.>

## What you learned
<Three or four bullets naming the concepts, so the reader can search for more.>

## Next steps
- <Natural extension>
- <Link to the reference docs>
````

**Progression rules**

- Each step depends only on steps before it. A tutorial the reader cannot pause is broken.
- Working state after every step. Never leave the reader with code that does not run "until step 6".
- Explain *why* before *how*. Code with no rationale is a snippet, not a tutorial.
- Complete code blocks: imports, dependencies, config included. Fragments cost the reader a debugging session.
- Language tag on every fence, so syntax highlighting works.
- Checkpoints roughly every two or three steps — a command the reader runs and a result they compare against. This is what separates a tutorial that gets finished from one that gets abandoned.

## CLI documentation

````markdown
# <tool>

<One sentence.>

## Install
<Each supported method: package manager, binary, source.>

## Usage
```
tool <command> [options]
```

## Commands

### `tool init [directory]`
Creates a config file in the target directory.

**Arguments**
- `directory` — where to write the config. Defaults to the current directory.

**Options**
- `--force` — overwrite an existing config
- `--template <name>` — start from a named template

**Examples**
```bash
tool init
tool init ./services/api --template minimal
```

**Exit codes**
| Code | Meaning |
| :--- | :--- |
| 0 | Success |
| 1 | Config already exists (use `--force`) |
| 2 | Invalid template name |

## Configuration
<Config file location and format, then the precedence order:
flags override environment variables override the config file.>

## Environment variables
| Variable | Purpose | Default |
| :--- | :--- | :--- |

## Common workflows
<Two or three real end-to-end sequences.>

## Errors
| Message | Cause | Fix |
| :--- | :--- | :--- |
````

Document every public flag, including the boring ones. State the precedence order explicitly — it is the most common source of confusion and the most commonly omitted section. Order commands alphabetically for lookup, but put the common workflows section above them for the first-time reader.

## API integration guide

This is the narrative companion to an OpenAPI spec, not a replacement for it. The spec enumerates; the guide teaches the path through.

```markdown
1. Overview — what the API is for, and what it is not
2. Authentication — obtaining a credential, sending it, refresh and expiry
3. Your first request — one curl command that returns real data
4. Core workflows — the two or three sequences most integrations need,
   with full request and response bodies
5. Errors — the format, the codes that matter, and what to do about each
6. Rate limits — the limits, the headers, and the backoff you expect
7. Pagination — the contract, with a loop example
8. Webhooks — events, payloads, signature verification, retry behavior
9. Reference — link to the OpenAPI spec
```

Give examples in curl plus one or two languages the audience actually uses. Show the response body, not just the request — a reader cannot write a parser against a request.

## Code quality

- Every snippet runs as written. Test it; do not reason about whether it should work.
- No placeholders where a real value is knowable. `YOUR_API_KEY` is fine; `<your-endpoint>` where the endpoint is documented on the same page is not.
- Show the output. A command with no expected output gives the reader nothing to check against.
- Real values in examples — a task titled "Draft Q4 blog post", not "string".
- Follow the language's conventions. Readers copy the style along with the code.
- Version-pin what you install, and say which version the tutorial was written against.

## Common failures

| Failure | Fix |
| :--- | :--- |
| Theory before the first working result | Move setup to step 1, theory to "what you learned" |
| Untested code | Run every block before publishing |
| Unstated prerequisites | List them, including assumed knowledge |
| No verification | Add a checkpoint with an expected result |
| Fragments without imports | Show complete, runnable code |
| A tutorial that drifts into reference | Split it |
| No date or version | Both, at the top |
