# Phase 16 — Controlled sales and payables lifecycle

## Outcome

Phase 16 live-validates the six Phase 14 create APIs as one connected QuickBooks sandbox workflow. No public
route, payload field, response schema, migration, or service abstraction was added.

## Approved sandbox records

| Record | Controlled input | QuickBooks ID | Local operation |
|---|---|---:|---:|
| Customer | `CFO Bridge Phase 16 Customer 2026-07-21` | `58` | `4` |
| Vendor | `CFO Bridge Phase 16 Vendor 2026-07-21` | `59` | `5` |
| Invoice | $2.00, Service Item `1`, 2026-07-21, due 2026-07-31 | `147` (`1038`) | `6` |
| Customer Payment | $2.00 applied only to Invoice `147` | `148` | `7` |
| Bill | $1.00, Office Expenses `15`, A/P `33`, 2026-07-21, due 2026-07-31 | `149` | `8` |
| BillPayment | $1.00 check from Checking `35`, applied only to Bill `149` | `150` | `9` |

The Invoice description is `Phase 16 controlled sandbox service sale`. The Bill description is
`Phase 16 controlled sandbox office expense`. Service Item `1` was chosen so this validation did not change
inventory quantity.

## Submission and readback

Each request went through the real Rails controller with a session CSRF token and its own UUID
`Idempotency-Key`. The entity-specific submitter reserved its connection-scoped operation, reloaded current
QuickBooks references, made one POST, read the returned entity by ID, compared the intended fields, then marked
the operation succeeded. Every initial response was HTTP 201 with `replayed: false`.

Independent entity reads after both payments confirmed Invoice `147` and Bill `149` each have current balance
`0.0`. The sales/payables dashboard rendered all six new records and these total counts:

```text
Customers 30 | Vendors 27 | Invoices 32 | Bills 16 | Payments 17 | BillPayments 11
```

Neither Invoice `147` nor Bill `149` remains in an open-source payment selector.

## Idempotency acceptance

The exact same six request bodies and UUID keys were submitted again. Each API returned HTTP 200 with
`replayed: true`, its original operation ID, and its original QuickBooks entity ID. The audit count stayed at
seven total rows: the previously approved Journal Entry plus six Phase 16 operations. No replay called a creator
or sent another QuickBooks write.

Replay returns the immutable creation-time result. Invoice/Bill replay therefore retains the balance observed
immediately after creation; their current zero balances come from the independent entity GETs after payment.

## Duplicate-submission guard evidence

During later browser cleanup, a stale Customer confirmation submitted the same Phase 16 Customer fields with a
new UUID. Rails reserved local operation `24`, queried current Customers, detected that active Customer `58`
already owned the display name, and returned HTTP 422 with `quickbooks_customer_input_invalid`. The request log
contains the QuickBooks query and no Customer POST. The rejected row is intentionally preserved as audit evidence;
the current ledger therefore has eight rows total: seven succeeded and one rejected. Customer count remained 30,
and no financial report value changed.

## Financial reconciliation

All reports use Accrual basis and the period 2026-01-21 through 2026-07-21, except Balance Sheet which is as of
2026-07-21.

| Report value | Baseline | Final | Expected delta | Result |
|---|---:|---:|---:|---|
| Services | 503.55 | 505.55 | +2.00 | Matched |
| Total Income | 10200.77 | 10202.77 | +2.00 | Matched |
| Office Expenses | 19.08 | 20.08 | +1.00 | Matched |
| Total Expenses | 5237.31 | 5238.31 | +1.00 | Matched |
| Net Income | 1642.46 | 1643.46 | +1.00 | Matched |
| Checking | 1201.00 | 1200.00 | −1.00 | Matched |
| Accounts Receivable | 5281.52 | 5281.52 | 0.00 | Matched |
| Undeposited Funds | 2062.52 | 2064.52 | +2.00 | Matched |
| Accounts Payable | 1602.67 | 1602.67 | 0.00 | Matched |

Trial Balance returned those same final account balances. General Ledger increased from 452 to 460 normalized
rows and showed exactly eight native accounting legs:

1. Invoice: debit A/R $2 and credit Services $2.
2. Customer Payment: debit Undeposited Funds $2 and credit A/R $2.
3. Bill: debit Office Expenses $1 and credit A/P $1.
4. BillPayment: debit A/P $1 and credit Checking $1.

The dashboard rendered the reconciled P&L values and all eight General Ledger rows with no alert.

## Final non-test verification

```text
six initial create APIs                           HTTP 201 / replayed false / verified readback
six same-key replays                             HTTP 200 / replayed true / original IDs
independent Invoice and Bill reads               both current balance 0.0
audit integrity                                  8 total / 7 succeeded / operation 24 rejected pre-POST
sales/payables dashboard                         counts matched / six rows visible / no alert
P&L, Balance Sheet, Trial Balance                all predicted deltas matched
General Ledger                                   8 exact lifecycle legs / 460 total rows
bundle check                                     dependencies satisfied
bin/rails db:migrate:status                      all six migrations up
bin/rails zeitwerk:check                         all is good
node --check                                     four JavaScript assets passed
OpenAPI assertion                                3.0.3 / v1.5.1 / 19 paths / 30 operations / 430 refs
bundle exec rubocop --cache false                134 files / no offenses
bundle exec brakeman --no-pager                  0 errors / 0 warnings
```

Automated tests were not created, modified, or run. Production QuickBooks remains disabled. Nothing was staged
or committed. The temporary local acceptance server was stopped after validation.
