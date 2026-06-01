# Backtest Validation

Use this reference when designing, reviewing, debugging, or reporting backtest results.

## Bias Checks

Check for these failure patterns before trusting performance:

- Lookahead bias: using data not known at the decision time.
- Data leakage: computing features, scalers, thresholds, or labels with future samples.
- Survivorship bias: testing equities or ETFs only on current constituents.
- Corporate action errors: missing split or dividend adjustments.
- Selection bias: choosing instruments, dates, or parameters after seeing results.
- Rebalancing ambiguity: signals and fills occurring on the same timestamp without a clear delay.

## Execution Model

State the assumed execution model explicitly:

- signal timestamp
- order timestamp
- fill price
- fill delay
- partial fills or volume limits
- market, limit, or close/open execution
- transaction fees
- spread and slippage
- borrow costs for shorts
- funding costs for crypto perpetuals

If the implementation fills on the same close used to compute the signal, flag it unless the strategy has a realistic mechanism for knowing and trading that price.

## Validation Design

Prefer validation that can falsify overfit strategies:

- fixed parameters chosen before testing
- train/test split or walk-forward validation
- out-of-sample period with no tuning
- benchmark comparison
- sensitivity analysis around key parameters
- regime checks across bull, bear, high-volatility, and low-volatility periods
- turnover and capacity analysis

## Metrics

Report both return and risk:

- CAGR or annualized return
- annualized volatility
- Sharpe or Sortino ratio, with caveats
- maximum drawdown
- Calmar ratio
- win rate and payoff ratio when trade-level data exists
- exposure and turnover
- average trade duration
- fee and slippage impact
- benchmark-relative return and drawdown

Do not rely on a single metric. If performance disappears after costs, say so directly.

## Review Findings

When reviewing code, order findings by impact:

1. Invalid results due to lookahead, leakage, or broken data alignment.
2. Unrealistic execution, costs, or fills.
3. Missing risk controls or benchmark comparison.
4. Weak reproducibility, tests, or reporting.
5. Maintainability and style issues.

