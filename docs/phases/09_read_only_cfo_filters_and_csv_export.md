# Phase 9 — Read-only CFO filters and CSV export

## Outcome

Phase 9 adds one compact dashboard panel for filtering the bounded Journal Entry and local audit JSON already
loaded by the existing APIs, plus two CSV downloads for the currently visible data. Filtering and export run only
in the browser. They create no Rails request, database query, QuickBooks request, audit operation, or accounting
transaction.

The CFO API surface remains exactly four operations:

```text
GET  /api/v1/quickbooks/connections/:connection_id/accounts
GET  /api/v1/quickbooks/connections/:connection_id/journal_entries
POST /api/v1/quickbooks/connections/:connection_id/journal_entries
GET  /api/v1/quickbooks/connections/:connection_id/journal_entry_operations
```

No new route, controller, model, migration, QuickBooks entity, gem, JavaScript package, build process, or automated
test infrastructure was added.

## Filter behavior

The panel has four explicit controls:

- inclusive **Entry date from**;
- inclusive **Entry date to**;
- case-insensitive **Memo contains**;
- exact **Audit status** (`pending`, `succeeded`, `rejected`, or `uncertain`).

Entry date and memo apply to both tables. Status applies only to local audit history, so selecting an audit status
never hides a matching native QuickBooks Journal Entry. An end date before the start date is rejected by the
browser with `Entry date to must be on or after entry date from.` Clearing the controls restores the current
bounded source arrays.

The table summaries always distinguish visible count from API count. A zero-result filter shows an explicit
no-match row, and the corresponding CSV button is disabled. Existing API failure behavior remains unchanged.

## CSV behavior

The Journal Entry download uses one row per visible debit/credit line with these columns:

```text
txn_date, quickbooks_journal_entry_id, doc_number, memo, balanced,
posting_type, amount, account_id, account_name, line_description
```

The audit download uses one row per visible local operation with these columns:

```text
operation_id, status, submitted_at, completed_at, txn_date, memo, amount,
debit_account_id, credit_account_id, quickbooks_journal_entry_id, error_code
```

Amounts remain the decimal strings supplied by the APIs. No total, balance, exchange-rate, or other accounting
calculation occurs in JavaScript. ISO 8601 values are copied without reinterpretation.

Every CSV field is quoted, embedded quotes are doubled, and values beginning with spreadsheet formula-trigger
characters are neutralized inside the quoted field. A UTF-8 byte-order mark supports common spreadsheet readers.
The browser creates a temporary `Blob` URL for the download and revokes it after use. Rails does not write or
retain an export file.

## Rails and browser design decision

`docs/reference_review.md` records the current Rails Asset Pipeline and form-control guidance, browser Blob URL
guidance, and OWASP CSV Injection guidance reviewed for this phase. The existing Propshaft-served JavaScript and
CSS remain the appropriate boundary because both source datasets are already present in the page and bounded at
50 records.

The implementation keeps two source arrays and derives two visible arrays without mutating the API objects. Two
fixed export schemas make the accounting meaning reviewable. A server CSV response, export route, CSV gem, grid
library, frontend framework, saved-filter model, and background export were rejected because none solve a current
problem at this scale.

No Intuit documentation change was needed. This phase adds no Intuit field, entity, query, or request; that
decision is recorded in `docs/references.md`.

## Validation evidence

Interactive validation on 2026-07-15 used the real local Rails dashboard and existing sandbox data without
submitting the Journal Entry form:

- Initial load: 87 eligible Accounts, five QuickBooks Journal Entries, and one local audit operation; no alert.
- Memo `controlled sandbox`: one of five QuickBooks entries and one of one audit operations visible, both for the
  Phase 6 record.
- Audit status `rejected`: the matching QuickBooks entry remained visible, audit became zero of one, the explicit
  audit no-match row appeared, and the audit export button became disabled.
- Entry date `2026-05-26` through `2026-05-26`: exactly the two May 26 QuickBooks entries appeared; the July audit
  operation did not.
- Invalid date range: native validity became false with the intended message and the previously rendered data was
  not replaced.
- Clear: memo/status/date controls emptied and the full five/one datasets returned.
- Layout: at a 1280-pixel viewport, the filter panel and actions had no horizontal overflow; buttons wrapped by
  CSS when needed. Browser diagnostic logs were empty.
- Browser QA caught and corrected a singular/plural status message; the final message reads `1 visible Journal
  Entry`.

Downloaded CSV validation:

- Full Journal Entry CSV: UTF-8 BOM, exact ten-column schema, 10 lines across IDs `146`, `145`, `8`, `7`, and `6`,
  both `Debit` and `Credit` posting types, and decimal-string amounts.
- Memo-filtered Journal Entry CSV: exactly two lines, both ID `146`, one debit and one credit, amount `1.0`, and
  only the Phase 6 memo.
- Audit CSV: exact 11-column schema and one row for operation `1`, `succeeded`, transaction date `2026-07-15`,
  original amount `1.00`, Accounts `15` → `20`, and QuickBooks ID `146`.
- Sensitive-column assertion: audit CSV contained none of `idempotency_key`, `request_digest`, `request_payload`,
  `result_payload`, `access_token`, or `refresh_token`.

Browser validation created four local files in `/Users/nakshatrasingh/Downloads`: the full Journal Entry CSV, two
filtered/retest Journal Entry CSVs with browser-added numeric suffixes, and the audit CSV. They are user-visible
download artifacts only and were not added to the repository.

Final read-only reconciliation:

- QuickBooks sandbox still returned five Journal Entries and exactly one ID `146`.
- PostgreSQL still contained exactly one audit operation: operation `1`, `succeeded`, mapped to ID `146`.
- All four existing migrations remained `up`; Phase 9 added no migration.
- QuickBooks writes: zero.
- Local financial/audit writes: zero.

Static validation:

- JavaScript syntax passed.
- Bundle check, route inspection, and Rails Zeitwerk eager loading passed.
- OpenAPI remained 3.1.1 with exactly four CFO operations.
- RuboCop inspected 56 files with no offenses.
- Brakeman 8.0.5 reported zero errors and zero security warnings.
- Automated tests were not created, modified, or run because tests remain explicitly deferred.

## Manual verification

Run Rails and open:

```text
http://localhost:3000/quickbooks/connections/2/journal_entries
```

Apply a memo or inclusive entry-date filter and confirm that both table summaries show visible/total counts. Set
an audit status and confirm that only the audit table changes. Download each CSV and inspect it in a text editor or
spreadsheet application. Do not submit the Journal Entry form merely to validate this read-only phase.
