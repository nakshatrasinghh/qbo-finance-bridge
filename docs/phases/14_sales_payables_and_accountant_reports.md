# Phase 14 — Sales, payables, and accountant reports

## Outcome

Phase 14 adds fourteen explicit connection-scoped Rails JSON operations:

```text
GET/POST /api/v1/quickbooks/connections/:connection_id/customers
GET/POST /api/v1/quickbooks/connections/:connection_id/vendors
GET/POST /api/v1/quickbooks/connections/:connection_id/invoices
GET/POST /api/v1/quickbooks/connections/:connection_id/bills
GET/POST /api/v1/quickbooks/connections/:connection_id/customer_payments
GET/POST /api/v1/quickbooks/connections/:connection_id/bill_payments
GET      /api/v1/quickbooks/connections/:connection_id/reports/general_ledger
GET      /api/v1/quickbooks/connections/:connection_id/reports/trial_balance
```

Together with the fifteen earlier operations, the public CFO API surface is exactly twenty-nine operations plus
`GET /health`. The new HTML shell is
`GET /quickbooks/connections/:connection_id/transactions`; ERB performs no QuickBooks exchange while rendering.

## Supported boundary

Official Intuit documentation was reviewed before implementation and is recorded in `docs/reference_review.md`
and `docs/references.md`. Customer and Vendor are non-posting list records. Invoice and Bill are restricted to
one accounting line. Customer Payment applies one amount to one open Invoice. BillPayment uses check pay type,
one current bank Account, and one open Bill. The dashboard does not expose arbitrary QuickBooks payloads.

Trial Balance and General Ledger are transient, read-only QuickBooks reports. Rails preserves the existing
normalized report shape and never persists or recalculates report values. Trial Balance returned data in the
connected sandbox. The official `GeneralLedgerDetail` endpoint returned Intuit code `5020` Permission Denied for
this sandbox/role; Rails returns a normalized 422 failure and the dashboard presents it without breaking the
independent Journal Entry form.

Phase 15 supersedes only that endpoint conclusion: a read-only comparison found that this sandbox returns the
same General Ledger report at `reports/GeneralLedger`. The Rails API now uses that path and returns HTTP 200.

## Implementation

- Six explicit controllers permit only fixed entity input and delegate all vendor/accounting behavior.
- Each entity namespace owns its `Query`, `Create`, `Details`, `Serializer`, and `Submit` classes.
- Invoice validates one active Customer and eligible sales Item; Bill validates one active Vendor, expense
  Account, and Accounts Payable Account.
- Both payment creators reload the source transaction and cap the decimal amount at its current open balance.
- Every creator makes one QuickBooks POST, reads the returned ID back, and verifies the intended record before
  reporting success.
- `Quickbooks::CreateSubmission` remains limited to connection-scoped UUID reservation, canonical digest
  matching, safe replay/refusal, and succeeded/rejected/uncertain state. It has no entity fields or payload rules.
- Migration `20260721150000` expands the fixed database pairing constraint to exactly eleven allowed
  operation/entity pairs. No external HTTP call occurs inside a database transaction.
- Existing report parameters/query/parser classes are extended with two fixed report keys and vendor paths.
- OpenAPI 3.0.3 document version 1.5.0 documents all request, success, replay, validation, and error shapes.

No generic CRUD endpoint, service base class, repository, Rails Engine, background job, frontend framework, or
second process was added.

## Dashboard acceptance

The sales/payables dashboard starts six GETs independently, renders six tables, and fills only the selectors
required by each corresponding create. Every POST requires browser confirmation, Rails CSRF, and a UUID
`Idempotency-Key`. An uncertain key is retained, successful submission refreshes only its relevant source, and a
safe failure appears in the common dismissible alert.

Browser validation rendered:

| Source | Rows |
|---|---:|
| Customers | 29 |
| Vendors | 26 |
| Invoices | 31 |
| Bills | 15 |
| Customer Payments | 16 |
| BillPayments | 10 |

All six forms were enabled only after their live prerequisites loaded. The alert remained hidden on success.
The financial dashboard rendered five report choices, loaded Trial Balance with 49 rows, and displayed a visible
safe error for General Ledger while leaving Journal Entry submission enabled.

Phase 15 later replaced that historical error result with a successful General Ledger dashboard render.

## Write-safety acceptance

Phase 14 deliberately sent no valid Customer, Vendor, Invoice, Bill, Payment, or BillPayment POST to QuickBooks.
The existing audit ledger remained exactly one row, the accepted `journal_entry_create` operation. The six write
paths are implemented, documented, idempotent, audited, and readback-gated, but are not claimed as live-write
validated. A first real sandbox record requires explicit approval and exact input/reference choices.

## Final non-test verification

```text
bundle check                                      dependencies satisfied
bin/rails db:migrate:status                       all six migrations up
bin/rails routes -g quickbooks                    29 CFO API operations + HTML/OAuth routes present
bin/rails zeitwerk:check                          all is good
live Phase 14 Rails GETs                          HTTP 200/no-store except handled General Ledger 422/5020
node --check                                      four JavaScript assets passed
OpenAPI assertion                                 3.0.3 / v1.5.0 / 19 paths / 30 operations / 430 refs
bundle exec rubocop --cache false                 134 files, no offenses
bundle exec brakeman --no-pager                   0 errors, 0 warnings
```

Automated tests were not created, modified, or run. Production QuickBooks remains disabled. Nothing was staged
or committed. The temporary local acceptance server was stopped after validation.
