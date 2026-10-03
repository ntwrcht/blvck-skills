---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

We use Clean Architecture. Every use case has its own input port and output port interface, and there's one Postgres gateway behind them all. We're about to add three more use cases — should each one get its own ports too? No repo here, sketch below.

```ts
interface CreateOrderInput { execute(req: CreateOrderRequest): void }
interface CreateOrderOutput { present(res: CreateOrderResponse): void }
interface CancelOrderInput { execute(req: CancelOrderRequest): void }
interface CancelOrderOutput { present(res: CancelOrderResponse): void }
interface GetOrderInput { execute(req: GetOrderRequest): void }
interface GetOrderOutput { present(res: GetOrderResponse): void }

class CreateOrderInteractor implements CreateOrderInput { constructor(private out: CreateOrderOutput, private gw: PostgresOrderGateway) {} /* ... */ }
// CancelOrderInteractor, GetOrderInteractor follow the same shape.
// Each port has exactly one implementation; tests mock the interactors.
```
