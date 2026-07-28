# QuickBooks financial records dashboard

This is one simple Ruby on Rails application for finance teams to:

- connect a QuickBooks Online sandbox;
- GET QuickBooks-generated Profit & Loss, Balance Sheet, Cash Flow, General Ledger, and Trial Balance reports
  through JSON APIs;
- GET existing QuickBooks Journal Entries through a JSON API;
- POST one balanced Journal Entry through a JSON API;
- read the created entry back from QuickBooks and show its returned ID;
- GET the local Journal Entry submission audit history without calling QuickBooks;
- filter Journal Entries and audit operations by transaction date on the server, load additional pages, and
  download the visible loaded records as CSV;
- GET and POST limited Employee records and employee TimeActivities through Rails APIs;
- GET TaxCodes, TaxRates, and TaxAgencies and POST a TaxCode using one existing active, applicability-compatible
  TaxRate;
- GET Inventory Items and eligible Accounts and POST one decimal-safe Inventory Item;
- GET and POST Customers, Vendors, one-line Invoices, one-line Bills, customer Payments applied to open Invoices,
  and check-style BillPayments applied to open Bills.

There is no separate frontend project or generic integration framework. Rails serves a small vanilla-JavaScript
dashboard. The financial-report, Account, and Journal Entry APIs call QuickBooks; the audit-history API reads
PostgreSQL only.

## MVP status

The simplified local QuickBooks sandbox MVP is complete. Production QuickBooks access remains intentionally
disabled; the setup, operating boundaries, and failure behavior are documented below.

