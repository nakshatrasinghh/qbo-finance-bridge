# Phase 8 — Read-only Journal Entry audit history

## Outcome

Phase 8 exposes the existing connection-scoped Journal Entry submission audit evidence as one bounded, read-only
JSON API and renders it as a compact dashboard table. The data comes from PostgreSQL only. Loading or refreshing
the history does not call QuickBooks, change an audit row, or create an accounting transaction.

The CFO API surface is now exactly four operations:

```text
GET  /api/v1/quickbooks/connections/:connection_id/accounts
GET  /api/v1/quickbooks/connections/:connection_id/journal_entries
POST /api/v1/quickbooks/connections/:connection_id/journal_entries
GET  /api/v1/quickbooks/connections/:connection_id/journal_entry_operations
```

No new QuickBooks entity, write path, background job, polling process, generic repository, serializer framework,
or automated test infrastructure was added.

## API behavior

`GET /api/v1/quickbooks/connections/:connection_id/journal_entry_operations` finds the owning local connection and
returns its newest 50 `quickbooks_sync_operations`, ordered by `created_at` and then `id`, both descending. The
association query is explicitly read-only and uses the existing connection/time index.

Each response item contains only the dashboard-safe projection:

- local operation ID and conservative status;
- original transaction date, memo, decimal amount string, debit Account ID, and credit Account ID;
- connection-scoped QuickBooks Journal Entry ID when known;
- safe error code when present;
- ISO 8601 creation and completion timestamps.

The API deliberately does not expose the idempotency key, request digest, raw stored request object, normalized
result object, OAuth tokens, client credentials, authorization data, or vendor response bodies. A missing local
connection uses the existing normalized `404 not_found` JSON response. The API response inherits the API base
controller's `Cache-Control: no-store` policy.

## Dashboard behavior

The existing Rails-rendered dashboard remains an HTML shell. On load, browser JavaScript independently calls the
Accounts API, QuickBooks Journal Entries API, and new local audit-history API. The audit table shows submission
time, status and operation ID, entry date, memo, formatted amount, debit-to-credit Account IDs, and the returned
QuickBooks ID.

An audit API failure produces the existing prominent error banner and an explicit unavailable table state. It
does not disable Journal Entry submission because Accounts availability, not audit display availability,
determines whether the form has valid QuickBooks Account choices. After a known successful or replayed POST, the
browser refreshes both the QuickBooks records table and the local audit table.

## Rails design decision

Current official Rails routing, controller, and Active Record query guidance was reviewed and recorded in
`docs/reference_review.md`. The implementation uses a nested plural resource with one conventional `index`
action, an association-based `select`/`order`/`limit`/`readonly` query, and one small entity-specific serializer.
This keeps connection ownership and the safe response boundary explicit without adding a repository or generic
service hierarchy.

No new Intuit contract was introduced: this phase reads an existing local table and does not invent or map a new
QuickBooks field or entity. `docs/references.md` records that decision.

## Validation evidence

Validation on 2026-07-15 used the existing Phase 6/7 sandbox evidence and made no QuickBooks write:

- Audit API: HTTP `200`, `Cache-Control: no-store`, and exactly one newest-first operation.
- Returned row: operation `1`, status `succeeded`, QuickBooks Journal Entry ID `146`, original Phase 6 date,
  memo, decimal amount `"1.00"`, debit Account `15`, and credit Account `20`.
- Sensitive-boundary check: no idempotency key, request digest, raw request/result payload, access token, or
  refresh token appeared in the JSON response.
- Missing connection: HTTP `404` with normalized code `not_found`.
- Dashboard HTML: contains the generated audit API URL and the local-only audit table shell.
- Browser QA: loaded 87 Accounts, five QuickBooks Journal Entries, and one local audit operation; the alert stayed
  hidden, the table remained compact and readable, and the browser console reported zero warnings or errors.
- Final read-only QuickBooks reconciliation: five Journal Entries remained, with exactly one ID `146`.
- Final local reconciliation: exactly one audit operation remained, operation `1` in `succeeded` state mapped to
  ID `146`.
- Database: all four migrations are `up`; Phase 8 required no schema change.
- OpenAPI: YAML loaded as OpenAPI 3.1.1/version 1.1.0, contains exactly the four CFO operations, and caps the audit
  response at 50 items.
- Static gates: JavaScript and Ruby syntax checks, routes, bundle check, Zeitwerk, and OpenAPI assertions passed;
  RuboCop inspected 56 files with no offenses; Brakeman 8.0.5 reported zero errors and zero warnings.

Automated tests were not created, modified, or run because `ENABLE AUTOMATED TESTS` has not been provided.

## Provenance and accounting effect

Operation `1` is the local Phase 7 backfill for the explicitly approved Phase 6 sandbox Journal Entry `146`. Its
UUID was not used for the original Phase 6 POST. Phase 8 only reads that row and performs a final QuickBooks GET
reconciliation, so it has no accounting effect and adds no new audit record.

## Manual verification

With Rails running locally and the sandbox connection available:

```bash
curl -i http://localhost:3000/api/v1/quickbooks/connections/2/journal_entry_operations
```

Then open:

```text
http://localhost:3000/quickbooks/connections/2/journal_entries
```

The **GET submission audit history** section should show operation `1` as succeeded and QuickBooks ID `146`. The
API contract is available at `http://localhost:3000/api-docs`. Do not submit the form merely to validate this
read-only phase.
