# Data dictionary

The application has no database. The values below exist only in the Rails process, Rails session, inbound
request, or QuickBooks sandbox.

## `Quickbooks::SandboxConnection`

| Attribute | Type | Sensitivity | Source | Rules | Lifetime |
| --- | --- | --- | --- | --- | --- |
| `id` | UUID string | Opaque handle | Rails `SecureRandom.uuid` | Valid UUID; not an OAuth secret | Until disconnect, restart, reload, or eviction |
| `realm_id` | Numeric string, max 255 | Company metadata | Validated OAuth callback | Sandbox company scope; never caller-selected after connection | Same as connection |
| `access_token` | Nonblank string | Secret | Intuit token endpoint | Server memory only; redacted inspection | Until rotation or connection loss |
| `refresh_token` | Nonblank string | Secret | Intuit token endpoint | Latest rotated value only; server memory only | Until rotation, revoke, or connection loss |
| `access_token_expires_at` | Time | Internal | Token lifetime | Proactive refresh with bounded skew | Same as token generation |
| `refresh_token_expires_at` | Time or nil | Internal | Optional Intuit lifetime | Preserved when refresh omits it | Same as connection |
| `environment` | `sandbox` | Public | Server configuration | Any other value fails closed | Same as connection |
| `created_at` | Time | Internal | Rails | Immutable | Same as connection |
| `updated_at` | Time | Internal | Rails | Replaced on token rotation | Same as connection |
| `last_refreshed_at` | Time or nil | Internal | Rails | Set only on successful refresh | Same as connection |

The object has readers but no writers or persistence API. It exposes no token-bearing serializer and redacts
default inspection.

## Rails session

| Key | Content | Purpose |
| --- | --- | --- |
| `quickbooks_connection_id` | Opaque UUID only | Select the session-owned process-memory connection |
| `quickbooks_oauth_state` | Random value and expiry, temporary | Validate one OAuth callback |

Access tokens, refresh tokens, token responses, Authorization headers, client secrets, and serialized connection
objects must never be stored in the session or cookie.

## Process store

The dedicated MemoryStore uses a namespaced cache key derived only from the non-secret opaque connection UUID.
Connection objects are not persisted or shared across processes. A synchronized lock registry is internal
runtime state and contains no token material.

## Finance request data

Requests accept only the fields declared by their entity-specific strong-parameter and parameter-object
boundaries. Monetary values enter as decimal strings and use `BigDecimal`; dates use strict ISO 8601 parsing.
QuickBooks entity IDs are realm-scoped strings and are never treated as globally unique.

Create flows retain only their local variables for the duration of one request. They do not store:

- request payloads or digests;
- caller idempotency keys;
- replay responses;
- pending/succeeded/rejected/uncertain states;
- audit rows or CSV exports;
- duplicate-name indexes.

The internal QBO `requestid` is a fresh UUID generated once by `Quickbooks::Client#post` and used for one
outbound attempt. Rails includes it in the sanitized structured request log for operational correlation, so it
follows the configured log retention lifecycle. It is not accepted from callers, persisted as replay state, or
reused for another write.

## QuickBooks records

Accounts, reports, Journal Entries, Employees, TimeActivities, TaxCodes, Items, Customers, Vendors, Invoices,
Bills, Payments, and BillPayments remain native QuickBooks sandbox records. Rails reads and normalizes them but
does not mirror or persist them.

POST readback verifies the created entity before returning HTTP 201. Repeating POST can create another native
record because Rails performs no local replay or create-time duplicate-name check.

## Removed data

The former `quickbooks_connections`, `account_mappings`, and `quickbooks_sync_operations` PostgreSQL data is not
migrated. The schema, migrations, Active Record models, encrypted columns, local audit history, and stored replay
payloads are removed. Git retains the historical implementation record.
