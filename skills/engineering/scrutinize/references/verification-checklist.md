# Verification Checklist

**Load this when** tracing a code change in Workflow step 4. Walk every changed function through the three passes below, and report each hit as its own finding, even when a bigger finding sits next to it.

## 1. Failure Paths

For each call that can fail (I/O, network, parsing, a third-party SDK), ask "what does the caller see when this fails?"

| Flag | Shape | Why it matters |
|---|---|---|
| **Swallowed error** | `catch (e) {}`, `except: pass`, `_ = err`, a catch that only logs | The failure vanishes: no retry, no alert, and the caller reports success |
| **Broad catch** | Catching the base `Error` / `Exception` around several calls | A bug gets handled like an expected failure |
| **Lost async error** | A promise with no `await` or `.catch`, a fire-and-forget task | The rejection never reaches a handler |
| **Partial write** | Two writes with no transaction, or a side effect followed by the write that records it | A failure between them leaves state half-changed |
| **Leaked detail** | A stack trace or internal ID in a user-facing error | Exposes internals; route to `security-audit` if it is exploitable |

## 2. Boundaries

Feed each input its edge values: `null`/missing, empty string or collection, zero, negative, the maximum, and one past the end.

- `items[0]` or `arr[arr.length - 1]` with no length check
- `total / count` with no zero check
- `if (value)` where `0`, `""`, or `false` is a valid value
- Pagination and slicing bounds: the first page, the last page, and a page past the end
- Money or measurements in floating point, compared with `===`

## 3. Cost at Scale

Ask how the change behaves at 10× and 100× today's data.

- A query or HTTP call inside a loop (N+1): batch it
- A full table or file loaded into memory: paginate or stream it
- A collection or cache that only grows: bound it, give it a TTL, or say why not
- A cache keyed without the user or tenant: one user's data served to another
- Expensive work (regex compile, JSON parse, crypto) repeated in a hot path

---

_Adapted from the `code-review-expert` skill in `sanyuan-skills`, MIT-licensed © 2025 sanyuan0704._
