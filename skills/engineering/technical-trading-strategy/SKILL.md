---
name: technical-trading-strategy
description: Technical trading strategy research and engineering guidance for rule design, Python backtesting, validation, risk controls, and implementation review.
---

# Technical Trading Strategy

Guide technical trading strategy work with a strict separation between the trading hypothesis, the backtest or implementation design, and the evidence needed to trust the result.

## When to Use

Use this skill for requests involving rule-based technical strategies, indicator logic, Python backtests, backtest review, strategy research workflows, risk controls, or technical trading implementation for:

- equities and ETFs
- crypto spot
- crypto perpetuals and futures

This skill supports two modes:

- **Research / trader mode**: clarify hypothesis, market assumptions, indicators, entry and exit rules, risk model, and validation plan.
- **Engineering mode**: implement or review Python backtests, data handling, execution assumptions, tests, reproducibility, and code quality.

Prefer the existing codebase's libraries, structure, and testing style when working in a repo. When starting fresh, suggest libraries only when they improve correctness, reproducibility, or backtest ergonomics.

## When Not to Use

Do not use this skill for options strategy modeling, discretionary trade calls, portfolio advice, tax advice, or personalized buy/sell recommendations. Options need separate modeling for expiries, volatility surfaces, Greeks, exercise and assignment, and liquidity.

For live trading requests, keep the work to readiness assessment and engineering design unless the user explicitly supplies live-execution requirements and infrastructure details. Do not claim a strategy is safe or profitable for live deployment.

## Safety Boundary

Provide engineering and research assistance only. Discuss strategy mechanics, implementation correctness, validation quality, and risk controls. Avoid personalized recommendations, guaranteed-profit language, and claims that backtest performance predicts future returns.

For live execution, require discussion of paper trading, kill switches, capital limits, monitoring, logging, operational failure modes, and compliance constraints. Load `references/live-trading-readiness.md` when the request involves deployment, automation, exchange APIs, brokers, or real capital.

## Core Workflow

1. Classify the request as research / trader mode, engineering mode, or both.
2. Separate the trading hypothesis from implementation details.
3. Check whether the minimum strategy spec is complete before coding.
4. Inspect repo code, docs, configs, tests, and data schemas before asking questions when working in an existing project.
5. Challenge invalid or underspecified methodology before presenting results.
6. Use task-specific output formats so assumptions, code changes, evidence, and caveats are visible.

## Minimum Strategy Spec

Before implementing a backtest or strategy, confirm or infer these items. If any are missing and risky to assume, ask focused questions before coding.

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

## Validation Standard

Be strict by default. Actively check or ask about:

- lookahead bias and data leakage
- survivorship bias for equities and ETFs
- split and dividend adjustments
- fees, spread, slippage, borrow, and funding costs where relevant
- order timing and fill assumptions
- train/test, out-of-sample, or walk-forward separation
- sample size, market regime coverage, and parameter overfitting
- benchmark comparison and risk-adjusted metrics

Load `references/backtest-validation.md` for detailed review criteria, metrics, and failure patterns.

## Market Assumptions

Do not reuse assumptions across markets without checking them. Equities, ETFs, crypto spot, and crypto perpetuals/futures differ in sessions, leverage, funding, liquidity, corporate actions, and data quality.

Load `references/market-assumptions.md` when the market, venue, data source, or execution model affects the answer.

## Output Formats

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

