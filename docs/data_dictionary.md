# Data dictionary

## `quickbooks_connections`

One row represents authorization for one QuickBooks company in one QuickBooks environment. The composite identity is `(environment, realm_id)`; a realm ID is never treated as globally meaningful without its environment/connection context.

| Field | Type | Null? | Meaning | Example | Security classification | Origin | Index/constraint | Retention |
|---|---|---:|---|---|---|---|---|---|
| `id` | bigint | No | Rails local primary key | `42` | Internal | Local | Primary key | Keep while mappings/sync history later refer to the connection |
| `realm_id` | varchar | No | Intuit QuickBooks company identifier used in API paths | `123456789012345` | Confidential company metadata | OAuth callback | Numeric and max 255 checks; unique with `environment` | Keep with connection/audit history; do not log unnecessarily |
| `environment` | varchar | No | Intuit realm in which the identifier is valid | `sandbox` | Internal | Local configuration | Allowed: `sandbox`, `production`; unique with `realm_id` | Keep; current runtime accepts only `sandbox` |
| `status` | varchar | No | Local connection state | `active` | Internal | Local state transition | Default `active`; allowed `active`, `disconnected`; indexed | Keep to explain authorization history |
| `access_token` | text | Yes | Active Record-encrypted bearer token used for API requests | Ciphertext in PostgreSQL | **Secret** | Intuit token endpoint | Required by DB/model when active; required absent when disconnected; non-deterministically encrypted and parameter-filtered | Clear immediately after successful revoke/disconnect; never serialize or display |
| `refresh_token` | text | Yes | Active Record-encrypted token used only to obtain/revoke authorization | Ciphertext in PostgreSQL | **Secret** | Intuit token endpoint | Required by DB/model when active; required absent when disconnected; non-deterministically encrypted and parameter-filtered | Replace on every returned rotation; clear after successful disconnect |
| `access_token_expires_at` | timestamp | Yes | Absolute local time derived from Intuit `expires_in` | `2026-07-14T14:00:00Z` | Confidential auth metadata | Derived locally from Intuit response | Required when active; absent when disconnected | Clear after disconnect |
| `refresh_token_expires_at` | timestamp | Yes | Absolute rolling expiry derived from `x_refresh_token_expires_in`, when supplied | `2026-10-22T13:00:00Z` | Confidential auth metadata | Derived locally from Intuit response | None; nullable because an upstream response may omit it | Clear after disconnect |
| `granted_scopes` | varchar | No | Scope authorized for this connection | `com.intuit.quickbooks.accounting` | Internal | Requested OAuth scope | Default and model presence validation | Keep with connection history; revisit if multiple scopes are supported |
| `last_refreshed_at` | timestamp | Yes | Last time a refresh response was successfully persisted; initial authorization leaves it null | `2026-07-15T08:30:00Z` | Internal operational metadata | Local after Intuit response | None | Keep for troubleshooting while row exists |
| `disconnected_at` | timestamp | Yes | Time local tokens were cleared after successful remote revocation | `2026-07-20T09:00:00Z` | Internal operational metadata | Local | Required by DB/model when disconnected | Keep with row as authorization-history evidence |
| `lock_version` | integer | No | Rails optimistic-lock version; also changes with token persistence | `3` | Internal | Rails | Default 0, not null | Keep while row exists |
| `created_at` | timestamp | No | First local connection persistence time | `2026-07-14T13:00:00Z` | Internal | Rails | Not null | Keep while row exists |
| `updated_at` | timestamp | No | Most recent local state/token update | `2026-07-15T08:30:00Z` | Internal | Rails | Not null | Keep while row exists |

### Table-level integrity

- Unique index on `(environment, realm_id)` prevents duplicate rows for the same company/environment.
- Status index supports bounded connection-status lists and future operational queries.
- Numeric/length checks reject malformed realm IDs even when model validations are bypassed.
- Environment/status checks prevent unrecognized state values.
- An active row must have encrypted access/refresh values and an access expiry.
- A disconnected row must have `disconnected_at` and must have access token, refresh token, and access expiry cleared.
- Model validations mirror these rules to provide readable application errors before PostgreSQL rejects a write.

### Encryption and key ownership

