---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Can you look over this diff before I merge? No repo here, so it's pasted below.

```diff
--- a/src/wallet/withdraw.ts
+++ b/src/wallet/withdraw.ts
@@ -0,0 +1,16 @@
+import { db } from '../db';
+import { payouts } from '../payouts';
+import { mailer } from '../mailer';
+
+export async function withdraw(userId: string, amount: number) {
+  const account = await db.accounts.findOne({ userId });
+  if (account.balance >= amount) {
+    await payouts.send(userId, amount);
+    await db.accounts.update({ userId }, { balance: account.balance - amount });
+    await notifyWithdrawal(userId);
+  }
+}
+
+async function notifyWithdrawal(userId: string) {
+  try { await mailer.send(userId, 'withdrawal'); } catch (e) {}
+}
```
