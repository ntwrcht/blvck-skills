---
type: llm
---

The deploy waves put identity-service first, billing-api and admin-web after it, and notification-worker after billing-api. The playbook names a rollback decision point with an explicit abort criterion, and states that rollback after the identity-service migration means restoring the database from backup. The version matrix lists all four services with old and new tags, admin-web included, plus one platform-level release number or a placeholder for it.
