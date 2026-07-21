# Phase 7 — Journal Entry idempotency and audit safety

## Outcome

Phase 7 adds durable, connection-scoped duplicate protection and audit evidence to the existing simple Journal
Entry POST. The dashboard still has one form and the public CFO API surface still has exactly three financial
operations. No new QuickBooks entity, production access, background job, generic sync framework, or automated
test infrastructure was added.

No QuickBooks write was executed during Phase 7 validation. The sandbox Journal Entry count was five before and
after validation.

## Request behavior

`POST /api/v1/quickbooks/connections/:connection_id/journal_entries` now requires a caller-generated UUID in the
`Idempotency-Key` header. The browser creates one UUID for one intended submission and retains it whenever the
outcome may be uncertain.

For a new key, Rails:

1. canonicalizes only `txn_date`, `memo`, `amount`, `debit_account_id`, and `credit_account_id` as stripped strings;
2. calculates a SHA-256 digest in a fixed field order;
3. inserts and commits a `pending` `quickbooks_sync_operations` row scoped to the selected connection;
4. validates the input and active Account IDs through the existing Journal Entry create operation;
5. forwards the same UUID to QuickBooks as the documented `requestid` query parameter;
6. performs the existing QuickBooks POST and readback validation;
7. stores the realm-scoped QuickBooks ID and normalized result as `succeeded` audit evidence.

The database reservation is committed before the external HTTP call. No database transaction is held open while
QuickBooks is called.

For an existing key, Rails performs no new QuickBooks POST:

| Stored/input condition | HTTP result | Meaning |
|---|---:|---|
| Same digest and `succeeded` | `200`, `Idempotency-Replayed: true` | Return the stored normalized result |
| Different digest | `409 idempotency_key_reused` | Refuse to reinterpret a key as a different transaction |
| `pending` | `409 idempotency_request_in_progress` | Refuse a duplicate while processing or after interruption |
| `rejected` | `409 idempotency_request_rejected` | Require corrected data and a deliberately new key |
| `uncertain` | `409 idempotency_outcome_uncertain` | Require QuickBooks reconciliation before any new key |
| Missing/malformed UUID | `422 idempotency_key_invalid` | Reject before creating an audit row or calling QuickBooks |

## Audit states

- `pending`: reserved before QuickBooks; no completion time, result, entity ID, or error.
- `succeeded`: verified readback; requires completion time, QuickBooks entity ID, and nonempty normalized result.
- `rejected`: failed before a confirmed QuickBooks POST; requires completion time and safe error code.
- `uncertain`: a POST may have reached QuickBooks or later readback failed; requires completion time and safe error
  code and may retain a returned QuickBooks ID.

The audit row preserves the five canonical financial inputs and normalized successful output. It never stores an
OAuth token, client secret, authorization header, CSRF value, or raw vendor body. QuickBooks remains the accounting
source of truth; this table is idempotency/reconciliation evidence, not a local general ledger.

## Database safety

PostgreSQL, not a model-only uniqueness validation, enforces the concurrency boundary:

- unique `(quickbooks_connection_id, idempotency_key)`;
- partial unique `(quickbooks_connection_id, quickbooks_entity_type, quickbooks_entity_id)` when the entity ID is
  present;
- foreign key to the owning connection and connection destruction restricted while audit rows exist;
- checks for the one supported operation/entity type, lowercase UUID, SHA-256 digest, JSON-object payloads,
  allowed state, matching completion/error state, non-success empty result, realm-scoped numeric entity ID, and
  complete successful result.

This ensures identical IDs in different QuickBooks connections remain distinct and prevents concurrent duplicate
key insertion inside one connection.

## Research recorded

`docs/reference_review.md` records current Rails guidance for database uniqueness/check constraints and the
`RecordNotUnique` concurrency pattern. `docs/references.md` records official Intuit `requestid`, error-code, and
Journal Entry references. The design adds one explicit `JournalEntries::Submit` coordinator instead of a generic
service base or repository.

## Validation evidence

Validation used the already-approved Phase 6 sandbox Journal Entry only:

- Initial read-only query: five Journal Entries; exactly one entry with ID `146`; date, memo, balance, accounts,
  and amounts remained unchanged.
- Local setup: one `succeeded` audit row, operation `1`, was backfilled for ID `146` with key
  `9c6b15d0-4b5b-4ac1-a342-6f96db92e8e7` and the live normalized read result.
- Important provenance: that UUID was **not** sent during the original Phase 6 QuickBooks POST. The row is
  historical local evidence created solely to validate Phase 7 replay without another financial write.
- Exact HTTP replay: `200 OK`, `Idempotency-Replayed: true`, `replayed: true`, operation `1`, Journal Entry `146`.
- Same key with amount changed from `1.00` to `2.00`: `409 Conflict`, code `idempotency_key_reused`.
- Missing key: `422 Unprocessable Content`, code `idempotency_key_invalid`.
- Final read-only reconciliation: still five Journal Entries, exactly one ID `146`, and exactly one local sync
  operation in `succeeded` state mapped to `146`.
- Lowercase UUID enforcement was checked at the model boundary; PostgreSQL has the matching lowercase UUID check.

The replay request returned from the existing audit row before `JournalEntries::Create` was instantiated. The two
refusal requests stopped even earlier. Therefore none of the three validation POSTs reached the QuickBooks POST
path.

## Static validation

- Both Phase 7 migrations applied successfully and appear `up`.
- Rails Zeitwerk eager loading passed.
- Ruby syntax and JavaScript syntax checks passed.
- Targeted RuboCop passed with no offenses; the final whole-project check is recorded in `docs/phase_status.md`.
- OpenAPI 3.1.1 YAML loaded and the required idempotency parameter was asserted.
- Brakeman 8.0.5 completed with zero errors and zero security warnings.
- Automated tests were not created, modified, or run because `ENABLE AUTOMATED TESTS` has not been provided.
