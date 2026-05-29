# Refactor Candidates

After the TDD cycle is green, look for:

- Duplication: extract a function, class, or shared fixture.
- Long methods: break into helpers while keeping tests on public behavior.
- Shallow modules: combine pass-through layers or deepen the boundary.
- Feature envy: move logic closer to the data it uses.
- Primitive obsession: introduce value objects when primitives obscure meaning.
- Existing code revealed as problematic by the new behavior.

Run tests after each meaningful refactor step.
