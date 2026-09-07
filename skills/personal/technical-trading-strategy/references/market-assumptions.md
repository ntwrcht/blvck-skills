# Market Assumptions

Use this reference when assumptions differ by instrument or venue.

## Equities and ETFs

Check:

- trading sessions, holidays, and early closes
- split and dividend adjustments
- survivorship bias in index or universe membership
- delisted securities
- borrow availability and borrow costs for shorts
- opening and closing auction behavior
- liquidity, spread, and volume constraints
- benchmark choice such as SPY, QQQ, sector ETF, or equal-weight universe

Avoid assuming all symbols existed or were tradable for the full backtest period.

## Crypto Spot

Check:

- 24/7 trading and exchange-specific outages
- quote currency and stablecoin assumptions
- maker/taker fees
- spread and liquidity by venue
- withdrawal, deposit, and transfer assumptions if relevant
- missing candles, exchange maintenance, and bad ticks
- survivorship and delisting of tokens

Avoid assuming uninterrupted liquidity across all assets and dates.

## Crypto Perpetuals and Futures

Check:

- funding payments and funding timestamp alignment
- leverage and liquidation risk
- margin mode and collateral currency
- contract specifications
- mark price versus last price
- basis and expiry for dated futures
- exchange risk limits
- liquidation, auto-deleveraging, and insurance fund mechanics where relevant

Backtests without funding, leverage constraints, and liquidation assumptions can materially overstate performance.

