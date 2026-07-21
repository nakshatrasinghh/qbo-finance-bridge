# Phase 17 — Controlled workforce, tax, and inventory acceptance

## Outcome

Phase 17 validates the four Phase 13 create APIs through the connected QuickBooks Online sandbox. One Employee,
one linked TimeActivity, one Sales TaxCode, and one zero-opening Inventory Item were created through the real
Rails JSON controllers, read back, independently queried, replay-checked, reconciled, and rendered in the
dashboard.

The phase found and corrected one narrow GET defect: Intuit returned the same TaxRate ID twice after the new
TaxCode reused that rate. Rails now collapses identical duplicate IDs and still rejects conflicting duplicates.
No route, request field, response schema, migration, or architectural layer was added.

## Controlled records

| Record | Controlled input | QuickBooks ID | Local operation |
|---|---|---:|---:|
| Employee | Given `Phase17`, family `CFOBridge`, no contact data | `400000001` | `25` |
| TimeActivity | 2026-07-21, 0 hours 15 minutes, linked to Employee `400000001` | `1073741824` | `26` |
| TaxCode | `P17TAX721`, Sales, existing active TaxRate `3` | `4` | `27` |
| Inventory Item | `P17 Inventory 20260721`, SKU `P17-20260721`, quantity 0, cost 0.01, price 0.02 | `19` | `28` |

The TimeActivity description is `Phase 17 controlled sandbox validation`. The Inventory Item description is
`Phase 17 zero-opening controlled sandbox item`. The Item uses current eligible Accounts `79` (sales income),
`80` (COGS), and `81` (inventory asset).

## Submission, readback, and independent GETs

Each initial request used a Rails session CSRF token and a separate connection-scoped UUID `Idempotency-Key`.
The entity submitter reserved its audit operation, queried current references where required, sent one QuickBooks
POST, read the returned entity back, compared the controlled fields, and marked the operation succeeded. Every
initial Rails response was HTTP 201 with `replayed: false`.

Independent collection GETs found exactly one matching record and produced these current counts:

```text
Employees 3 | TimeActivities 6 | TaxCodes 6 | distinct TaxRates 3 | TaxAgencies 2 | Inventory Items 5
```

The operations dashboard rendered all four records, the same counts, the three distinct TaxRate choices, and the
three required inventory Accounts. Its failure alert remained hidden and all four POST controls were enabled.

## Idempotency and audit

The exact four request bodies were submitted again with their original keys. Each returned HTTP 200,
`replayed: true`, its original local operation ID, and its original QuickBooks entity ID. No replay called
QuickBooks or created another audit row.

The local audit ledger now has twelve rows: eleven succeeded and one previously preserved rejected duplicate
Customer attempt. Operations `25`–`28` are succeeded with their exact operation/entity pairings; there are no
pending or uncertain operations.

## TaxRate duplicate correction

After TaxCode `4` reused TaxRate `3`, Intuit's `SELECT * FROM TaxRate` result contained two fully identical records
with ID `3`. The pre-correction API therefore reported four TaxRates even though only IDs `1`, `2`, and `3`
existed.

`Quickbooks::TaxCodes::Query` now indexes normalized records by ID. An identical repeated record is returned once;
the existing safe unexpected-response error is raised if the same ID carries conflicting normalized data. A live
read after the correction returned the three distinct IDs and the dashboard showed one California 8% choice.

## Financial reconciliation

The baseline and final reports used 2026-01-21 through 2026-07-21, Accrual where supported, with Balance Sheet as
of 2026-07-21.

| Report | Baseline rows | Final rows | Result |
|---|---:|---:|---|
| Profit & Loss | 60 | 60 | Full normalized fingerprint unchanged |
| Balance Sheet | 45 | 45 | Full normalized fingerprint unchanged |
| Cash Flow | 22 | 22 | Full normalized fingerprint unchanged |
| Trial Balance | 49 | 49 | Full normalized fingerprint unchanged |
| General Ledger | 460 | 462 | Exactly two new zero-dollar Inventory Starting Value rows |

QuickBooks created transaction `151`, `Inventory Starting Value`, for zero-opening Item `19`. Its two report rows
are dated 2026-07-21, both have amount `.00`, and split between Opening Balance Equity and Inventory Asset. The
displayed account balances remain `596.25` for Inventory Asset and `-9337.50` on the General Ledger's Opening
Balance Equity leg; Trial Balance remained unchanged. Rails preserves these native rows rather than hiding or
recalculating them.

The financial dashboard loaded General Ledger with eight columns and 462 rows, displayed both Phase 17 rows, kept
the error alert hidden, and left the independent Journal Entry form enabled.

## Final non-test verification

```text
four initial create APIs                           HTTP 201 / replayed false / exact readback
four same-key replays                             HTTP 200 / replayed true / original IDs
independent collection GETs                       exact records / counts 3, 6, 6, 3, 2, 5
audit integrity                                   12 total / 11 succeeded / 1 rejected / no unresolved state
operations dashboard                              four rows visible / 3 distinct rates / no alert
five-report reconciliation                        four unchanged / GL +2 exact zero-dollar rows
financial dashboard                               462 GL rows / two Phase 17 rows / no alert
Ruby dependencies                                 bundle check satisfied
database                                          6 migrations up
Rails loading                                     Zeitwerk check passed
dashboard JavaScript                              4 assets passed node syntax checks
OpenAPI                                           3.0.3 / v1.5.1 / 19 paths / 30 operations / 430 resolved refs
Ruby style                                        RuboCop inspected 134 files / no offenses
static security                                   Brakeman 0 errors / 0 warnings
```

Automated tests were not created, modified, or run. Production QuickBooks remains disabled. Nothing was staged
or committed. The temporary local acceptance server was stopped after validation.
