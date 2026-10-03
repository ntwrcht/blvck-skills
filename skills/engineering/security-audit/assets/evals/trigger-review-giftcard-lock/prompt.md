---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Can you security-review our gift card redemption? We added a lock to stop double redemption. We run 4 replicas behind the load balancer. No repo here, code below.

```ts
const locks = new Map<string, Promise<void>>();

export async function redeemGiftCard(userId: string, code: string) {
  while (locks.has(code)) await locks.get(code);
  let release!: () => void;
  locks.set(code, new Promise<void>((r) => (release = r)));
  try {
    const card = await db.giftCards.findOne({ code });
    if (card.redeemedAt) throw new Error('already redeemed');
    await wallet.credit(userId, card.value);
    await db.giftCards.update({ code }, { redeemedAt: new Date() });
  } finally {
    locks.delete(code);
    release();
  }
}
```
