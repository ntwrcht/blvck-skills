---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Quick review of this before I merge? `src/pricing/legacy.ts` still exports `legacyDiscount`; grep shows its only other reference is `src/pricing/legacy.test.ts`. No repo here, diff below.

```diff
--- a/src/pricing/discount.ts
+++ b/src/pricing/discount.ts
@@ -1,5 +1,5 @@
-import { legacyDiscount } from './legacy';
+import { tieredDiscount } from './tiered';

 export function priceFor(cart: Cart): number {
-  return cart.subtotal - legacyDiscount(cart);
+  return cart.subtotal - tieredDiscount(cart);
 }
```
