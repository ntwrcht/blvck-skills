# Feedback Loops

Treat the loop as the main product of diagnosis. A sharp loop makes bisection, hypotheses, and instrumentation useful; a vague loop wastes every later phase.

## Construction Options

Try these in roughly this order:

1. **Failing test.** Use whatever seam reaches the bug: unit, integration, contract, component, or e2e.
2. **Curl or HTTP script.** Drive a running dev server or service with the smallest request that reproduces the symptom.
3. **CLI invocation.** Feed a fixture input to the command and diff stdout, stderr, exit code, or generated files against a known-good snapshot.
4. **Headless browser script.** Use Playwright or Puppeteer to drive the UI and assert on DOM, console, network, screenshots, or timing.
5. **Trace replay.** Save a real network request, payload, event log, queue message, or job input, then replay it through the path in isolation.
6. **Throwaway harness.** Start the minimal service subset or call the smallest function boundary with mocked dependencies that still exercises the real path.
7. **Property or fuzz loop.** For intermittent wrong output, run many generated inputs and stop on the failure signature.
8. **Bisection harness.** When the bug appeared between two known commits, datasets, versions, or configs, automate the check so `git bisect run` or an equivalent state bisector can drive it.
9. **Differential loop.** Run the same input through old vs new code, two configs, or two environments and diff the outputs.
10. **Human-in-the-loop script.** Last resort. Copy `scripts/hitl-loop.template.sh`, replace the prompts, and use the captured output as structured evidence.

## Loop Quality

Once a loop exists, improve it before leaning on it:

- Make it faster by caching setup, narrowing scope, skipping unrelated init, or prebuilding fixtures.
- Make it sharper by asserting the exact symptom rather than a broad crash or generic failure.
- Make it more deterministic by pinning time, seeding randomness, isolating filesystem state, freezing network calls, or controlling concurrency.

A 30-second flaky loop is only a starting point. A 2-second deterministic loop is a diagnostic tool.

## Nondeterministic Bugs

The first goal is a higher reproduction rate, not a perfect repro. Loop the trigger many times, parallelise, add stress, narrow timing windows, inject sleeps, pin or vary scheduling, and capture enough context to distinguish failure from noise.

If the bug reproduces 1 percent of the time, keep raising the rate. If it reproduces around 50 percent of the time, it is usually debuggable.

## When No Loop Is Possible

Stop and say so explicitly. List what you tried and ask for one of these:

- Access to the environment that reproduces the bug.
- A captured artifact such as HAR, logs, core dump, event payload, queue message, database fixture, trace, or timestamped screen recording.
- Permission to add temporary production instrumentation.

Do not proceed to root-cause speculation without a credible loop or a concrete missing-loop blocker.
