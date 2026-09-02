# Good and Bad Tests

## Good Tests

Good tests verify observable behavior through public interfaces.

```typescript
test("user can checkout with valid cart", async () => {
  const cart = createCart();
  cart.add(product);

  const result = await checkout(cart, paymentMethod);

  expect(result.status).toBe("confirmed");
});
```

Characteristics:

- Tests behavior users or callers care about.
- Uses public API only.
- Survives internal refactors.
- Describes what the system does, not how it does it.
- Keeps one logical behavior per test.

## Bad Tests

Bad tests couple to implementation details.

```typescript
test("checkout calls paymentService.process", async () => {
  const mockPayment = jest.mock(paymentService);

  await checkout(cart, payment);

  expect(mockPayment.process).toHaveBeenCalledWith(cart.total);
});
```

Red flags:

- Mocking internal collaborators.
- Testing private methods.
- Asserting call counts or internal call order.
- Breaking when behavior is unchanged but internals are refactored.
- Naming tests after how the code works.

## Verify Through Interfaces

Prefer verification through the system interface over direct inspection of
external state.

```typescript
// Avoid: bypasses the interface to verify.
test("createUser saves to database", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});

// Prefer: verifies behavior through the interface.
test("createUser makes user retrievable", async () => {
  const user = await createUser({ name: "Alice" });
  const retrieved = await getUser(user.id);
  expect(retrieved.name).toBe("Alice");
});
```
