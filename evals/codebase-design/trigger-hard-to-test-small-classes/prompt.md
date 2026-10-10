---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

This invoicing module is hard to test and split across too many small classes — InvoiceBuilder, LineItemFormatter, TaxApplier, InvoiceNumberer, InvoicePersister, each with one method, each mocked in every test. Where should the seam go?
