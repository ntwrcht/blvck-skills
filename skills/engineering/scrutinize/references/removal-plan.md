# Removal Plan

**Load this when** the change leaves code unused (a replaced function, a feature flag fixed on or off, a deprecated endpoint) or the review finds code that a smaller path would delete.

Every removal finding ends in one of two calls. Name it in the finding's suggested change.

## Delete Now

Make this call only when all three hold:

1. A search (`rg`, `grep`) finds no callers outside the code being deleted and its own tests.
2. Nothing reaches it dynamically: no reflection, string-built imports, route tables, config keys, or job names.
3. Nothing outside the repo consumes it: no public API, SDK, webhook, or documented contract.

Then list what goes in the same change (the code, its tests, its config, its docs) and the check that proves the deletion was safe, usually the test suite plus a build.

## Defer With a Plan

When any of the three fails, or the evidence is missing, write the plan in the finding:

| Field | What to write |
|---|---|
| **Why defer** | The failing condition: active consumers, dynamic use, an external contract, or a check you could not run |
| **Precondition** | The observable signal that makes it safe, e.g. "flag off in production for 14 days" or "zero calls in the access log for 30 days" |
| **Steps** | Deprecate, migrate consumers, then delete, each with its own check |
| **Rollback** | How to restore it if the deletion breaks something |

---

_Adapted from the `code-review-expert` skill in `sanyuan-skills`, MIT-licensed © 2025 sanyuan0704._
