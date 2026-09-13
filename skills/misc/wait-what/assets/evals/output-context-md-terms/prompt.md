---
max_turns: 5
allowed_tools: [Skill, Read, Glob]
---

/wait-what

This was your previous reply:

> The proration bug is in the org-level license recount: when a workspace downgrades mid-cycle, we recompute members against the new tier but the credit note still uses the old per-member rate.

Our `CONTEXT.md`, for reference:

```md
# Billing — Ubiquitous Language

- **Tenant** — a paying organization. Not "customer", "org", or "workspace".
- **Seat** — one licensed user inside a Tenant. Not "license" or "member".
- **Plan** — the pricing tier a Tenant is on. Not "tier" or "package".
```
