# Deep Modules

From "A Philosophy of Software Design":

- Deep module: small interface, substantial implementation hidden behind it.
- Shallow module: broad interface, thin implementation that mostly passes work
  through.

Prefer deep modules when designing for TDD. They reduce the public behavior
surface while keeping complexity local.

Ask:

- Can the number of methods be reduced?
- Can parameters be simplified?
- Can more complexity be hidden behind the interface?
- Can tests describe fewer, more meaningful behaviors?
