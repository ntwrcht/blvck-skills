# Strategy Spec

Use this reference to turn an idea into precise strategy rules before implementation.

## Separate Hypothesis from Mechanics

Write the hypothesis as a falsifiable market behavior claim, not as code:

- Good: "Large-cap equities with 20-day momentum and low recent volatility continue to outperform over the next 5 trading days."
- Weak: "Buy when RSI is low and sell when it goes up."

Then define the mechanics:

- universe and filters
- data frequency and bar timestamp semantics
- feature and indicator formulas
- signal generation time
- order placement time
- entry and exit conditions
- position sizing and rebalancing rules
- risk limits
- cost assumptions
- benchmark and evaluation period

## Minimum Rule Precision

Require enough detail that two engineers would implement the same strategy:

- Indicator lookback windows and exact formulas.
- Whether signals use close, open, high, low, volume, funding, or other data.
- Whether today's close can trigger today's fill or only a future bar.
- Tie-breaking rules when multiple assets qualify.
- Maximum number of positions and per-position exposure.
- Stop-loss, take-profit, time-stop, or trailing-stop rules when present.
- Re-entry rules after an exit.
- Cash handling and unused capital behavior.

## Question Prompts

Ask narrow questions when details are missing:

- "Which bar should execute the order after the signal is known?"
- "Should position size be fixed notional, percent equity, volatility scaled, or risk-per-trade?"
- "What benchmark should this beat: buy-and-hold, equal-weight universe, cash, or another strategy?"
- "Are parameters fixed before the backtest, or selected using a training window?"

