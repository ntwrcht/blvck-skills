---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Security review this endpoint please. Coupons are issued to one user each (`coupon.userId`). No repo here, code below.

```ts
app.post('/coupons/:id/redeem', auth, async (req, res) => {
  const coupon = await db.coupons.findById(req.params.id);
  if (coupon.redeemed) return res.status(409).end();
  await orders.applyCredit(req.user.id, coupon.value);
  await db.coupons.update(coupon.id, { redeemed: true });
  res.json(coupon);
});
```