Tokens are encrypted/decrypted by Active Record Encryption at the model boundary. The database receives
ciphertext. Keys are not columns and are not stored in this table; they come from encrypted Rails credentials or
the three `ACTIVE_RECORD_ENCRYPTION_*` environment variables. Losing those keys makes retained ciphertext
unreadable. Rotating encryption keys requires a deliberate Rails encryption-key rotation plan outside the current
application workflow.

## `quickbooks_sync_operations`

One row reserves one intended allowed create operation for one QuickBooks connection. The fixed allowlist covers
Journal Entries plus ten workforce, tax, inventory, sales, and payables creates. This is a local idempotency/audit
record, not a native QuickBooks entity and not a second accounting ledger. QuickBooks remains the source of truth.

| Field | Type | Null? | Meaning | Example | Security classification | Origin | Index/constraint | Retention |
|---|---|---:|---|---|---|---|---|---|
| `id` | bigint | No | Local audit operation identifier returned by the POST API | `1` | Internal | Rails | Primary key | Retain with the financial-operation audit history |
| `quickbooks_connection_id` | bigint | No | Owning local connection and realm scope | `42` | Confidential company metadata | Local route ownership | Foreign key; unique with key; part of lookup indexes | Retain; connection deletion is restricted while operations exist |
| `operation_type` | varchar | No | Explicit supported operation | `inventory_item_create` | Internal | Rails | Fixed operation/entity pairing check | Retain so meaning does not depend on code version |
| `idempotency_key` | varchar(50) | No | UUID held for one intended transaction and forwarded as Intuit `requestid` | `8f7555b6-0dc4-4ee4-8dc9-9e1fb4fc98b1` | Internal operational metadata | Browser/API caller | UUID check; unique with connection | Retain to prevent a later duplicate |
| `request_digest` | varchar(64) | No | SHA-256 of the operation's explicit canonical request object | 64 lowercase hex characters | Internal integrity metadata | Rails derived | SHA-256 format check | Retain with request payload for key-reuse comparison |
| `request_payload` | jsonb | No | Original explicit canonical fields for the selected operation | JSON object | **Confidential business/financial metadata** | Rails API input | Nonempty JSON object check | Retain as the submitted audit fact; never add tokens/secrets |
| `status` | varchar | No | Conservative operation state | `pending`, `succeeded`, `rejected`, or `uncertain` | Internal operational metadata | Rails state transition | Allowed-values and completion/error-state checks | Retain; unresolved states require reconciliation |
| `quickbooks_entity_type` | varchar | No | Native entity kind fixed for this operation | `Invoice` | Internal | Rails | Pairing check permits only the eleven documented operation/entity combinations | Retain with external ID |
| `quickbooks_entity_id` | varchar | Yes | Realm-scoped QuickBooks ID, when confirmed or returned before a later failure | `146` | Confidential business/financial metadata | QuickBooks response | Safe 1–255 identifier check; uniquely indexed only with connection/entity type when present | Retain; never treat as globally unique |
| `result_payload` | jsonb | No | Normalized successful entity result used for safe replay | Entity JSON object | **Confidential business/financial metadata** | Verified QuickBooks readback | JSON object; nonempty when succeeded | Retain for deterministic replay and audit evidence |
| `error_code` | varchar(64) | Yes | Safe local/upstream code for rejected or uncertain outcomes | `quickbooks_timeout` | Internal operational metadata | Rails error normalization | Present only for rejected/uncertain states | Retain for investigation; raw vendor bodies are not stored |
| `completed_at` | timestamp | Yes | Time a non-pending outcome was recorded | `2026-07-15T15:30:00Z` | Internal operational metadata | Rails | Required unless pending; absent while pending | Retain for chronology and reconciliation |
| `created_at` | timestamp | No | Time Rails reserved the idempotency key before external HTTP | `2026-07-15T15:29:59Z` | Internal operational metadata | Rails | Indexed with connection | Retain for chronology |
| `updated_at` | timestamp | No | Most recent persisted audit-state change | `2026-07-15T15:30:00Z` | Internal operational metadata | Rails | Not null | Retain for chronology |

### Table-level integrity and state transitions

- Unique `(quickbooks_connection_id, idempotency_key)` is the concurrency boundary. The model deliberately has no
  validation-only uniqueness check; concurrent inserts rely on PostgreSQL and handle `RecordNotUnique`.
