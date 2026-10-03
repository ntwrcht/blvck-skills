# Framework Mapping

How to work with a user or codebase that already speaks a named architecture style. Load this only when one is in play — the user asks for "the Clean Architecture way", or the code is visibly organised as layers, rings, or ports.

The vocabulary in [SKILL.md](SKILL.md) stays in charge: **module**, **interface**, **seam**, **adapter**, **depth**. Translate the style's terms into it, design in it, and run its tests (the deletion test, one-adapter-means-hypothetical) against what the style would produce. Never switch to designing in the style's own terms. Where a style and this skill disagree, say so and let the tests decide.

## Hexagonal (Ports & Adapters)

| Style term | Our term |
|---|---|
| port | interface at a seam |
| adapter | adapter |
| application core | deep module |

**Where our tests push back:** little — this is dependency category 3 in [deepening.md](deepening.md). The one trap is a port with a single production adapter and no test adapter; that is a hypothetical seam.

## Clean Architecture

| Style term | Our term |
|---|---|
| use case / interactor | module |
| boundary | seam |
| gateway | adapter |
| entity | module (usually in-process) |

**Where our tests push back:** an input and output interface per use case usually means one adapter each, so the seams are hypothetical. Merge use cases that share a caller and a dependency set until each interface earns its adapters.

## Onion

| Style term | Our term |
|---|---|
| ring | a layer of modules |
| domain core | deep module |
| infrastructure ring | adapters |

**Where our tests push back:** a ring whose modules only forward calls inward fails the deletion test. Keep the dependency direction; drop the rings that add no behaviour.

## Layered (n-tier)

| Style term | Our term |
|---|---|
| layer | module |
| service | module — often shallow |
| DAO / repository | adapter |

**Where our tests push back:** a `controller → service → repository` chain where each layer mirrors the next one's methods is the textbook shallow module. Apply the deletion test layer by layer and collapse the pass-throughs.

## DDD — Tactical Patterns

| Style term | Our term |
|---|---|
| aggregate | module |
| repository | adapter at a seam |
| domain service | module |
| value object | in-process module |

**Where our tests push back:** a repository per aggregate is a real seam only when a test adapter exists beside the production one. An aggregate exposing its internal entities to callers has leaked its implementation into its interface.

Strategic DDD — bounded contexts and context maps — is not covered here; that is `domain-modeling`'s ground.

## Vertical Slice

| Style term | Our term |
|---|---|
| slice / feature | tier-spanning module |
| handler | the slice's interface |

**Where our tests push back:** mostly agrees — a slice is a deep module by design. Watch for shared helpers between slices that grow into a shallow layer of their own.
