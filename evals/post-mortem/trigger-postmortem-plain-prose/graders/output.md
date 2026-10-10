---
type: llm
---

Produces a post-mortem with summary, symptom, root cause, fix, how it was found, why it slipped through, validation, and follow-ups. It keeps the identifiers `InvoiceJob.run`, `mark_sent`, `TimeoutError`, PR #2214, and `test_retry_skips_sent_invoices`, and the numbers 412 duplicates and 0 duplicates over 5,000 invoices. It presents no invented detail as given fact: no owner, follow-up item, impact figure, or test beyond what the prompt states, unless labelled as a suggestion or open question. Follow-ups are stated as none agreed or left open. Explaining how the stated mechanism produced the symptom is allowed.