- `(quickbooks_connection_id, created_at)` supports per-company audit chronology. The partial unique entity index
  always includes connection and entity type, so realm-scoped QuickBooks IDs cannot duplicate inside one company
  and are never queried globally.
- `pending` is inserted and committed before any QuickBooks call. No database transaction spans external HTTP.
- `succeeded` requires `completed_at`, a safe QuickBooks entity ID, a nonempty normalized result, and no error
  code. This result can be replayed only when the stored request digest matches.
- `rejected` and `uncertain` require `completed_at` plus a safe error code. They cannot be replayed into another
  QuickBooks POST under the same key. `uncertain` means human readback/reconciliation is required.
- Request/result payloads intentionally exclude OAuth tokens, client secrets, authorization headers, Rails CSRF
  values, raw QuickBooks response bodies, and arbitrary user JSON.
- `QuickbooksConnection` restricts destruction while audit rows exist. Normal OAuth disconnect changes connection
  state and clears encrypted tokens without deleting audit history.

### Journal Entry audit API projection

`GET /api/v1/quickbooks/connections/:connection_id/journal_entry_operations` returns a bounded page of rows for
the route-owned connection. It exposes operation ID, status, the five original canonical financial fields,
connection-scoped QuickBooks Journal Entry ID when known, safe error code, and creation/completion timestamps. It
does not expose `idempotency_key`, `request_digest`, `result_payload`, connection tokens, or any raw vendor body.
The endpoint reads this table only and has no QuickBooks HTTP path.

### Workforce, tax, and inventory audited create types

The database permits exactly these pairs: `journal_entry_create/JournalEntry`, `employee_create/Employee`,
`time_activity_create/TimeActivity`, `tax_code_create/TaxCode`, and `inventory_item_create/Item`. The Rails model
mirrors the pairing. The unique `(connection, idempotency_key)` and partial unique
`(connection, entity_type, entity_id)` indexes continue to prevent cross-operation key reuse and duplicate
connection-scoped mappings. Existing Journal Entry audit-history GET explicitly filters to
`journal_entry_create`; the endpoint does not expose request payloads or add a generic operation-history surface.

Each new request payload keeps only its canonical allowed form fields. Employee excludes SSN, birth date,
compensation, and address. TimeActivity keeps Employee ID/date/hours/minutes/description. TaxCode keeps
name/rate/applicability. Inventory Item keeps master-data fields, decimal strings, and supporting Account IDs.
Successful results store only the normalized API projection after vendor readback.

Sandbox validation created four succeeded rows: operation `25` Employee `400000001`, operation `26` TimeActivity
`1073741824`, operation `27` TaxCode `4`, and operation `28` Item `19`. Each retains its canonical request and
normalized creation-time readback. Same-key replay returned those stored results and created no additional audit
row or QuickBooks entity. The current audit ledger therefore has twelve rows: eleven succeeded, one rejected, and
none pending or uncertain.

### Sales and payables audited create types

The database and Rails model additionally permit exactly
`customer_create/Customer`, `vendor_create/Vendor`, `invoice_create/Invoice`, `bill_create/Bill`,
`customer_payment_create/Payment`, and `bill_payment_create/BillPayment`. The migration replaces only the fixed
pairing constraint; all UUID, digest, payload, state, connection, and entity-ID constraints remain unchanged.

Customer/Vendor requests retain names and optional contact data. Invoice/Bill requests retain exact dates,
decimal amount strings, description, and realm-scoped references. Payment requests retain one source transaction
ID, date, amount, and, for BillPayment, one bank Account ID. Successful results are the normalized readback
projection.

Sandbox validation created six succeeded rows using these fixed pairs: operation `4` Customer `58`, operation `5` Vendor
`59`, operation `6` Invoice `147`, operation `7` Payment `148`, operation `8` Bill `149`, and operation `9`
BillPayment `150`. Each row retains its original normalized readback for deterministic idempotent replay. That
stored result is intentionally the creation-time fact; for example, Invoice/Bill replay still shows the original
open balance even though later linked payments reduced the current QuickBooks balance to zero. Current state is
read through the entity GET APIs. Same-key replay created no additional audit row or QuickBooks entity.

