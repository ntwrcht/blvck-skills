---
name: codebase-design
description: "Provides the shared vocabulary for designing deep modules — module, interface, depth, seam, adapter, leverage, locality — and applies it to interface design, deepening a cluster, and seam placement. Use when designing or improving a module's interface, finding deepening opportunities, deciding where a seam goes, making code more testable, or when another skill needs the deep-module vocabulary."
---

# Codebase Design

Design **deep modules**: a lot of behaviour behind a small interface, placed at a clean seam, testable through that interface. The aim is leverage for callers, locality for maintainers, and testability for everyone.

## When to Use

Use this skill when code is being designed or restructured and the shape of an interface is in question: choosing what a module exposes, finding deepening opportunities, deciding where a seam belongs, or making code easier to test through its public surface.

It is also the shared source of this vocabulary for other skills. `tdd` reaches for it when the seam under test is itself the open question; `scrutinize` and `prototype` reach for it when a design is being judged.

## When Not to Use

- **The vocabulary is settled and you just need to write the tests** — stay in `tdd`. This skill is for when the interface's *shape* is the question, not when you are testing an agreed one.
- **The contested thing is a domain term, not a module boundary** — use `domain-modeling`. That skill names concepts; this one shapes the code that carries them.
- **A written design needs findings rather than vocabulary** — use `scrutinize`.

## Artifacts

- Produces: nothing by default. The Design It Twice path produces an interface recommendation for the user to accept; record the outcome as an ADR through `domain-modeling` when it meets the ADR gate.
- Consumes: `CONTEXT.md` (for domain language in interface names), `.context/adr/`

## Glossary

Use these terms exactly. Don't substitute "component", "service", "API", or "boundary" — consistent language is the whole point.

**Module**: anything with an interface and an implementation. Deliberately scale-agnostic — a function, class, package, or tier-spanning slice. _Avoid_: unit, component, service.

**Interface**: everything a caller must know to use the module correctly — the type signature, but also invariants, ordering constraints, error modes, required configuration, and performance characteristics. _Avoid_: API, signature (too narrow; they refer only to the type-level surface).

**Implementation**: what's inside a module, its body of code. Distinct from **adapter**: a thing can be a small adapter with a large implementation (a Postgres repo) or a large adapter with a small implementation (an in-memory fake). Reach for "adapter" when the seam is the topic, "implementation" otherwise.

**Depth**: leverage at the interface. The amount of behaviour a caller (or test) can exercise per unit of interface they have to learn. A module is **deep** when a large amount of behaviour sits behind a small interface, **shallow** when the interface is nearly as complex as the implementation.

**Seam** _(Michael Feathers)_: a place where you can alter behaviour without editing in that place — the *location* at which a module's interface lives. Where to put the seam is its own design decision, distinct from what goes behind it. _Avoid_: boundary (overloaded with DDD's bounded context).

**Adapter**: a concrete thing that satisfies an interface at a seam. Describes *role* (what slot it fills), not substance (what's inside).

**Leverage**: what callers get from depth. More capability per unit of interface they learn. One implementation pays back across N call sites and M tests.

**Locality**: what maintainers get from depth. Change, bugs, knowledge, and verification concentrate in one place rather than spreading across callers. Fix once, fixed everywhere.

## Deep vs Shallow

**Deep module** — small interface, lots of implementation:

```
┌─────────────────────┐
│   Small Interface   │  ← Few methods, simple params
├─────────────────────┤
│                     │
│ Deep Implementation │  ← Complex logic hidden
│                     │
└─────────────────────┘
```

**Shallow module** — large interface, little implementation. Avoid:

```
┌─────────────────────────────────┐
│       Large Interface           │  ← Many methods, complex params
├─────────────────────────────────┤
│  Thin Implementation            │  ← Just passes through
└─────────────────────────────────┘
```

When designing an interface, ask:

- Can I reduce the number of methods?
- Can I simplify the parameters?
- Can I hide more complexity inside?

## Principles

- **Depth is a property of the interface, not the implementation.** A deep module can be internally composed of small, mockable, swappable parts — they just aren't part of the interface. A module can have **internal seams** (private to its implementation, used by its own tests) as well as the **external seam** at its interface.
- **The deletion test.** Imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, it was earning its keep.
- **The interface is the test surface.** Callers and tests cross the same seam. If you want to test *past* the interface, the module is probably the wrong shape.
- **One adapter means a hypothetical seam. Two adapters means a real one.** Don't introduce a seam unless something actually varies across it.

## Designing for Testability

Good interfaces make testing natural.

**Accept dependencies, don't create them:**

```typescript
// Testable
function processOrder(order, paymentGateway) {}

// Hard to test
function processOrder(order) {
  const gateway = new StripeGateway();
}
```

**Return results, don't produce side effects:**

```typescript
// Testable
function calculateDiscount(cart): Discount {}

// Hard to test
function applyDiscount(cart): void {
  cart.total -= discount;
}
```

**Keep the surface small.** Fewer methods mean fewer tests needed; fewer parameters mean simpler test setup. A stable public interface lets the implementation change without rewriting tests.

## Relationships

- A **module** has exactly one **interface** — the surface it presents to callers and tests.
- **Depth** is a property of a **module**, measured against its **interface**.
- A **seam** is where a **module**'s **interface** lives.
- An **adapter** sits at a **seam** and satisfies the **interface**.
- **Depth** produces **leverage** for callers and **locality** for maintainers.

## Rejected Framings

- **Depth as a ratio of implementation lines to interface lines** (Ousterhout) — rewards padding the implementation. Use depth-as-leverage instead.
- **"Interface" as the TypeScript `interface` keyword, or a class's public methods** — too narrow. Interface here includes every fact a caller must know.
- **"Boundary"** — overloaded with DDD's bounded context. Say **seam** or **interface**.

## Reference Map

- `references/deepening.md`: load when deepening a cluster of shallow modules — dependency categories, seam discipline, and replace-don't-layer testing.
- `references/design-it-twice.md`: load when exploring alternative interfaces — parallel sub-agents design the interface several radically different ways, then you compare on depth, locality, and seam placement.

## Next Step

Most of the time this skill is a reference another skill consults mid-task, and it ends when the vocabulary has been applied — no handoff needed. When it has produced an interface recommendation (the Design It Twice path), the user accepting one design is the approval gate.

- **If approved:** hand off to `tdd` to build it, testing at the agreed seam. If the choice was hard to reverse, surprising, and a real trade-off, hand off to `domain-modeling` to record an ADR first.
- **If not approved:** ask which constraint the rejected designs got wrong, then run another Design It Twice round against that constraint — do not proceed to implementation on an interface the user has not accepted.

---

_Adapted from the `codebase-design` skill in `mattpocock-skills`, MIT-licensed © 2026 Matt Pocock._
