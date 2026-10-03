---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Our controller → OrderService → OrderRepository chain feels pointless; the service just mirrors the repo's methods. How should I restructure it? No repo here, code below.

```ts
class OrderController {
  constructor(private svc: OrderService) {}
  get(id: string) { return this.svc.findById(id); }
  list(userId: string) { return this.svc.findByUser(userId); }
  save(o: Order) { return this.svc.save(o); }
}
class OrderService {
  constructor(private repo: OrderRepository) {}
  findById(id: string) { return this.repo.findById(id); }
  findByUser(u: string) { return this.repo.findByUser(u); }
  save(o: Order) { return this.repo.save(o); }
}
```
