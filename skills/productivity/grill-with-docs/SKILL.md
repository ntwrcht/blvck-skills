---
name: grill-with-docs
description: "User entry point for a grilling session that builds living documentation as decisions crystallize. Use when the user wants to stress-test a plan and simultaneously capture domain vocabulary and architectural decisions."
disable-model-invocation: true
argument-hint: "<plan or topic to stress-test>"
---

# Grill With Docs

Run a `grilling` session, using the `domain-modeling` skill to capture terms and record decisions as they resolve.

## What You Get

- A grilled plan with resolved decisions (from `grilling`)
- Updated domain glossary in `CONTEXT.md` (from `domain-modeling`)
- ADRs for hard, surprising, real-tradeoff decisions (from `domain-modeling`)

## When to Use

Use when the user wants both: an interview to sharpen and stress-test a plan, and living documentation of the domain decisions made during that session.

Use `grill-me` when the interview outcome matters but documentation is not the goal.

## Next Step

See `grilling`'s and `domain-modeling`'s Next Step sections — this skill has no independent routing of its own.
