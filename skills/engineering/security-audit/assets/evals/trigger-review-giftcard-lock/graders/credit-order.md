---
type: regex
pattern: 'idempoten|(credit|wallet)[^\n]{0,160}(before|ahead of|prior to)[^\n]{0,100}(mark|redeem|update|commit)|(mark|claim)[^\n]{0,80}(first|before)[^\n]{0,80}(credit|wallet)'
flags: i
match: contains
---

Flags that the wallet is credited before the card is marked redeemed, or asks for an idempotency key on the credit.
