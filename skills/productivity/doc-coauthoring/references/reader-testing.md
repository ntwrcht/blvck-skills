# Stage 3 — Reader Testing

Goal: find the blind spots — what is obvious to the authors and opaque to everyone else — before real readers hit them.

The test only works with a reader that has none of this conversation's context. Never test with context from the drafting session bleeding in.

## 1. Predict Reader Questions

Generate 5-10 questions real readers would ask of this document: what they need to decide, what they will be skeptical of, what they would type into an agent after being handed the doc. Show the list to the user and let them add their own.

## 2. Test With Subagents

Dispatch one subagent per question. Give each subagent only the document content and its single question — no conversation history, no background.

Prompt template:

```
You are reading this document for the first time. You have no other context.

<document>
{full document text}
</document>

Question: {question}

Answer in three parts:
1. Your answer, based only on the document.
2. Anything ambiguous or unclear that made answering harder.
3. Knowledge the document assumes you already have.
```

Report per question what the reader got right, got wrong, or could not find. A wrong answer is a document defect, not a reader defect.

## 3. Additional Checks

Dispatch one more subagent over the whole document to check for ambiguity, unstated assumptions, and internal contradictions. Summarize what it found.

## 4. Fix and Re-test

List the specific gaps, then loop back to the Stage 2 section loop for the sections that caused them. Re-run the failing questions after fixing — a fix that was never re-tested is a guess.

## No-Subagent Fallback

Where subagents are unavailable, the user runs the test. Give them the exact steps:

1. Open a fresh agent conversation with no history.
2. Paste the document, or share it if connectors give the agent access.
3. Ask the predicted questions one at a time, requesting the same three-part answer above.
4. Also ask: what is ambiguous here, what knowledge does this assume, and are there internal contradictions?

Ask what the reader got wrong, then fix those sections.

## Exit Condition

Testing is done when the reader answers the predicted questions correctly and stops surfacing new gaps. Then hand ownership back: the user does a final read, verifies facts, links, and technical details, and confirms the doc achieves the impact they wanted.

## Closing Tips

Offer these once, at the end:

- Appendices carry depth without bloating the main document.
- Linking the drafting conversation in an appendix lets readers see how the decisions were reached.
- Update the doc as real readers give feedback — the first version is a draft with a wider audience.
