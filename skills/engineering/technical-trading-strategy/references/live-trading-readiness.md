# Live Trading Readiness

Use this reference for deployment, automation, exchange APIs, brokers, or real-capital requests. Keep the scope to readiness, safeguards, and engineering design unless the user supplies concrete live-trading requirements.

## Required Gates

Before live deployment, require:

- reproducible backtest with realistic costs and execution assumptions
- paper-trading or shadow-trading period
- capital limit and per-trade risk limit
- maximum daily loss and maximum drawdown stop
- kill switch
- position reconciliation
- order reconciliation
- exchange or broker outage handling
- logs, metrics, and alerts
- secrets management
- compliance and account-permission review

## Operational Failure Modes

Design for:

- duplicate orders
- missed fills
- partial fills
- stale data
- clock skew
- API rate limits
- reconnect loops
- network partition
- exchange maintenance
- bad ticks and invalid candles
- strategy process restart with open positions

## Readiness Output

For live-readiness reviews, return:

- current readiness status
- blockers
- required safeguards
- monitoring and alerting plan
- paper-trading plan
- rollback or shutdown procedure
- residual risks

