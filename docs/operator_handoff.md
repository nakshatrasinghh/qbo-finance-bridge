# Local sandbox MVP operator handoff

## Handoff status

The application is accepted as a local, single-operator QuickBooks Online **sandbox** MVP. It connects one
sandbox company; serves five financial statements, Journal Entries, and local audit history; and exposes
controlled workforce/tax/inventory plus customer/vendor/sales/payables reads and creates. It is not approved for
production QuickBooks, public/network deployment, unattended financial processing, or full payroll.

The active CFO API surface is exactly twenty-nine operations:

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

`GET /health` is an application liveness check, not a CFO data operation.

## Start the application

Prerequisites: Ruby 3.4.6 through rbenv, PostgreSQL 16, the encrypted `config/credentials.yml.enc`, and the matching
local `config/master.key` supplied through a secure channel.

```bash
cd /Users/nakshatrasingh/Spurtree/ai/ruby-cfo-bridge
brew services start postgresql@16
RBENV_VERSION=3.4.6 rbenv exec ruby bin/setup --skip-server
QUICKBOOKS_ENV=sandbox RBENV_VERSION=3.4.6 rbenv exec ruby bin/dev
```

Open `http://localhost:3000/quickbooks/connections`. Select **Inspect** for the active sandbox connection, verify
CompanyInfo readback, then open **Financial records**, **Sales and payables**, or **Workforce, tax, and
inventory**. API documentation is available at `http://localhost:3000/api-docs`.

Stop the foreground server with `Ctrl-C`.

## Safe daily workflow

### Read

Opening the dashboard calls Accounts, Journal Entries, audit history, and the default Profit & Loss GET. Selecting
another statement calls only its explicit report endpoint. Statement dates and Journal Entry dates are inclusive
server reads; memo and audit status operate on pages currently loaded in the browser. **Load more** calls only the
relevant next-page GET. Statement CSV contains the current normalized report; Journal Entry/audit CSV downloads
contain visible loaded rows only and are not a complete point-in-time export unless every page has been loaded.

Profit & Loss, Cash Flow, General Ledger, and Trial Balance periods are limited to six calendar months. Balance
Sheet uses an as-of date. Every report except Cash Flow accepts Cash or Accrual. General Ledger uses the
sandbox-validated `reports/GeneralLedger` endpoint and returns the same normalized read-only report shape as the
other statements.

### Create

The Journal Entry form is a real sandbox write. Before confirming it:

1. Verify the page says `sandbox` and shows the expected company.
2. Enter an ISO date, explanatory memo, positive decimal amount, and two different eligible Accounts.
3. Confirm the accounting intent: the selected debit increases that account's debit balance and the selected
   credit increases that account's credit balance.
4. Submit once. Wait for the returned QuickBooks ID and readback confirmation.
5. Inspect the local audit row and QuickBooks sandbox record before considering a retry after any uncertain error.

The browser generates a UUID idempotency key. Rails reserves it locally, forwards it as Intuit `requestid`, and
will not automatically repeat an uncertain write. Do not use a new key merely to bypass an unresolved outcome.

Swagger intentionally has no **Try it out** control for POST. It documents the write but cannot execute it.

### Workforce, tax, and inventory

The operations page issues four independent GETs for Employees, TimeActivities, tax configuration, and Inventory
Items/account choices. Full payroll is unavailable: Employee and TimeActivity are payroll-adjacent Accounting API
records only. TaxCode creation uses one existing active TaxRate. The dashboard limits Sales/Purchase choices to
the capabilities advertised by that rate's TaxAgency; the server repeats the same check immediately before POST.
Inventory Item creation uses existing eligible income, COGS, and inventory-asset Accounts; positive opening
quantity and cost can change inventory value.

All four creates use the same safety sequence as the Journal Entry write: confirmation in the browser, CSRF,
connection-scoped UUID reservation, entity-specific current-reference validation, Intuit `requestid`, readback,
and a succeeded/rejected/uncertain local operation. Do not bypass an uncertain operation with a new key.

Phase 17 validated one controlled record through each path. Employee `400000001` and linked 15-minute
TimeActivity `1073741824` are workforce/time records only. TaxCode `4` (`P17TAX721`) uses Sales TaxRate `3`.
Inventory Item `19` uses Accounts `79`/`80`/`81`, quantity zero, cost `0.01`, and price `0.02`. All four were read
back, all four same-key replays returned their stored HTTP 200 result, and operations `25`–`28` succeeded.

Two later user-initiated TaxCodes are visible through GET but retain honest uncertain audit states: operation `33`
for ID `5` (`Test TAX`) lost its immediate readback to a transient availability failure, and operation `36` for
ID `6` (`Test TAX 2`) observed QuickBooks normalize an incompatible Purchase request into the sales-rate list.
Do not delete these audit rows or retry either key. Phase 21 prevents the same applicability mismatch before POST.

### Customers, vendors, sales, and payables

The sales/payables page issues six independent GETs. Invoice data includes active Customer and sales-Item
choices. Bill data includes active Vendor, expense Account, and Accounts Payable choices. Customer Payment data
includes open Invoices. BillPayment data includes open Bills and active bank Accounts.

