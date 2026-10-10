---
max_turns: 10
allowed_tools: [Skill, Read, Glob, Grep]
---

Bug's fixed and verified, write up the RCA in your reply.

- Symptom: nightly invoice job emailed some customers twice on 2026-10-02. 412 duplicate emails, logged in `mailer.sent` with the same `invoice_id`.
- Root cause: `InvoiceJob.run` retries the whole batch when the SMTP client raises `TimeoutError`, but `mark_sent(invoice_id)` is only called after the full batch finishes. A timeout on email 300 re-sent emails 1 to 299.
- Fix: PR #2214 calls `mark_sent` per invoice right after each send and skips invoices already marked sent on retry.
- Found by: grouping `mailer.sent` by `invoice_id`; every duplicate pair sat on either side of a `TimeoutError` in the job log.
- Slipped through: the integration test uses a fake SMTP client that never times out.
- Validation: added `test_retry_skips_sent_invoices`; replayed the 2026-10-02 batch in staging with injected timeouts at 1% of sends, 0 duplicates over 5,000 invoices.
- Follow-up: none agreed yet.
