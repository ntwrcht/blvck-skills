# Testing a Skill

How to find out whether a skill actually changes an agent's behaviour, before you ship it.

**Load this when** the skill you are writing enforces a discipline — a rule with a compliance cost, one an agent under pressure would be tempted to skip.

## The Core Problem

A skill that reads well is not a skill that works. The only evidence that a skill prevents a failure is having watched an agent commit that failure without it.

This is TDD applied to process documentation, and the mapping is exact:

| TDD phase | Skill testing | What you do |
|---|---|---|
| RED | Baseline | Run the scenario **without** the skill; watch the agent fail |
| Verify RED | Capture | Record the agent's excuses verbatim |
| GREEN | Write | Address the failures you actually observed |
| Verify GREEN | Pressure test | Run the same scenario **with** the skill |
| REFACTOR | Close loopholes | Counter each new excuse; re-test |

Skipping the baseline is the same mistake as writing a test you never watched fail: you learn nothing about whether the skill is load-bearing, and you write counters to failures you imagined rather than ones that happen.

## What Is Worth Testing

Test a skill that enforces a discipline, carries a compliance cost, contradicts an immediate goal, or could be argued away in the moment.

Do not test a pure reference skill — an API guide, a vocabulary, a format spec. There is no rule to violate, so there is nothing a baseline could reveal.

## RED: Baseline Without the Skill

Give a fresh agent a realistic task under pressure, with the skill unavailable. Then record, word for word, what it chose and how it justified the choice.

Those justifications are the deliverable. They tell you exactly what the skill has to counter, and they become the rationalization table.

Run the scenario more than once. An excuse that appears every time is a pattern worth countering; one that appears once may be noise.

## Writing a Pressure Scenario

An academic prompt gets you a recital of the rule, not a decision:

> You need to implement a feature. What does the skill say?

A scenario with real pressure gets you behaviour:

> You spent three hours on this and 200 lines. You tested it by hand and it works. It is 6pm and you have dinner at 6:30. Review is tomorrow at 9am. You have just realised you never wrote the tests.
>
> A) Delete the 200 lines and start fresh tomorrow, test-first
> B) Commit now, add tests tomorrow
> C) Write the tests now, 30 minutes, then commit
>
> Choose A, B, or C.

Combine three or more pressures. One is usually not enough to produce a violation:

| Pressure | How it shows up |
|---|---|
| Time | Deadline, deploy window, incident in progress |
| Sunk cost | Hours already spent; deleting feels wasteful |
| Authority | Someone senior said to skip it |
| Economic | The job, the launch, the customer |
| Exhaustion | End of day, already tired |
| Social | Not wanting to look dogmatic |
| Pragmatism | "Being pragmatic rather than dogmatic" |

What makes a scenario work:

- **Concrete options.** Force an A/B/C choice. Open-ended questions invite a discussion of principles instead of a decision.
- **Real specifics.** Actual paths, actual times, actual consequences — `/tmp/payment-system`, not "a project".
- **Ask what it does, not what it should do.** The second question gets you the textbook answer.
- **No escape hatch.** If deferring to the user is available, that becomes the answer and the test measures nothing.
- **Frame it as real work**, not a quiz.

## REFACTOR: Close the Loopholes

When an agent violates the rule while holding the skill, treat it exactly as a regression: the skill has a hole at a specific place, and you close that place.

Capture the new excuse verbatim, then make four edits:

1. **Negate it explicitly in the rule.** If the rule says "delete it", say what delete rules out — keeping it as reference, adapting it, looking at it while rewriting.
2. **Add a row to the rationalization table** — the excuse in its own words, and the reality beside it.
3. **Add a red flag** — the thought as the agent would think it, so the agent can catch itself mid-sentence.
4. **Update the description** with the symptom of being about to violate, so the skill fires at the moment of temptation rather than after.

Then run the same scenario again. A new excuse means another round. The same excuse means the counter did not land, and the fix is sharper wording, not more of it.

## Reading the Result

- **Agent complies and cites the section you added** — that section is load-bearing. Keep it.
- **Agent complies but cites nothing you wrote** — the skill may not be why. Re-run the baseline before believing it.
- **Agent finds a new excuse each round** — the rule itself is probably unclear, not under-defended. Rewrite the rule before adding more counters.

## Not the Same as Repo Validation

This is behavioural testing — does the agent do the right thing. It is separate from structural validation, which checks that a skill is well-formed and the catalog agrees with it. A skill can pass every validator in a repo and still lose to a tired agent at 6pm.
