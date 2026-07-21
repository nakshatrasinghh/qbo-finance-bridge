# Phase 12 — Read-only core CFO financial statements

## Outcome

Phase 12 adds three explicit read-only Rails JSON APIs and dashboard views for QuickBooks-generated Profit &
Loss, Balance Sheet, and Cash Flow statements. QuickBooks remains the accounting system and report calculator;
Rails validates the requested filters, calls a fixed report endpoint, normalizes the returned hierarchy, and
renders or exports the result without persisting report values.

No QuickBooks `POST`, local financial write, audit write, migration, table, cache, or background job was added or
executed. Automated tests were not created, modified, or run.

## Accepted API surface

The CFO API surface is now exactly seven operations:

```text
GET  /api/v1/quickbooks/connections/:connection_id/accounts
GET  /api/v1/quickbooks/connections/:connection_id/reports/profit_and_loss
GET  /api/v1/quickbooks/connections/:connection_id/reports/balance_sheet
GET  /api/v1/quickbooks/connections/:connection_id/reports/cash_flow
GET  /api/v1/quickbooks/connections/:connection_id/journal_entries
POST /api/v1/quickbooks/connections/:connection_id/journal_entries
GET  /api/v1/quickbooks/connections/:connection_id/journal_entry_operations
```

`GET /health` remains a separate liveness operation.

Profit & Loss and Cash Flow accept exact ISO `start_date` and `end_date` values, require the end date to be after
the start date, and cap the period at six calendar months. Balance Sheet accepts an ISO `as_of_date`, which Rails
sends to QuickBooks as `end_date`. Profit & Loss and Balance Sheet accept `Cash` or `Accrual`; Cash Flow rejects
`accounting_method` because the current official contract does not expose it.

Every response contains normalized report metadata, dynamic columns, recursively flattened rows, and the applied
filters. Monetary cells stay decimal strings; no Ruby or JavaScript floating-point conversion is used. Cash Flow
returns `basis: null` because QuickBooks does not return `ReportBasis` for that report.

## Implementation boundary

- `Api::V1::Quickbooks::FinancialReportsController` owns HTTP concerns and delegates all report work.
- `Quickbooks::Reports::Parameters` owns report-specific date/basis policy and stable validation errors.
- `Quickbooks::Reports::Query` maps only the three supported symbols to fixed Intuit report paths and reuses the
  existing connection-aware HTTP client.
- `Quickbooks::Reports::Details` validates and normalizes the Intuit report envelope, including nested sections,
  summaries, money strings, timestamps, and the observed Cash Flow leaf-row variation.
- `Quickbooks::Reports::Serializer` publishes one stable JSON shape to the dashboard and API consumers.
- Reports are transient reads. They are not Active Record entities and are not written to the synchronization
  audit table, which remains reserved for controlled writes.

This keeps the existing Rails request flow obvious and does not introduce a generic service base, repository
layer, engine, metaprogrammed endpoint, or report cache.

## Official-reference decisions

The implementation reviewed current official Rails routing, controller-parameter, form, and asset guidance and
current Intuit report-overview plus ProfitAndLoss, BalanceSheet, and CashFlow references before adding the new
flow. The findings and links are recorded in `docs/reference_review.md` and `docs/references.md`.

Two live-contract details materially shaped the implementation:

1. the Cash Flow reference and sandbox response neither accept nor return an accounting basis;
2. one live Cash Flow leaf row contained `ColData` and `group` without the otherwise documented `type` member.

Rails accepts that narrowly observed leaf shape while continuing to reject malformed report structures. It does
not invent missing Intuit fields or claim unsupported entity behavior.

## Dashboard and CSV acceptance

Opening the existing financial-records dashboard makes the initial Accounts, Journal Entries, local audit, and
Profit & Loss GETs independently. The new statement panel provides:

- a selector for exactly the three accepted reports;
- period controls for Profit & Loss and Cash Flow;
- one as-of control for Balance Sheet;
- an accounting-basis selector only where Intuit supports it;
- report title, basis, QuickBooks period, currency, generated timestamp, dynamic columns, and nested rows;
- CSV export of the currently loaded normalized statement, including row kind/group/depth metadata;
- a visible source-specific alert and unavailable state when a report request fails.

Browser acceptance against connection `2` confirmed:

1. Profit & Loss loaded by default with 60 rows, Accrual basis, USD, and its requested period.
2. Balance Sheet switched to the as-of form and loaded 45 rows with Accrual basis and USD.
3. Cash Flow switched back to period dates, hid the basis selector, displayed the explicit unsupported-basis note,
   and loaded 22 rows with `Not provided by QuickBooks` in the basis metadata.
4. `/api-docs` rendered OpenAPI 3.1.1 document version 1.3.0 and listed all three report GET operations under
   **Financial Reports**. The existing Journal Entry POST remains documentation-only in Swagger.

## HTTP and failure acceptance

Each report succeeded through the local Rails API and live QuickBooks sandbox. The successful report response
included `Cache-Control: no-store` and `Content-Type: application/json`. Invalid requests returned HTTP 422 with
stable code `quickbooks_report_parameters_invalid` for:

- a Cash Flow accounting basis;
- an end date equal to the start date;
- a period longer than six calendar months;
- period dates sent to Balance Sheet instead of `as_of_date`.

During repeated acceptance reads, Intuit returned one transient HTTP 500 for Profit & Loss. Rails converted it to
the existing sanitized HTTP 503 `quickbooks_upstream_error`; a later read and the dashboard load succeeded. This
confirms the failure remains visible without exposing vendor payloads, credentials, or tokens.

## Accounting effect

None. Every Phase 12 QuickBooks request was a GET to a sandbox report endpoint. Reports were generated from
existing sandbox transactions and were not stored locally. The accepted controlled Journal Entry and its audit
row were not changed.

## Final non-test verification

The final checks passed:

```text
bundle check                                      dependencies satisfied
bin/rails db:migrate:status                       all four migrations up
bin/rails routes -g reports                       three explicit GET report routes
bin/rails zeitwerk:check                          all is good
bin/rails runner                                  Rails 8.1.3 booted; three report types loaded
node --check financial_records.js                 passed
OpenAPI assertion                                 3.1.1 / v1.3.0 / 7 paths / 8 operations / 3 report GETs
RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop  64 files, no offenses
bundle exec brakeman --no-pager                   0 errors, 0 warnings
```

Automated tests remain explicitly deferred. The temporary local server used for acceptance was stopped after
validation. Phase 12 adds no production-readiness claim and starts no later phase.
