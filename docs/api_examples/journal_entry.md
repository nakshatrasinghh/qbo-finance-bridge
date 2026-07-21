# Journal Entry example

## Read a filtered page

Both Journal Entry and local audit GETs accept inclusive transaction dates plus a bounded page:

```text
GET /api/v1/quickbooks/connections/:connection_id/journal_entries?txn_date_from=2026-07-15&txn_date_to=2026-07-15&page=1&per_page=1
```

A successful QuickBooks response is shaped as:

```json
{
  "journal_entries": [
    {
      "id": "146",
      "txn_date": "2026-07-15",
      "doc_number": null,
      "memo": "CFO Bridge controlled sandbox validation phase 6 2026-07-15",
      "balanced": true,
      "lines": [
        {
          "posting_type": "Debit",
          "amount": "1.0",
          "account_id": "15",
          "account_name": "Office Expenses",
          "description": "CFO Bridge controlled sandbox validation phase 6 2026-07-15"
        },
        {
          "posting_type": "Credit",
          "amount": "1.0",
          "account_id": "20",
          "account_name": "Supplies",
          "description": "CFO Bridge controlled sandbox validation phase 6 2026-07-15"
        }
      ]
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 1,
    "returned_count": 1,
    "has_more": true,
    "next_page": 2
  },
  "filters": {
    "txn_date_from": "2026-07-15",
    "txn_date_to": "2026-07-15"
  }
}
```

Journal Entries are ordered by `TxnDate DESC, Id DESC`. A direct API call defaults to page 1 and 50 records;
`page` accepts 1–10,000 and `per_page` accepts 1–50. Dates must be exact ISO `YYYY-MM-DD`, and the start cannot be
after the end. Invalid input returns HTTP 422 with `quickbooks_read_parameters_invalid`.

## Create one Journal Entry

The browser submits JSON to this Rails API route:

```text
POST /api/v1/quickbooks/connections/:connection_id/journal_entries
```

Required request headers include the Rails session/CSRF values used by the same-origin dashboard and one
caller-generated UUID for the intended transaction:

```http
Content-Type: application/json
Idempotency-Key: 8f7555b6-0dc4-4ee4-8dc9-9e1fb4fc98b1
X-CSRF-Token: [RAILS TOKEN]
```

JSON body:

```json
{
  "journal_entry": {
    "txn_date": "2026-07-15",
    "memo": "Monthly adjustment",
    "amount": "100.00",
    "debit_account_id": "<ACTIVE_QBO_ACCOUNT_ID>",
    "credit_account_id": "<DIFFERENT_ACTIVE_QBO_ACCOUNT_ID>"
  }
}
```

Rails first stores the key, a SHA-256 digest of the five canonical fields, and the preserved request payload in a
connection-scoped audit row. It commits that row before any external request. Rails then validates the form and
active Account IDs and sends this shape to QuickBooks:

```json
{
  "TxnDate": "2026-07-15",
  "PrivateNote": "Monthly adjustment",
  "Line": [
    {
      "Description": "Monthly adjustment",
      "Amount": 100.0,
      "DetailType": "JournalEntryLineDetail",
      "JournalEntryLineDetail": {
        "PostingType": "Debit",
        "AccountRef": { "value": "<DEBIT_ACCOUNT_ID>" }
      }
    },
    {
      "Description": "Monthly adjustment",
      "Amount": 100.0,
      "DetailType": "JournalEntryLineDetail",
      "JournalEntryLineDetail": {
        "PostingType": "Credit",
        "AccountRef": { "value": "<CREDIT_ACCOUNT_ID>" }
      }
    }
  ]
}
```

QuickBooks endpoint:

```text
POST /v3/company/<realmId>/journalentry?requestid=8f7555b6-0dc4-4ee4-8dc9-9e1fb4fc98b1&minorversion=75
```

After QuickBooks returns the ID, Rails performs:

```text
GET /v3/company/<realmId>/journalentry/<returnedId>?minorversion=75
```

Success is shown only when the readback matches the date, amount, selected debit/credit accounts, and balanced
totals. The local audit row then stores `succeeded`, the realm-scoped QuickBooks ID, and the normalized response.
Repeating the exact Rails request with the same key returns that stored response with HTTP 200 and
`Idempotency-Replayed: true`, without a QuickBooks call. A different payload or unresolved operation with that key
returns HTTP 409. Tokens and raw vendor bodies are never displayed or stored in the audit payload.

## Read-only local audit history

The dashboard reads recent submission evidence through:

```text
GET /api/v1/quickbooks/connections/:connection_id/journal_entry_operations?txn_date_from=2026-07-15&txn_date_to=2026-07-15&page=1&per_page=50
```

This request reads PostgreSQL only; it does not call QuickBooks. A successful response is shaped as:

```json
{
  "journal_entry_operations": [
    {
      "id": 1,
      "status": "succeeded",
      "txn_date": "2026-07-15",
      "memo": "CFO Bridge controlled sandbox validation phase 6 2026-07-15",
      "amount": "1.00",
      "debit_account_id": "15",
      "credit_account_id": "20",
      "quickbooks_journal_entry_id": "146",
      "error_code": null,
      "created_at": "2026-07-15T15:18:00.000+05:30",
      "completed_at": "2026-07-15T15:18:00.000+05:30"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 50,
    "returned_count": 1,
    "has_more": false,
    "next_page": null
  },
  "filters": {
    "txn_date_from": "2026-07-15",
    "txn_date_to": "2026-07-15"
  }
}
```

The list is connection-scoped and ordered by submission time descending, then local ID descending. Its date
predicate applies to the original submitted Journal Entry date, not the submission timestamp. It intentionally
omits the idempotency key, request digest, stored result payload, OAuth values, and raw QuickBooks data.

## Dashboard filters, pagination, and CSV

The dashboard sends transaction-date changes to both GET operations above and resets both to page 1. Each table
has an independent **Load more** action when its response supplies `next_page`. Memo and audit status remain
browser predicates across loaded pages. Journal Entry CSV expands each visible loaded entry into one row per
line; audit CSV keeps one row per visible loaded operation. CSV export itself never calls Rails or QuickBooks.