Operation `24` preserves a later duplicate-Customer browser attempt as `rejected` with
`quickbooks_customer_input_invalid`, no entity ID, and an empty result payload. The active-name lookup stopped the
submission before a QuickBooks Customer POST. Keeping this row is intentional audit behavior; it is not a native
QuickBooks record.

### Browser-only CSV projections

This feature adds no table or persisted field. The browser retains only the current bounded JSON responses and
derives two downloadable projections from the currently visible records:

- Journal Entry CSV: transaction date, connection-scoped QuickBooks ID, document number, memo, balanced flag,
  posting type, unchanged decimal amount string, Account ID/name, and line description. One CSV row represents
  one debit or credit line.
- Audit CSV: operation ID/status, submitted/completed ISO 8601 timestamps, transaction date, memo, unchanged
  decimal amount string, debit/credit Account IDs, connection-scoped QuickBooks ID, and safe error code. One CSV
  row represents one local operation.

The CSV exists only as a temporary browser `Blob`. It is not stored in PostgreSQL or Rails, and it never contains
the idempotency key, request digest, raw request/result objects, OAuth tokens, secrets, authorization data, or raw
vendor bodies. Every value is quoted and guarded against spreadsheet formula prefixes before download.

### Read parameters and pages

This capability adds no table, persisted field, or migration. Both existing read APIs accept transient
`txn_date_from`, `txn_date_to`, `page`, and `per_page` values. Dates are exact ISO `YYYY-MM-DD`; page defaults to 1
and is capped at 10,000; page size defaults to 50 and is capped at 50. Responses echo normalized date filters and
return page metadata, but neither the request nor page state is stored.

The local audit date predicate applies to the preserved canonical Journal Entry date at
`request_payload->>'txn_date'`, not `created_at`. Ordering remains `created_at DESC, id DESC`; the existing
connection/created-at index supports scoping and chronology. No JSON-expression date index was added for the
current one-row audit dataset. That decision should be revisited only with measured growth and a PostgreSQL query
plan. The Journal Entry page is native QuickBooks data and remains unpersisted locally.

### Financial report projections

Financial reports add no table, persisted field, migration, cache, or audit row. Profit & Loss, Balance Sheet, and
Cash Flow are generated by QuickBooks on each GET and normalized transiently into report metadata, column
definitions, and flattened rows. Every row retains its QuickBooks kind/group/depth and ordered cells; realm-scoped
IDs are returned only when QuickBooks supplies them. Money cells are validated with `BigDecimal` and serialized as
their original decimal strings.

The browser holds only the current statement and can create a temporary formula-safe CSV `Blob`. The CSV includes
report type, returned basis when applicable, currency, QuickBooks start/end period, row kind/group/depth, and the
ordered cell strings. It is not stored in Rails or PostgreSQL and contains no OAuth token, client secret, raw
vendor response, or local idempotency data.

General Ledger and Trial Balance reuse this projection unchanged. Trial Balance normalized successfully. The
corrected `reports/GeneralLedger` request also normalized successfully with 8 columns and 452 rows. Neither report
payload is persisted.

## `account_mappings`

> Legacy note: this table remains from the earlier mapping experiment, but the current financial-record dashboard does not read or write it. Its routes, controller, operation, and page were removed. Journal Entries use currently active QuickBooks Account IDs selected directly from the dashboard.

One row represents a deliberate local association from one source-system account code to one currently active QuickBooks Account in one authorized connection. It is integration metadata, not a QuickBooks entity and not a posting record.

