---
type: llm
---

Produces the customer release document in the reply. It groups the changes into themes by capability (for example sign-in or billing), not one section per service. The Impact section opens with the breaking change: the password grant removed from POST /oauth/token, with client_credentials as the replacement. It states that rolling back after the identity-service migration means restoring the database from backup, not redeploying the old tag. Deploy waves put identity-service first, billing-api and admin-web after it, and notification-worker after billing-api. Customer Actions is its own section listing at least the SAML_SP_ENTITY_ID or INVOICE_EXPORT_BUCKET value and the *.webhook.office.com allowlist, each with a by-when.
