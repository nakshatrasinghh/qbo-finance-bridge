# Phase 10 — Read-only server date filtering and pagination

## Outcome

Phase 10 adds one shared, validated read contract to the existing Journal Entry and local audit GET APIs. Both
now accept inclusive transaction-date bounds plus page/page-size values and return explicit pagination/filter
metadata. The dashboard sends date changes to both APIs and loads their later pages independently. Memo, audit
status, and CSV generation remain browser-only across records loaded so far.

The CFO API surface remains exactly four operations:

```text
GET  /api/v1/quickbooks/connections/:connection_id/accounts
GET  /api/v1/quickbooks/connections/:connection_id/journal_entries
POST /api/v1/quickbooks/connections/:connection_id/journal_entries
GET  /api/v1/quickbooks/connections/:connection_id/journal_entry_operations
```

No route, write endpoint, model, table, migration, gem, JavaScript dependency, generic repository, pagination
framework, or automated test infrastructure was added.

## Read contract

The two GETs accept:

| Parameter | Meaning | Default | Valid range |
|---|---|---:|---|
| `txn_date_from` | Inclusive original Journal Entry date lower bound | none | exact ISO `YYYY-MM-DD` |
| `txn_date_to` | Inclusive original Journal Entry date upper bound | none | exact ISO `YYYY-MM-DD` |
| `page` | One-based page | `1` | integer `1`–`10000` |
| `per_page` | Returned records per page | `50` | integer `1`–`50` |

The start date cannot follow the end date. Invalid input returns HTTP 422 with
`quickbooks_read_parameters_invalid`; invalid strings are never interpolated into QuickBooks query text or SQL.
Controllers explicitly permit only these four values and delegate validation/calculation to
`Quickbooks::JournalEntries::ReadParameters`.

Successful responses retain their existing top-level data array and add:

```json
{
  "pagination": {
    "page": 1,
    "per_page": 25,
    "returned_count": 25,
    "has_more": true,
    "next_page": 2
  },
  "filters": {
    "txn_date_from": "2026-07-01",
    "txn_date_to": "2026-07-31"
  }
}
```

Each reader requests `per_page + 1`, exposes at most `per_page`, and uses the lookahead only to compute
`has_more`/`next_page`. It does not issue a separate count request.

## Store-specific query behavior

The QuickBooks reader builds:

```text
SELECT * FROM JournalEntry
WHERE TxnDate >= '<from>' AND TxnDate <= '<to>'
ORDERBY TxnDate DESC, Id DESC
STARTPOSITION <one-based position> MAXRESULTS <per_page + 1>
```

Only present date predicates are included. `Quickbooks::Client` still supplies the connected sandbox realm,
minor version, bearer token, error normalization, and refresh behavior.

The local audit reader begins at `connection.quickbooks_sync_operations`, applies optional predicates to the
preserved original `request_payload->>'txn_date'`, orders by `created_at DESC, id DESC`, then applies
`offset`/`limit` and `readonly`. The API date therefore has the same accounting meaning on both endpoints: the
Journal Entry's date, not the audit submission timestamp. The local path never instantiates a QuickBooks client.

No JSON-expression index was added for the current one-row audit dataset. The existing connection/created-at
index already supports ownership and chronology. A date index should be reconsidered only after real growth and
an `EXPLAIN` plan show a current need.

## Dashboard behavior

The dashboard uses `per_page=25` and keeps independent pagination state for the QuickBooks and local tables.

- Applying/clearing either date calls both GET APIs at page 1 with the normalized bounds.
- Applying only memo/status derives new visible arrays locally and explicitly says no API request was made.
- A **Load more Journal Entries** or **Load more audit operations** button is shown only when that response has a
  `next_page`; clicking it calls only the relevant GET and appends the response.
- Appends de-duplicate by the connection-scoped record ID before rendering.
- CSV still contains visible loaded records only, not an implied complete server-side export.
- A failure loading one next page shows the existing alert without discarding pages already rendered in the
  other table.

Offset and QuickBooks `STARTPOSITION` pagination are intentionally small and understandable. A concurrent insert
can move later offsets. Stable ordering and browser de-duplication avoid displaying a duplicate, but this is not
a point-in-time snapshot. A cursor/snapshot export requires a later explicit phase if stakeholders need that
property.

## Reference and API contract review

`docs/reference_review.md` records the official Rails Action Controller and Active Record query guidance, plus
Intuit query/`TxnDate` guidance inspected before implementation. `docs/references.md` records the exact Intuit
capabilities used. The OpenAPI 3.1.1 contract is versioned `1.2.0` and documents all four parameters, metadata
objects, and HTTP 422 responses for both existing GET operations.

## Validation evidence

Live read-only API validation on 2026-07-15 used connection `2`:

- Journal Entry page 1 at size 2 returned IDs `146`, `145`, `has_more: true`, `next_page: 2`.
- Page 2 returned IDs `8`, `7` with `next_page: 3`.
- Exact date `2026-07-15` at size 1 returned ID `146` and echoed both date filters.
- Exact-date audit page 1 returned operation `1`; page 2 was empty with `has_more: false`.
- `page=0`, `per_page=51`, non-ISO dates, and a reversed range each returned the stable HTTP 422 error.
- An independent live QuickBooks query using both date bounds, deterministic two-column ordering, start position,
  and maximum results returned IDs `146`, `145`, and `8` in the expected order.

Browser validation used the real Rails dashboard:

- Production page size 25 loaded 87 Accounts, five Journal Entries, and one audit operation with no alert.
- Exact date `2026-07-15` triggered server reads and rendered two Journal Entries plus one audit operation.
- Memo `controlled sandbox` then rendered one of two Journal Entries and one of one audit operation and explicitly
  reported that no API request was made.
- Audit status `rejected` changed only the audit view to zero of one.
- Clear refetched page 1 without date bounds and restored five/one.
- A temporary QA page size of 2 exercised Journal Entry pages 1, 2, and 3: loaded counts advanced 2 → 4 → 5,
  IDs stayed ordered and unique, and the button disappeared after the final page. The source was restored to 25.
- Final layout had no horizontal overflow, both load-more buttons were hidden for the five/one dataset, and the
  failure alert was hidden.

Final reconciliation and static checks are summarized in `docs/phase_status.md`. Phase 10 made zero QuickBooks
writes and zero local financial/audit writes. Automated tests were not created, modified, or run because they
remain explicitly deferred.

## Manual verification

Run Rails and open:

```text
http://localhost:3000/quickbooks/connections/2/journal_entries
```

Apply an exact transaction date and confirm the top status says server date filters were loaded. Add only a memo
or status value and confirm it says no API request was made. Direct API callers can inspect `pagination.next_page`
or use the dashboard's conditional **Load more** buttons. Do not submit the Journal Entry form merely to validate
this read-only phase.
