# Data flow

## Open the financial records dashboard

```mermaid
sequenceDiagram
  participant B as Browser
  participant S as Rails HTML shell
  participant J as Browser JavaScript
  participant A as Rails JSON API
  participant D as PostgreSQL audit ledger
  participant Q as Quickbooks::Client
  participant I as QuickBooks sandbox
  B->>S: GET /connections/:id/journal_entries
  S-->>B: HTML shell + six API URLs (seven operations)
  B->>J: Run financial_records.js
  J->>A: GET /api/v1/.../reports/profit_and_loss
  A->>Q: GET reports/ProfitAndLoss with dates/basis
  Q->>I: Read generated statement
  I-->>Q: Header + Columns + nested Rows
  Q-->>A: Parsed vendor JSON
  A-->>J: 200 normalized report JSON
  J->>A: GET /api/v1/.../accounts
  A->>Q: Query active Accounts
  Q->>I: GET /query (Account)
  I-->>Q: Active Account payloads
  Q-->>A: Parsed vendor JSON
  A-->>J: 200 JSON accounts
  J->>A: GET /api/v1/.../journal_entries?page=1&per_page=25
  A->>Q: Query ordered JournalEntry page (+1 lookahead)
  Q->>I: GET /query (JournalEntry STARTPOSITION/MAXRESULTS)
  I-->>Q: Journal Entry payloads
  Q-->>A: Parsed vendor JSON
  A-->>J: 200 JSON data + filters + pagination
  J->>A: GET /api/v1/.../journal_entry_operations?page=1&per_page=25
  A->>D: Ordered connection operations (+1 lookahead)
  D-->>A: Local audit rows
  A-->>J: 200 JSON data + filters + pagination
  J-->>B: Populate statement, form, QuickBooks table, audit table, and status
```

## Select and export a financial statement

```mermaid
sequenceDiagram
  participant B as CFO browser
  participant J as financial_records.js
  participant A as Rails FinancialReportsController
  participant R as Reports::Query and Parser
  participant H as Quickbooks::Client
  participant Q as QuickBooks sandbox
  participant F as Downloaded CSV file
  B->>J: Select statement and valid dates/basis
  J->>A: GET one fixed /reports/... endpoint
  A->>R: Validate report-specific parameters
  R->>H: GET fixed report path and parameters
  H->>Q: Realm-scoped bearer GET
  Q-->>H: Report JSON
  H-->>R: Parsed Header, Columns, and recursive Rows
  R->>R: Validate decimals and flatten rows with depth
  R-->>A: Immutable normalized report
  A-->>J: 200 report + echoed filters
  J-->>B: Render metadata and ordered table
  B->>J: Download current statement CSV
  J->>J: Quote cells and neutralize formula prefixes
  J->>F: Temporary Blob URL download
  J->>J: Revoke Blob URL
```

Profit & Loss and Cash Flow use inclusive periods capped at six calendar months. Balance Sheet accepts one as-of
date. Only Profit & Loss and Balance Sheet accept Cash/Accrual. Report money cells remain strings from QuickBooks;
neither Rails nor JavaScript calculates statement totals, and no report payload is persisted.

## Filter, paginate, and export read-only data

```mermaid
sequenceDiagram
  participant B as CFO browser
  participant J as financial_records.js
  participant A as Rails read APIs
  participant Q as QuickBooks sandbox
  participant D as PostgreSQL audit ledger
  participant M as Loaded in-memory pages
  participant F as Downloaded CSV file
  B->>J: Apply inclusive transaction dates
  J->>A: GET both page 1 URLs with txn_date_from/to
  A->>Q: Filter/order QuickBooks JournalEntry query
  A->>D: Filter/order connection audit query
  Q-->>A: Journal Entry page
  D-->>A: Audit page
  A-->>J: Independent data + pagination metadata
  J-->>B: Render filtered page 1 for both tables
  B->>J: Load more for one table
  J->>A: GET only that source's next_page
  A-->>J: Next data page + pagination metadata
  J->>M: Append records and de-duplicate by ID
  J-->>B: Render all loaded pages
  B->>J: Apply memo / audit status
  J->>M: Derive visible records without mutation
  M-->>J: Filtered Journal Entries and audit operations
  J-->>B: Render visible rows; no API request
  B->>J: Download a visible-data CSV
  J->>J: Quote cells and neutralize formula prefixes
  J->>F: Temporary Blob URL download
  J->>J: Revoke Blob URL
```

