# Interface Design for Testability

Good interfaces make behavior easy to test.

## Accept Dependencies

Pass dependencies in instead of constructing them inside the function.

```typescript
// Testable.
function processOrder(order, paymentGateway) {}

// Hard to test.
function processOrder(order) {
  const gateway = new StripeGateway();
}
```

## Return Results

Prefer returned values over hidden side effects.

```typescript
// Testable.
function calculateDiscount(cart): Discount {}

// Hard to test.
function applyDiscount(cart): void {
  cart.total -= discount;
}
```

## Keep the Surface Small

- Fewer methods mean fewer behaviors to cover.
- Fewer parameters mean simpler setup.
- Stable public interfaces let implementation change without rewriting tests.
