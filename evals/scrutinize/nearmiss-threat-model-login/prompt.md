---
max_turns: 2
allowed_tools: [Skill]
---

Threat-model our login endpoint: what could an attacker do with it? It takes email + password, issues a JWT, and has no rate limit yet.
