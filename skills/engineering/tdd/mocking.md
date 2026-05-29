# When to Mock

Mock at system boundaries only:

- External APIs such as payment, email, and third-party services.
- Databases when a test database is impractical.
- Time and randomness.
- File systems when real files would make the test slow, flaky, or unsafe.

Do not mock:

- Your own modules.
- Internal collaborators.
- Code you control.

## Designing for Mockability

Accept dependencies instead of creating them internally.

```typescript
// Testable.
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to test.
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

Prefer SDK-style boundary interfaces over generic fetchers.

```typescript
// Good: each operation has a specific mock shape.
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch("/orders", { method: "POST", body: data }),
};

// Avoid: mock setup needs endpoint conditionals.
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```