The canonical source repository is
[`nakshatrasinghh/qbo-finance-bridge`](https://github.com/nakshatrasinghh/qbo-finance-bridge).
`config/credentials.yml.enc`, `config/master.key`, `.env*`, logs, temp files, and storage remain local and
ignored.

## Rails JSON APIs

The finance data-exchange surface is exactly twenty-nine operations:

```text
GET  /api/v1/quickbooks/connections/:connection_id/accounts
GET  /api/v1/quickbooks/connections/:connection_id/reports/profit_and_loss
GET  /api/v1/quickbooks/connections/:connection_id/reports/balance_sheet
GET  /api/v1/quickbooks/connections/:connection_id/reports/cash_flow
GET  /api/v1/quickbooks/connections/:connection_id/reports/general_ledger
GET  /api/v1/quickbooks/connections/:connection_id/reports/trial_balance
GET  /api/v1/quickbooks/connections/:connection_id/journal_entries
POST /api/v1/quickbooks/connections/:connection_id/journal_entries
GET  /api/v1/quickbooks/connections/:connection_id/journal_entry_operations
GET  /api/v1/quickbooks/connections/:connection_id/employees
POST /api/v1/quickbooks/connections/:connection_id/employees
GET  /api/v1/quickbooks/connections/:connection_id/time_activities
POST /api/v1/quickbooks/connections/:connection_id/time_activities
GET  /api/v1/quickbooks/connections/:connection_id/tax_codes
POST /api/v1/quickbooks/connections/:connection_id/tax_codes
GET  /api/v1/quickbooks/connections/:connection_id/inventory_items
POST /api/v1/quickbooks/connections/:connection_id/inventory_items
GET  /api/v1/quickbooks/connections/:connection_id/customers
POST /api/v1/quickbooks/connections/:connection_id/customers
GET  /api/v1/quickbooks/connections/:connection_id/vendors
POST /api/v1/quickbooks/connections/:connection_id/vendors
GET  /api/v1/quickbooks/connections/:connection_id/invoices
POST /api/v1/quickbooks/connections/:connection_id/invoices
GET  /api/v1/quickbooks/connections/:connection_id/bills
POST /api/v1/quickbooks/connections/:connection_id/bills
GET  /api/v1/quickbooks/connections/:connection_id/customer_payments
POST /api/v1/quickbooks/connections/:connection_id/customer_payments
GET  /api/v1/quickbooks/connections/:connection_id/bill_payments
POST /api/v1/quickbooks/connections/:connection_id/bill_payments
```

## QuickBooks data preprocessing

The Rails APIs are not raw QuickBooks pass-throughs. QuickBooks remains the accounting source of truth, while
Rails turns its vendor-specific JSON into a smaller, validated, decimal-safe contract for the dashboard and other
callers.

Every QuickBooks-backed GET follows the same basic path:

```text
Connection-scoped request
  -> sandbox QuickBooks API
  -> JSON and entity-shape validation
  -> reference/date/decimal normalization
  -> stable Rails JSON
```

Shared GET handling adds the company realm, OAuth bearer token, minor version, timeouts, safe error mapping, and
`Cache-Control: no-store`. It may refresh an expired token and retry one GET after a `401`. Money is parsed with
`BigDecimal` and serialized as decimal strings; dates use exact ISO `YYYY-MM-DD` values. Raw Intuit bodies,
tokens, and fields outside the documented projection are not returned.

Every create API additionally:

1. permits and trims only its documented fields;
2. requires a UUID `Idempotency-Key` and reserves a connection-scoped PostgreSQL audit row;
3. hashes the canonical request so an identical success can be replayed without another QuickBooks POST;
4. requeries current QuickBooks references before creating the entity;
5. builds one fixed entity-specific payload with exact decimal values;
6. reads the created entity back and verifies its important fields; and
7. records the result as `succeeded`, `rejected`, or `uncertain`.

POST is never automatically retried after an ambiguous failure because QuickBooks may already have committed the
record.

| API surface | GET preprocessing | POST preprocessing |
|---|---|---|
| Accounts (1 GET) | Pages through active Accounts, validates required fields and duplicate IDs, sorts display names, and removes Accounts Receivable and Accounts Payable from Journal Entry choices. | None; Account creation is not exposed. |
| Financial reports (5 GETs) | Validates report-specific dates, six-month period limits, and supported Cash/Accrual input; validates currency, timestamps, columns, and decimal money cells; flattens recursive section/data/summary rows while preserving order and depth. | None; Rails does not calculate, persist, or modify report totals. |
| Journal Entries (GET/POST) | Validates date filters and bounded pagination, queries deterministic pages, keeps Journal Entry lines, extracts Account references, parses decimal amounts, and derives a balanced flag. | Validates an exact date, memo, positive amount, and two different eligible active Accounts; creates equal Debit/Credit lines and verifies the returned posting. |
| Journal Entry audit (1 GET) | Reads only connection-scoped `journal_entry_create` rows from PostgreSQL, filters by the original transaction date, paginates, and omits keys, digests, raw payloads, tokens, and stored result bodies. It does not call QuickBooks. | Rows are produced by the Journal Entry create flow; there is no audit POST endpoint. |
| Employees (GET/POST) | Keeps active directory records, extracts nested email/phone values, validates identity fields, sorts by display name, and explicitly reports that full payroll is unsupported. | Accepts names and optional contact data only, excludes payroll/sensitive fields, validates formats, and verifies readback. |
| Time Activities (GET/POST) | Returns the latest 100 records, flattens `EmployeeRef`, validates dates, and converts hours/minutes to integers. | Requires a current active Employee, exact date, nonzero whole hours/minutes, and bounded description; verifies the returned activity. |
| Tax configuration (GET/POST) | Combines TaxCode, TaxRate, and TaxAgency queries; flattens rate-reference lists, validates percentage decimals, removes identical duplicate IDs, rejects conflicting duplicates, and sorts each collection. | Rejects duplicate names, requires an active existing rate and an agency compatible with Sales/Purchase applicability, then requeries the catalog to verify creation. |
| Inventory Items (GET/POST) | Parses quantity, price, and cost decimals; validates Account references and dates; combines active Accounts into eligible income, COGS, and inventory-asset choices. | Validates unique name, exact start date, nonnegative decimal quantity/price/cost, and eligible live Accounts; verifies amounts and references on readback. |
| Customers (GET/POST) | Keeps active Customers, extracts nested contact values, parses balance as a decimal, validates required fields, and sorts by display name. | Validates contact fields, rejects a case-insensitive duplicate active display name, and verifies the created Customer. |
| Vendors (GET/POST) | Applies the Customer-style active/contact/balance normalization to Vendors. | Validates contact fields, rejects a case-insensitive duplicate active display name, and verifies the created Vendor. |
| Invoices (GET/POST) | Validates IDs/dates/totals/balances, keeps sales-item lines, flattens Customer and Item references, sorts newest first, and adds active Customer plus eligible sales Item choices. | Creates one positive decimal sales line for a current Customer and Item, enforces due date on/after invoice date, and verifies dates, references, line amount, total, and balance. |
| Bills (GET/POST) | Validates IDs/dates/totals/balances, keeps account-based expense lines, flattens Vendor/Account references, sorts newest first, and adds active Vendor, expense, and Accounts Payable choices. | Creates one positive decimal expense line using current eligible references and verifies the Vendor, payable Account, dates, line, total, and balance. |
| Customer Payments (GET/POST) | Parses total/unapplied decimal amounts and Invoice links, sorts newest first, and separately derives open Invoice choices from positive current balances. | Requeries the selected open Invoice, caps the amount at its current balance, derives the Customer from the Invoice, creates one link, and verifies the application. |
| Bill Payments (GET/POST) | Parses Check/CreditCard payment Accounts and Bill links, sorts newest first, and derives open Bill plus active Bank Account choices. | Requeries the open Bill and Bank Account, caps the amount at the current Bill balance, derives Vendor/A/P references, creates one check-style link, and verifies the application. |

This is schema and write-safety preprocessing, not a general analytics pipeline. The app does not yet build
question-specific aggregates such as overdue balance by customer, maintain a full local QuickBooks warehouse,
consume CDC/webhooks, perform currency conversion, or create embeddings. Many entity catalogs are also bounded
at 1,000 records; Accounts and Journal Entries have explicit multi-page handling.

Repository documentation:

- [`docs/quickbooks_data_model.md`](docs/quickbooks_data_model.md): QuickBooks entities and their accounting
  relationships.
- [`docs/quickbooks_data_normalization.md`](docs/quickbooks_data_normalization.md): the ten transformations from
  vendor-specific QuickBooks JSON to the stable Rails contract.
- [`docs/architecture.md`](docs/architecture.md): Rails components and responsibilities.
- [`docs/data_flow.md`](docs/data_flow.md): runtime request and processing sequences.

The three connection-owned HTML routes are frontend shells only. Browser JavaScript calls the JSON APIs after
load; ERB rendering never exchanges finance data with QuickBooks.

The application also retains its read-only `GET /health` JSON liveness endpoint.

## OpenAPI and Swagger UI

Open the API documentation at:

```text
http://localhost:3000/api-docs
```

The page renders the checked-in OpenAPI 3.0.3 contract at `docs/openapi.yaml`. It documents the twenty-nine finance
data operations and health, including read models, eleven audited/idempotent create contracts, replay responses, and
normalized errors. The local Journal Entry audit GET is explicitly PostgreSQL-only. Swagger UI permits
interactive GET requests only. POST operations are visible as documentation but cannot be executed from Swagger
because each would create a real QuickBooks sandbox record.

Swagger UI is loaded from the pinned official `swagger-ui-dist@5.32.8` browser distribution. No Swagger gem,
RSpec integration, Node package, or second frontend process is required.

## What “financial record” means

QuickBooks does not have one generic `FinancialRecord` API. This dashboard uses `JournalEntry` for a controlled
posting record and separate read-only report endpoints for QuickBooks-generated financial statements.

The form asks for:

- date;
- memo;
- positive amount;
- one existing QuickBooks debit account;
- one different existing QuickBooks credit account.

Rails sends two lines with the same amount, so debit equals credit. Accounts Receivable and Accounts Payable are excluded because QuickBooks requires an additional customer or vendor reference for those lines.

## Runtime

- Ruby 3.4.10
- Rails 8.1.3
- PostgreSQL 16
- Faraday 2.14.3

## Installation

Follow [`INSTALLATION.md`](INSTALLATION.md) to install Ruby and PostgreSQL, create developer-specific encrypted
credentials, configure an Intuit sandbox app, prepare the databases, connect QuickBooks, and validate the
checkout.

After installing Ruby 3.4.10 and PostgreSQL 16, the primary setup command is:

```bash
bin/install
```

## Run the app

From the repository root:

```bash
brew services start postgresql@16
QUICKBOOKS_ENV=sandbox bin/dev
```

Open:

```text
http://localhost:3000/quickbooks/connections
```

Select the connected sandbox company, then open **Financial records**, **Sales and payables**, or **Workforce,
tax, and inventory**.

This is the frontend. The JavaScript is served by Rails/Propshaft. No `npm`, `yarn`, or second process is required.

## QuickBooks credentials

`bin/install` securely asks for each developer's Intuit Development Client ID and Client Secret, generates the
Rails and Active Record Encryption keys, and writes an ignored encrypted credentials/master-key pair. Developers
do not manually invent encryption values.

In the Intuit developer portal, use Development keys, enable the QuickBooks accounting scope, and register this exact redirect URI:

```text
http://localhost:3000/quickbooks/connections/callback
```

Both `config/credentials.yml.enc` and `config/master.key` stay local and ignored. Never paste the client secret,
access token, refresh token, encryption keys, or master key into documentation or version control. The complete
workflow, manual fallback, and key explanations are in [`INSTALLATION.md`](INSTALLATION.md).

Environment variables remain available for deployment/CI, but they are not required for this configured checkout:

```bash
export QUICKBOOKS_ENV=sandbox
export QUICKBOOKS_CLIENT_ID='YOUR_DEVELOPMENT_CLIENT_ID'
export QUICKBOOKS_CLIENT_SECRET='YOUR_DEVELOPMENT_CLIENT_SECRET'
export QUICKBOOKS_REDIRECT_URI='http://localhost:3000/quickbooks/connections/callback'
```

Production QuickBooks access is intentionally disabled.

## How the dashboard works

### GET

Opening the page causes browser JavaScript to perform four Rails API requests:

1. `GET .../accounts`, which queries active QuickBooks Accounts for the dropdowns;
2. `GET .../journal_entries?page=1&per_page=25`, which queries the first QuickBooks Journal Entry page;
3. `GET .../journal_entry_operations?page=1&per_page=25`, which reads the first local audit page from PostgreSQL
   and makes no QuickBooks request;
4. `GET .../reports/profit_and_loss`, which loads the default rolling six-month Accrual statement.

### Workforce, tax, and inventory operations

The separate `/quickbooks/connections/:connection_id/operations` page loads four independent GET APIs after its
HTML shell renders.

The payroll scope is intentionally limited. The app does not run payroll, calculate wages, create paychecks,
manage deductions, or file payroll tax. It supports public Accounting API Employee records and employee
TimeActivities only.

Each of the four POST APIs requires Rails CSRF plus a UUID `Idempotency-Key`, reserves a connection-scoped
audit row before external HTTP, validates current QuickBooks references, forwards the UUID as `requestid`, and
reads the created record back before reporting HTTP 201. A matching successful replay returns HTTP 200 without a
new QuickBooks call; conflicting or unresolved reuse returns HTTP 409.

### Customers, vendors, sales, and payables

The separate `/quickbooks/connections/:connection_id/transactions` page loads six independent GET APIs for
Customers, Vendors, Invoices, Bills, customer Payments, and BillPayments. Invoice responses also supply active
Customer and sales-Item choices. Bill responses supply active Vendor, expense Account, and Accounts Payable
choices. Payment responses supply currently open source transactions, and BillPayment also supplies active bank
Accounts.

Each create is deliberately narrow: a unique Customer or Vendor list record, a one-line Invoice, a one-line
account-based Bill, one Payment applied to one open Invoice, or one check-style BillPayment applied to one open
Bill. Amounts are decimal strings, dates are exact ISO 8601 values, and referenced records are re-queried before
POST. All six use the same audit/idempotency/readback safety sequence.

### Read-only financial statements

The dashboard exposes five separate GET APIs:

```text
GET .../reports/profit_and_loss?start_date=2026-01-16&end_date=2026-07-16&accounting_method=Accrual
GET .../reports/balance_sheet?as_of_date=2026-07-16&accounting_method=Accrual
GET .../reports/cash_flow?start_date=2026-01-16&end_date=2026-07-16
GET .../reports/general_ledger?start_date=2026-06-21&end_date=2026-07-21&accounting_method=Accrual
GET .../reports/trial_balance?start_date=2026-06-21&end_date=2026-07-21&accounting_method=Accrual
```

Profit & Loss, Cash Flow, General Ledger, and Trial Balance accept inclusive ISO periods of at most six calendar
months. Balance Sheet accepts one `as_of_date`, which Rails sends to QuickBooks as `end_date`. Every report except
Cash Flow accepts `Cash` or `Accrual`. The General Ledger integration uses the explicit
`reports/GeneralLedger` path.

Rails normalizes QuickBooks' recursive report envelope into ordered columns plus flattened `section`, `data`, and
`summary` rows with their original nesting depth. Money cells remain validated decimal strings. The dashboard
displays raw QuickBooks values and can download the current statement as formula-safe CSV; it does not calculate,
store, or POST report values.

### Read-only filters, pagination, and CSV

Both read APIs accept the same optional query parameters:

```text
txn_date_from=2026-07-01&txn_date_to=2026-07-31&page=1&per_page=25
```

Dates must be exact ISO 8601 calendar dates and are inclusive. `page` is 1–10,000; `per_page` is 1–50 and defaults
to 50 for a direct API call. Invalid parameters return HTTP 422 with
`quickbooks_read_parameters_invalid`. Each successful response includes the data array, echoed `filters`, and
`pagination` metadata containing `page`, `per_page`, `returned_count`, `has_more`, and `next_page`.

The dashboard requests 25 records per page and keeps the two read sources independent:

- entry-date from/to is sent to both GET APIs and reloads page 1;
- Journal Entries are ordered by transaction date descending and QuickBooks ID descending;
- audit operations are ordered by submission time descending and local ID descending, while the date predicate
  applies to the original submitted Journal Entry date;
- separate **Load more** buttons request the next page only for the relevant table;
- memo is applied in the browser to Journal Entry and audit pages loaded so far;
- audit status is applied in the browser only to loaded local operations;
- each CSV contains only the currently visible loaded data;
- the Journal Entry CSV uses one row per debit/credit line, while the audit CSV uses one row per operation;
- decimal strings and ISO 8601 source values are copied without accounting calculations;
- every CSV field is quoted, embedded quotes are escaped, and spreadsheet formula prefixes are neutralized.

The downloads are created temporarily in the browser; Rails does not add an export route or write a server-side
file. The public finance API surface is therefore the twenty-nine operations listed above.

### Journal Entry POST

Submitting the form calls `POST .../journal_entries` with JSON. The API:

1. requires a browser-generated UUID `Idempotency-Key` and reserves it in a connection-scoped local audit row;
2. validates date, memo, amount, and two different Account IDs;
3. rereads active Accounts to reject stale or fabricated selections;
4. sends one JSON `POST /journalentry` to QuickBooks with the same UUID as Intuit's `requestid` query parameter;
5. reads `GET /journalentry/:id` back;
6. verifies the ID, date, balance, amount, and selected accounts;
7. marks the audit row succeeded and returns HTTP 201 JSON with the QuickBooks ID and local operation ID.

The browser keeps one UUID for one intended form submission. A completed request repeated with the same UUID and
the same canonical fields returns the stored result with HTTP 200 and `Idempotency-Replayed: true`; Rails does not
call QuickBooks. The same UUID with different fields returns HTTP 409. A pending, rejected, or uncertain operation
also returns HTTP 409 instead of risking a second QuickBooks POST. A deliberately corrected or new transaction
must use a new UUID.

Every newly successful POST creates a real posting transaction in the sandbox. A replayed success does not. The
page shows a confirmation before sending and refreshes the records and local audit tables after every POST
outcome, including a rejection or uncertain result. These follow-up requests are GET-only reconciliation reads;
the application never automatically retries a Journal Entry POST after an HTTP 401 or uncertain transport result.
The durable key and audit state make that uncertainty visible without creating another record.

The APIs are currently intended for this same-origin development dashboard. Rails CSRF protection applies to POST; production authentication is intentionally not invented for a local sandbox tool.

### API failures

When any dashboard GET fails, the browser retries that Rails GET once after 500 ms only for the safe
`quickbooks_timeout` and `quickbooks_unavailable` codes. It never retries a POST. If the second GET also fails,
the page shows a prominent red error banner containing the API's safe error message.
The affected statement table, account selectors, QuickBooks records table, or local audit table also change from
“Loading” to an explicit unavailable state. If Accounts cannot be loaded, POST remains disabled. A financial
statement or audit-history failure does not disable posting because those reads are independent.

After every dashboard POST response, successful or not, the browser calls the related GET API or APIs and reports
the POST and refresh outcomes separately. The form values remain available after failure. This wording and
behavior are deliberate: a response or readback failure does not always prove that QuickBooks rejected the
transaction, while the reconciliation GET may already show the native record. The browser preserves the UUID for
uncertain/in-progress failures. It renews the UUID after malformed keys, rejected operations, definitive
same-key/different-payload conflicts, and entity-specific local validation errors. Rails refuses to resend an
unresolved key. The banner can be dismissed; the smaller status line continues to show the outcome. Swagger
displays HTTP failures inside the expanded operation as usual.

## Local validation commands

```bash
RBENV_VERSION=3.4.10 rbenv exec bundle check
RBENV_VERSION=3.4.10 rbenv exec ruby bin/format write
RBENV_VERSION=3.4.10 rbenv exec ruby bin/format check
RBENV_VERSION=3.4.10 rbenv exec ruby bin/rails db:prepare
RBENV_VERSION=3.4.10 rbenv exec ruby bin/rails test
RBENV_VERSION=3.4.10 rbenv exec ruby bin/rails db:migrate:status
RBENV_VERSION=3.4.10 rbenv exec ruby bin/rails routes -g quickbooks
RBENV_VERSION=3.4.10 rbenv exec ruby bin/rails routes -g api-docs
RBENV_VERSION=3.4.10 rbenv exec ruby bin/rails zeitwerk:check
RBENV_VERSION=3.4.10 rbenv exec ruby bin/rails runner 'puts "Rails booted successfully"'
node --check app/assets/javascripts/financial_records.js
node --check app/assets/javascripts/operational_capabilities.js
node --check app/assets/javascripts/accounting_transactions.js
ruby -e 'require "yaml"; puts YAML.safe_load_file("docs/openapi.yaml").fetch("openapi")'
RUBOCOP_CACHE_ROOT=tmp/rubocop_cache RBENV_VERSION=3.4.10 rbenv exec ruby bin/rubocop
RBENV_VERSION=3.4.10 rbenv exec bundle exec brakeman --no-pager
```