| Field | Type | Null? | Meaning | Example | Security classification | Origin | Index/constraint | Retention |
|---|---|---:|---|---|---|---|---|---|
| `id` | bigint | No | Rails local primary key | `17` | Internal | Local | Primary key | Keep while the mapping is approved/in use |
| `quickbooks_connection_id` | bigint | No | Owning local QuickBooks connection/realm | `42` | Confidential company metadata | Local selection | Foreign key; standalone association index; part of both composite indexes | Delete with connection; never use mapping across realms |
| `source_system` | varchar | No | Stable namespace for the inbound ledger/source | `erp` | Internal integration metadata | Manual input | Trim-aware 1–100 check; part of unique source identity | Keep with mapping; matching is case-sensitive |
| `source_account_code` | varchar | No | Stable account identifier within the source system | `6100` | Confidential financial metadata | Manual input | Trim-aware 1–100 check; unique with connection/source system | Keep with mapping; do not silently rename |
| `source_account_name` | varchar | No | Human-readable source account label | `Office expense` | Confidential financial metadata | Manual input | Trim-aware 1–255 check | Keep for review; code, not name, is lookup key |
| `quickbooks_account_id` | varchar | No | Intuit Account entity ID selected from an active query | `15` | Confidential financial metadata | QuickBooks read | Trim-aware 1–255 check; indexed with connection | Keep while mapped; never assume it is a realm ID |
| `quickbooks_account_name` | varchar | No | Name/fully qualified name observed when validated | `Office Expenses` | Confidential financial metadata | QuickBooks read | Trim-aware 1–255 check | Snapshot for review; may become stale |
| `quickbooks_account_type` | varchar | No | QuickBooks Account type observed when validated | `Expense` | Confidential financial metadata | QuickBooks read | Trim-aware 1–100 check | Snapshot for future policy/review |
| `quickbooks_account_subtype` | varchar | Yes | QuickBooks detail type when present | `OfficeGeneralAdministrativeExpenses` | Confidential financial metadata | QuickBooks read | Null or trim-aware 1–100 check | Snapshot; optional because upstream may omit it |
| `last_verified_at` | timestamp | No | Time selected ID was last confirmed in a fresh active Account query | `2026-07-15T00:30:00Z` | Internal operational metadata | Local after QuickBooks read | Not null | Keep; any future posting use must define acceptable age/revalidation |
| `created_at` | timestamp | No | Initial local persistence time | `2026-07-15T00:30:00Z` | Internal | Rails | Not null | Keep with mapping |
| `updated_at` | timestamp | No | Most recent local update time | `2026-07-15T00:30:00Z` | Internal | Rails | Not null | Keep with mapping |

### Table-level integrity and lookup paths

- Unique `(quickbooks_connection_id, source_system, source_account_code)` prevents two targets for the same source identity, including concurrent insert races.
- Non-unique `(quickbooks_connection_id, quickbooks_account_id)` supports reverse display/lookup while allowing several source accounts to consolidate deliberately into one QuickBooks Account.
- Foreign key prevents orphan mappings. The Rails association deletes local mappings if their local connection is deliberately destroyed; this has no remote QuickBooks effect.
- Seven trim-aware checks mirror required/maximum-length model rules for writes that bypass validation.
- `AccountMapping.indexed_by_source_account_code` resolves a bounded list of at most 1,000 codes with one indexed SQL query, returning a Hash keyed by source code.
- Names/types are validation snapshots. They do not replace the QuickBooks Account as source of truth and may be refreshed/revalidated before a later posting operation.

### Reserved demo mapping

The earlier demo flow reused the same schema rather than adding a demo-only table. One row has a fixed source
identity so repeated actions update it instead of creating a second mapping:

| Field | Reserved/live value | Meaning |
|---|---|---|
| `quickbooks_connection_id` | Current connected sandbox row | Keeps the mapping inside one realm |
| `source_system` | `qbo_cfo_bridge_demo` | Distinguishes application-owned learning data from future inbound ledgers |
| `source_account_code` | `operating_expense` | Stable lookup key for this one demo mapping |
| `source_account_name` | `CFO Bridge Demo Operating Expense` | Human-readable fixed source label |
| `quickbooks_account_id` | `1150040000` in the validated sandbox | Returned QuickBooks Account entity ID, read back after create |
| `quickbooks_account_name` | `CFO Bridge Demo Operating Expense` | QuickBooks name/fully qualified name snapshot |
| `quickbooks_account_type` | `Expense` | Places future postings under expenses on Profit and Loss |
| `quickbooks_account_subtype` | `Travel` in the validated sandbox | Detail type QuickBooks assigned when only the required Expense type was sent; it does not change the primary P&L classification |
| `last_verified_at` | Refreshed on every create/reuse action | Evidence that the ID/name/type were most recently confirmed active |

The unique source-identity index makes this mapping an updateable reservation locally. It is not a full remote
idempotency ledger: QuickBooks name uniqueness plus query-before-create provide only bounded demo protection.
Future arbitrary financial writes require explicit idempotency/audit records rather than copying this name-based
approach.