Transaction-date changes are server reads: the QuickBooks API filters native `TxnDate`, while PostgreSQL filters
the original submitted `request_payload.txn_date`. Memo and audit-status changes remain browser-only across the
pages loaded so far. Journal Entry CSV uses one row per debit/credit line; audit CSV uses one row per operation.
Both contain visible loaded rows only. Decimal strings and ISO 8601 source values are copied without financial
calculation.

## Post one financial record

```mermaid
sequenceDiagram
  participant B as Browser
  participant J as Browser JavaScript
  participant R as JSON JournalEntriesController
  participant S as JournalEntries::Submit
  participant A as CreateSubmission
  participant D as PostgreSQL audit ledger
  participant C as JournalEntries::Create
  participant H as Quickbooks::Client
  participant I as QuickBooks sandbox
  B->>J: Submit form and confirm
  J->>R: POST JSON + CSRF + Idempotency-Key UUID
  R->>S: Submit canonical five fields + key
  S->>A: Coordinate typed create
  A->>D: INSERT pending operation (connection + key unique)
  D-->>A: Commit audit reservation
  A->>C: Validate and create with requestid
  C->>H: GET active Accounts
  H->>I: Account query
  I-->>H: Active Account payloads
  H-->>C: Parsed vendor JSON
  C->>C: Verify two different eligible active Accounts
  C->>H: POST /journalentry?requestid=UUID with equal lines
  H->>I: JSON JournalEntry
  I-->>H: Returned JournalEntry ID
  H-->>C: Parsed vendor JSON
  C->>H: GET /journalentry/:id
  H->>I: Readback request
  I-->>H: Created JournalEntry JSON
  H-->>C: Parsed vendor JSON
  C->>C: Verify ID/date/amount/accounts/balance
  C-->>A: Verified entity
  A->>D: Mark succeeded + QuickBooks ID + normalized result
  D-->>A: Commit completed audit evidence
  A-->>S: Result + operation + replay status
  S-->>R: Entity-specific result
  R-->>J: 201 JSON + operation ID + replayed false
  J->>R: GET /api/v1/.../journal_entries
  R-->>J: 200 JSON refreshed records
  J->>R: GET /api/v1/.../journal_entry_operations
  R-->>J: 200 JSON refreshed local audit history
  J-->>B: Render record, audit status, and concise completion status
```

The Journal Entry is a real posting transaction. Its debit and credit effects depend on the selected QuickBooks
account types. QuickBooks remains the accounting source of truth. Rails stores the original canonical request,
request digest, status, QuickBooks entity ID when known, and normalized successful result as audit/idempotency
evidence; this is not a second accounting ledger.

For an existing key, Rails compares the request digest before any QuickBooks call. A matching `succeeded` row is
returned from the stored result with HTTP 200 and `replayed: true`. A different digest or a
`pending`/`rejected`/`uncertain` row returns HTTP 409. This conservative refusal requires human reconciliation
instead of guessing after an interrupted or ambiguous external write.

## OAuth/token storage

OAuth uses the existing encrypted/signed Rails session for temporary state and Active Record Encryption for persisted access/refresh tokens. A token refresh may update only the local `quickbooks_connections` row. Financial records remain in QuickBooks.

## Read and create workforce, tax, or inventory data

```mermaid
sequenceDiagram
  participant B as CFO browser
  participant J as operational_capabilities.js
  participant A as Explicit Rails entity API
  participant S as Entity-specific Submit
  participant C as CreateSubmission
  participant R as Entity Query/Create
  participant D as PostgreSQL audit ledger
  participant H as Quickbooks::Client
  participant Q as QuickBooks sandbox
  B->>J: Open operations page
  J->>A: Four independent GET requests
  A->>R: Run entity-specific query
  R->>H: Request fixed entity query
  H->>Q: Realm-scoped bearer GET
  Q-->>H: Current records and references
  H-->>R: Parsed vendor JSON
  R-->>A: Validated normalized records
  A-->>J: Normalized JSON catalogs
  J-->>B: Tables, constrained selectors, POST enabled per prerequisite
  B->>J: Confirm one create
  J->>A: JSON + CSRF + Idempotency-Key UUID
  A->>S: Fixed entity attributes and connection
  S->>C: Coordinate typed create
  C->>D: Commit pending operation reservation
  C->>R: Run entity-specific validation/create
  R->>H: Requery required references
  H->>Q: Realm-scoped reference GET
  Q-->>H: Current reference data
  H-->>R: Parsed vendor JSON
  R->>H: One POST with requestid UUID
  H->>Q: Entity-specific JSON payload
  Q-->>H: Created entity ID
  H-->>R: Parsed vendor JSON
  R->>H: Entity readback or TaxCode catalog requery
  H->>Q: Realm-scoped verification GET
  Q-->>H: Created record JSON
  H-->>R: Parsed vendor JSON
  R->>R: Verify submitted identity and core fields
  R-->>C: Verified entity
  C->>D: Mark succeeded with ID and normalized result
  C-->>S: Result + operation + replay status
  S-->>A: Entity-specific result
  A-->>J: 201 result + local operation ID
  J->>A: Refresh that entity GET
  A-->>J: Current records
  J-->>B: Created/read-back status and refreshed table
```

