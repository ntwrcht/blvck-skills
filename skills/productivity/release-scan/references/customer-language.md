# Writing for the Right Reader

Load this before filling `customer_visible_changes` and `internal_changes`.

The customer bullets are read by a client's IT manager, not by your team. They decide whether to
approve a maintenance window, not how the code works.

## Translate the change, don't restate the commit

- Not: `refactor: replace mgo driver with official mongo-go-driver in repository layer`
- Yes: `Database driver upgraded — improves connection stability under sustained load`

- Not: `fix: nil pointer in agent_handler.go:243`
- Yes: `Fixed an error that could interrupt agent responses during concurrent conversations`

No repo names, file paths, function names, or ticket keys in the customer bullets. Those belong
in `internal_changes` and `issue_keys`, which the PO reads for context but does not forward.

## Internal refactors are not customer bullets

An internal refactor with no observable effect does not belong in the customer bullets at all.
If the customer cannot notice it through the product's own interfaces, it is internal — see the
customer-visible test in `classification.md`.

An empty `customer_visible_changes` list is a valid and common answer. A release that only
restructured code has nothing to tell the customer, and padding it with translated refactors
teaches the customer that the list is noise.

## Don't upgrade a fix into a claim

Do not translate a bug fix into a benefit the diff does not support. "Fixed X" is honest;
"40% more stable" is invented unless something measured it and said so.

The same applies to performance and security wording. `Improved response times` needs a commit,
PR, or benchmark that states it. `Patched a known vulnerability` needs a CVE reference in the
evidence. Without that, describe what changed and let the PO decide what to claim.
