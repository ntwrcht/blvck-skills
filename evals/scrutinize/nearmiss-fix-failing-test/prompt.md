---
max_turns: 2
allowed_tools: [Skill]
---

This test started failing on CI this morning, can you fix it?

```
FAIL src/cart/total.test.ts
  ● cart total › applies tax after discount
    expect(received).toBe(expected)
    Expected: 107
    Received: 110
      at Object.<anonymous> (src/cart/total.test.ts:22:31)
```