Employee and TimeActivity are payroll-adjacent Accounting API records, not payroll processing. Tax create is
limited to a TaxCode using an existing TaxRate. Inventory create uses existing eligible Accounts; it does not
create purchases, sales, or adjustments. The common coordinator manages only idempotency/audit state. Every
payload, current-reference check, and readback rule remains in the entity namespace.

## Read and create customers, vendors, sales, or payables

```mermaid
sequenceDiagram
  participant B as CFO browser
  participant J as accounting_transactions.js
  participant A as Explicit Rails entity API
  participant S as Entity-specific Submit
  participant C as CreateSubmission
  participant R as Entity Query/Create
  participant D as PostgreSQL audit ledger
  participant H as Quickbooks::Client
  participant Q as QuickBooks sandbox
  B->>J: Open sales and payables page
  J->>A: Six independent GET requests
  A->>R: Query records and valid reference choices
  R->>H: Fixed entity queries
  H->>Q: Realm-scoped bearer GETs
  Q-->>H: Current Customers, Vendors, transactions, Items, and Accounts
  H-->>R: Parsed vendor JSON
  R-->>A: Validated decimal/date-safe catalogs
  A-->>J: Normalized JSON
  J-->>B: Tables and constrained forms
  B->>J: Confirm one create
  J->>A: JSON + CSRF + Idempotency-Key UUID
  A->>S: Permitted entity attributes
  S->>C: Coordinate fixed operation/entity pair
  C->>D: Commit pending operation reservation
  C->>R: Run entity-specific create
  R->>H: Requery current referenced records
  H->>Q: Reference GETs
  Q-->>H: Active or open records
  H-->>R: Parsed vendor JSON
  R->>H: POST one entity with requestid UUID
  H->>Q: Documented entity payload
  Q-->>H: Created entity ID
  H-->>R: Parsed vendor JSON
  R->>H: GET created entity by ID
  H->>Q: Readback request
  Q-->>H: Created entity JSON
  H-->>R: Parsed vendor JSON
  R->>R: Verify IDs, dates, decimal amounts, links, and references
  R-->>C: Verified entity
  C->>D: Mark succeeded with ID and normalized result
  C-->>S: Result + operation + replay status
  S-->>A: Entity-specific result
  A-->>J: 201 result + operation ID
  J->>A: Refresh affected GET catalogs
  A-->>J: Current records and balances
  J-->>B: Readback status and refreshed tables
```

Customer and Vendor are non-posting list records. Invoice and Bill create one accounting line. Payment and
BillPayment apply one decimal amount to one freshly reloaded open source transaction and cannot exceed its
balance.

## Open API documentation

`GET /api-docs` renders a separate Swagger UI page. It fetches `GET /api-docs/openapi.yaml`, which describes the
twenty-nine CFO JSON operations and `GET /health`. Swagger can execute only documented GET operations. All eleven
POST operations are visible but their execution controls are disabled so API exploration cannot create records.

## Dashboard API failure

```mermaid
sequenceDiagram
  participant B as Browser dashboard
  participant A as Rails JSON API
  participant Q as QuickBooks boundary
  B->>A: GET or POST JSON
  alt Local validation or idempotency rejection
    A-->>B: 4xx JSON error envelope
  else QuickBooks request fails
    A->>Q: Validated request
    Q-->>A: Safe typed failure
    A-->>B: 4xx or 5xx JSON error envelope
  end
  B->>A: Related GET reconciliation request
  A->>Q: Read-only QuickBooks request when applicable
  Q-->>A: Current native data or safe failure
  A-->>B: GET result
  B->>B: Show separate POST and GET outcomes
```

Initial Profit & Loss, Accounts, Journal Entries, and local audit-history requests settle independently, so every
failed source can be named while successful sections still render. A report failure marks only the statement
table unavailable. An Accounts failure keeps POST disabled. An audit-history failure marks only its table
unavailable. Safe transient GET failures are retried once after 500 ms. A POST failure preserves the user's form
values, refreshes the related GET projection, and explicitly warns the user to check QuickBooks before retrying
when the external transaction status may be uncertain. No POST is automatically retried.