The six creates are deliberately narrow: one unique Customer, one unique Vendor, one-line Invoice, one-line
account-based Bill, one Payment applied to one open Invoice, or one check-style BillPayment applied to one open
Bill. Every transaction amount is a decimal string, every date is ISO 8601, and Rails reloads source references
before POST. These writes can change receivable, payable, income, expense, cash, or inventory balances. They use
the same CSRF, UUID idempotency, connection-scoped audit, requestid, conservative uncertainty, and readback
sequence as the accepted Journal Entry path. No valid Phase 14 POST was executed during acceptance.

Phase 16 subsequently validated one complete controlled lifecycle. Customer `58` and Vendor `59` are the
non-posting list records. Invoice `147` (`1038`) posted $2.00 to Service Item `1`; Payment `148` applied it in
full. Bill `149` posted $1.00 to Office Expenses (`15`) and Accounts Payable (`33`); BillPayment `150` applied it
in full from Checking (`35`). All six local operations succeeded and all six same-key replays returned stored
HTTP 200 responses without another QuickBooks write. Use the normal GET APIs—not an idempotent replay's stored
creation-time payload—to inspect a transaction's current balance after later linked payments.

A later stale browser confirmation submitted the same Customer with a new UUID. The duplicate-name guard found
active Customer `58` through a QuickBooks query, returned HTTP 422 before any Customer POST, and preserved local
rejected operation `24`. This did not create another Customer or change any financial report.

## Failure handling

- A dashboard GET that returns `quickbooks_timeout` or `quickbooks_unavailable` is retried once by the browser
  after 500 ms. If it still fails, a red alert marks only the affected source unavailable.
- Every dashboard POST attempt is followed by its related GET API or APIs, even when POST returns an error. The
  alert reports the POST and refresh outcomes separately; this follow-up is read-only and never resends POST.
- A financial-statement failure does not disable the independent Journal Entry write form.
- An Accounts failure keeps POST disabled.
- A missing Customer, Vendor, sales Item, expense/AP Account, open source transaction, or bank Account keeps only
  its dependent Phase 14 POST disabled.
- A POST validation failure preserves the form and receives a new key for a corrected attempt. Malformed,
  rejected, and same-key/different-payload conflicts also renew the browser key.
- A transport, authentication, or readback failure may have an uncertain external outcome. Check QuickBooks and
  the audit table before retrying; the browser deliberately retains an uncertain or in-progress key.
- A stale access token is refreshed once automatically. If the refresh grant is no longer usable, reconnect the
  sandbox from the connections page.
- **Disconnect and revoke access** changes authorization state. Do not use it as ordinary troubleshooting.

## Credentials and source-control handoff

Rails stores application credentials in encrypted `config/credentials.yml.enc`. The matching `config/master.key`
is local and ignored by `/config/*.key`; `.env*`, logs, temp files, storage, and compiled assets are also ignored.
Never send the master key in the repository, chat, issue tracker, or application log. Transfer it separately to
an authorized operator. Losing it makes the encrypted credentials unusable.

OAuth access and refresh tokens are encrypted in PostgreSQL and omitted from views/JSON. Do not copy database
token columns into diagnostics.

Phase 20 established the reviewed initial `main` branch in
`https://github.com/nakshatrasinghh/qbo-finance-bridge.git`. The encrypted credentials file is versioned, but its
master key remains ignored and must be transferred separately to an authorized operator. Never add the key to a
later commit.

Phase 18 completed the repository-side CI preflight. The canonical executable `bin/importmap` and an empty
`config/importmap.rb` package map are present, `loofah` is locked at `2.25.2`, and `rails-html-sanitizer` is locked
at `1.7.1`. The exact GitHub Actions commands for Brakeman, Bundler Audit, Importmap Audit, and RuboCop all pass.
No automated test command was added or run. At the end of Phase 18, Git still had no initial commit or remote;
Phase 20 performed that separately authorized source-control handoff after the formatter and CI preflights.

Four Phase 9 QA exports remain outside the repository in `/Users/nakshatrasingh/Downloads`: three
`quickbooks-journal-entries-2026-07-15...csv` files and one `journal-entry-audit-2026-07-15.csv`. They contain
sandbox financial metadata. Phase 11 did not delete user files. Archive them in an approved location or delete
them manually when they are no longer needed.

## Legacy cleanup disposition

The rejected mapping experiment remains only as historical evidence:

- PostgreSQL has one unused `account_mappings` row, ID `5`, mapping `qbo_cfo_bridge_demo/operating_expense` to
  QuickBooks Account ID `1150040000`.
- The sandbox still has active Expense Account `CFO Bridge Demo Operating Expense`, ID `1150040000`.
- No active route, controller, page, or Journal Entry request uses the mapping.
- Both dashboard Account lists and server-side Journal Entry validation exclude the demo Account by its fixed
  name.

The row/table and sandbox Account are retained. Deleting the row would not remove the QuickBooks Account;
deactivating the Account would be an external QuickBooks write. Any cleanup must be separately requested, verify
that the Account is unused, name the exact sandbox ID, and define whether historical local evidence should also
be removed.

