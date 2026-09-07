---
name: technical-trading-strategy
description: "Designs, reviews, and implements rule-based technical trading strategies with disciplined backtesting, validation, risk controls, and Python engineering guidance. Use when working on indicator rules, strategy specs, backtest code, execution assumptions, market data, or live-trading readiness."
---

# Technical Trading Strategy

Guide rule-based technical trading strategy work by separating the market hypothesis, executable rules, implementation model, and evidence needed to trust the result.

## When to Use

Use this skill for rule-based technical strategies, indicator logic, strategy specs, Python backtests, validation reviews, risk controls, market-data assumptions, execution models, and live-readiness assessment across equities, ETFs, crypto spot, crypto perpetuals, and crypto futures.

## When Not to Use

Do not use this skill for options modeling, discretionary trade calls, portfolio allocation, tax advice, or personalized buy/sell recommendations. Options need separate handling for expiries, volatility surfaces, Greeks, exercise, assignment, and liquidity.

For live trading, keep the work to readiness assessment and engineering design unless the user supplies concrete execution requirements and infrastructure details. Do not claim a strategy is safe, profitable, or ready for real capital solely from a backtest.

## Artifacts

- Produces: strategy spec, backtest code
- Consumes: `.context/project.md`, `.context/engineering.md`

## Core Rule

Treat every strategy as untrusted until the rules, data, execution model, costs, risk controls, and validation design are explicit enough to falsify.

## Safety Boundary

Provide research and engineering assistance only. Discuss mechanics, implementation correctness, validation quality, and risk controls. Avoid personalized recommendations, guaranteed-profit language, and claims that backtest performance predicts future returns.

## Core Workflow

1. Classify the request as research, engineering, review, results reporting, or live-readiness.
2. Separate the falsifiable market hypothesis from indicators, rules, code, and evaluation metrics.
3. Check the minimum strategy spec before coding or judging results.
4. Inspect repo code, docs, configs, tests, and data schemas before asking questions when working in an existing project.
5. Challenge invalid or underspecified methodology before presenting results or implementation.
6. Prefer the repo's existing libraries, structure, and test style; suggest new libraries only when they improve correctness, reproducibility, or backtest ergonomics.
7. Make assumptions, code changes, validation evidence, and caveats visible in the final output.

## Minimum Strategy Spec

Before implementing a strategy or trusting a result, confirm or infer:

- market, instrument, or universe
- timeframe and data frequency
- entry rule
- exit rule
- position sizing
- fees, spread, slippage, borrow, or funding assumptions as relevant
- backtest period or data source
- long-only, short-only, or long/short behavior
- benchmark or success criteria

Load `references/strategy-spec.md` when the strategy rules are vague, mixed with implementation details, or need to be written as a reusable spec.

## Validation Checks

Actively check or ask about:

- lookahead bias and data leakage
- survivorship bias for equities and ETFs
- split and dividend adjustments
- fees, spread, slippage, borrow, and funding costs where relevant
- order timing and fill assumptions
- train/test, out-of-sample, or walk-forward separation
- sample size, market regime coverage, and parameter overfitting
- benchmark comparison and risk-adjusted metrics

Load `references/backtest-validation.md` for detailed review criteria, metrics, and failure patterns.

## Reference Map

- `references/strategy-spec.md`: load when turning a vague trading idea into precise, reusable strategy rules.
- `references/backtest-validation.md`: load when designing, reviewing, debugging, or reporting backtest results.
- `references/market-assumptions.md`: load when market, venue, data source, or execution assumptions affect the answer.
- `references/live-trading-readiness.md`: load for deployment, automation, exchange APIs, brokers, or real-capital requests.

## Output Shape

This skill follows a design → review → implement → backtest lifecycle; the shape of the output depends on which stage the request is in.

For strategy design, include:
- hypothesis
- market or instrument universe
- timeframe
- indicators or features
- entry and exit rules
- risk model
- assumptions
- validation plan

For backtest implementation, include:
- code changes
- tests or verification run
- data handling notes
- execution model
- fees and slippage assumptions
- reproducibility notes

For review or debugging, lead with findings ordered by severity, with file and line references when code exists.

For results reports, include metrics, benchmark comparison, drawdown and risk summary, caveats, and next validation steps.

## Next Step

Do not present a strategy as validated until every item in Validation Checks has been examined and the user has seen the assumptions and caveats behind the numbers.

- **If approved:** hand off to `python-engineer` for backtest implementation quality, or to `tdd` when entry and exit rules need regression tests that pin their behavior against known bars. For deployment, automation, or real-capital questions, load `references/live-trading-readiness.md` and keep the work to readiness assessment.
- **If not approved:** revise in place when the gap is a missing spec field or a cost, data, or execution assumption. When the methodology itself is unsound — lookahead, no out-of-sample separation, or parameters tuned until the equity curve improved — say so plainly and return to the Minimum Strategy Spec instead of tuning further.
