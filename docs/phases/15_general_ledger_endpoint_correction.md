# Phase 15 — General Ledger endpoint correction

## Outcome

The existing public API remains:

```text
GET /api/v1/quickbooks/connections/:connection_id/reports/general_ledger
```

Its fixed QuickBooks path changed from `reports/GeneralLedgerDetail` to `reports/GeneralLedger`. The corrected
request returns HTTP 200 and the existing report parser, serializer, dashboard table, and CSV projection work
without modification.

## Why the correction was necessary

Intuit's run-reports inventory names `GeneralLedgerDetail`, while its broader Accounting API resource overview
refers to `GeneralLedger`. Read-only sandbox comparison produced unambiguous local evidence:

| Request | Result |
|---|---|
| `GeneralLedgerDetail` with dates and Accrual basis | Intuit `5020` |
| `GeneralLedgerDetail` with dates only | Intuit `5020` |
| `GeneralLedgerDetail` with no parameters | Intuit `5020` |
| `GeneralLedger` with the dashboard parameters | HTTP 200 and report data |
| `ProfitAndLossDetail` comparison | HTTP 200, disproving a general detail-report restriction |

The application does not convert an upstream failure into a synthetic success. It now calls the path that
actually returns the requested native QuickBooks report; genuine QuickBooks errors still use the existing safe
error envelope.

## Implementation boundary

- Changed one value in the explicit `Quickbooks::Reports::Query::ENDPOINTS` map.
- Kept the public Rails route, controller action, ISO dates, six-month limit, accounting basis, normalized JSON
  schema, dashboard controls, and CSV behavior unchanged.
- Updated OpenAPI from document version 1.5.0 to 1.5.1 and corrected current operator/reference documentation.
- Added no migration, model, controller, service abstraction, dependency, background job, or write path.

## Live acceptance

The corrected entity-specific service returned:

```text
type: general_ledger
title: General Ledger
basis: Accrual
period: 2026-01-21 to 2026-07-21
currency: USD
columns: 8
rows: 452
no_data: false
```

The public Rails endpoint returned HTTP 200, `application/json`, and `Cache-Control: no-store`. Browser
acceptance rendered General Ledger with the same period, basis, eight column headers, and 452 rows. No alert was
visible and the independent Journal Entry submit control remained enabled. Swagger rendered OpenAPI v1.5.1 with
30 operations and no schema error panel.

## Final non-test verification

```text
bundle check                                      dependencies satisfied
bin/rails db:migrate:status                       all six migrations up
bin/rails zeitwerk:check                          all is good
live Quickbooks::Reports::Query                   8 columns / 452 rows / no_data false
live Rails General Ledger GET                     HTTP 200 / JSON / no-store
financial dashboard                              452 rows / no alert / Journal Entry form enabled
node --check financial_records.js                 passed
OpenAPI assertion                                 3.0.3 / v1.5.1 / 19 paths / 30 operations / 430 refs
bundle exec rubocop --cache false                 134 files, no offenses
bundle exec brakeman --no-pager                   0 errors, 0 warnings
```

Automated tests were not created, modified, or run. Phase 15 sent no QuickBooks POST. The audit ledger remained
one previously approved Journal Entry row. Nothing was staged or committed.