## Current accepted evidence

- Active local connection: ID `2`, environment `sandbox`.
- Eligible form Accounts: `87`; demo Account absent from both selectors.
- QuickBooks Journal Entries: five, ordered IDs `146`, `145`, `8`, `7`, `6`.
- Controlled application-created entry: ID `146`, balanced and read back.
- Local audit operations: twelve total. Operation `1` is the accepted Journal Entry; operations `4` through `9`
  are the six succeeded Phase 16 lifecycle creates; operation `24` is the preserved rejected duplicate-Customer
  attempt that stopped before a QuickBooks POST; operations `25` through `28` are the four succeeded Phase 17
  creates. The Journal Entry audit-history API intentionally still returns only operation `1` because it is
  entity-specific.
- Live core statements on 2026-07-16: Profit & Loss 60 rows, Balance Sheet 45 rows, Cash Flow 22 rows.
- Current Phase 17 reads: 3 Employees, 6 TimeActivities, 6 TaxCodes, 3 distinct TaxRates, 2 TaxAgencies, and 5
  Inventory Items.
- Inventory create prerequisites: one eligible Account for each income, COGS, and inventory-asset role.
- Phase 17 writes: Employee `400000001`, TimeActivity `1073741824`, TaxCode `4`, and Inventory Item `19`; all
  created/read back and all same-key replays returned 200 without another QuickBooks write.
- Phase 14 reads: 29 Customers, 26 Vendors, 31 Invoices, 15 Bills, 16 customer Payments, 10 BillPayments,
  20 open Invoices, 5 open Bills, 18 sales Items, 49 expense Accounts, 1 Accounts Payable Account, and 2 bank
  Accounts.
- Trial Balance reconciled after Phase 17. General Ledger: 8 columns and 462 normalized rows, including exactly
  eight Phase 16 accounting legs and two Phase 17 zero-dollar Inventory Starting Value rows.
- Phase 14 writes: zero valid vendor POSTs; local audit row count remained one.
- Phase 16 writes: Customer `58`, Vendor `59`, Invoice `147`, Payment `148`, Bill `149`, and BillPayment `150`;
  all read back, their six audit rows succeeded, Invoice/Bill settled to zero, and all same-key replays returned
  200.
- OpenAPI: 3.0.3, document version 1.5.1; twenty-nine CFO operations plus health.
- All six migrations are applied.

These are sandbox facts observed through 2026-07-21 and can change when an operator deliberately changes sandbox
data.

## Final non-test verification

```bash
RBENV_VERSION=3.4.6 rbenv exec bundle check
RBENV_VERSION=3.4.6 rbenv exec ruby bin/format check
RBENV_VERSION=3.4.6 rbenv exec ruby bin/rails db:migrate:status
RBENV_VERSION=3.4.6 rbenv exec ruby bin/rails routes -g quickbooks
RBENV_VERSION=3.4.6 rbenv exec ruby bin/rails routes -g api-docs
RBENV_VERSION=3.4.6 rbenv exec ruby bin/rails zeitwerk:check
RBENV_VERSION=3.4.6 rbenv exec ruby bin/rails runner 'puts "Rails booted successfully"'
node --check app/assets/javascripts/financial_records.js
node --check app/assets/javascripts/operational_capabilities.js
node --check app/assets/javascripts/accounting_transactions.js
ruby -e 'require "yaml"; puts YAML.safe_load_file("docs/openapi.yaml").fetch("openapi")'
RUBOCOP_CACHE_ROOT=tmp/rubocop_cache RBENV_VERSION=3.4.6 rbenv exec ruby bin/rubocop
RBENV_VERSION=3.4.6 rbenv exec bundle exec brakeman --no-pager
```

Automated tests remain intentionally disabled and must not be inferred from these checks.

Run `RBENV_VERSION=3.4.6 rbenv exec ruby bin/format write` after editing Ruby source. Syntax Tree owns
deterministic Ruby layout; RuboCop retains the non-overlapping Rails Omakase lint rules. The formatter covers
application/configuration Ruby, migrations, seeds, Ruby binstubs, `Gemfile`, `Rakefile`, and `config.ru`. It does
not rewrite generated `db/schema.rb`, automated tests, credentials, or non-Ruby assets.

## Explicitly outside the accepted MVP

- Production QuickBooks credentials or calls.
- Multi-user/public API authentication and authorization.
- Internet-facing deployment, TLS, backups, monitoring, alerting, or disaster recovery.
- Full payroll, payroll runs/paychecks, tax calculation/filings/payments, inventory adjustments, purchase/sales
  orders, estimates, credits/refunds, attachments, and reports beyond the five implemented statements.
- Bulk ingestion, background jobs, scheduled sync, or a general accounting integration platform.
- Automated tests, until `ENABLE AUTOMATED TESTS` is explicitly provided.
- Point-in-time snapshot/cursor exports across concurrent QuickBooks changes.

Those are separate product decisions, not incomplete local-sandbox MVP work.
