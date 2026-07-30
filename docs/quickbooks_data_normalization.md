# QuickBooks data normalization

The bridge does not expose raw QuickBooks responses. It acts as an anti-corruption layer between the
vendor-specific QuickBooks schema and the stable JSON contract used by downstream callers. Hand-written,
entity-specific parsers, validators, and serializers perform the transformation; no generic normalization
library or language model participates in it.

In this document, **normalization** means application-boundary canonicalization: representing equivalent
upstream values and structures in one predictable output form. It does not mean relational-database
normalization such as first, second, or third normal form. Some stages are more precisely described as schema
projection, structural transformation, validation, filtering, or deduplication. They are documented together
because all of them protect the downstream contract from QuickBooks-specific variability.

Where a read parser detects a repeated upstream identifier, that is response-integrity validation only. The
application does not query for an existing name before a create and does not prevent a deliberate repeated POST.

The conceptual boundary is:

```text
Raw QuickBooks JSON
  -> JSON and entity-shape parsing
  -> schema projection and canonical field naming
  -> scalar type and null canonicalization
  -> relationship and collection normalization
  -> structural and semantic contract validation
  -> deterministic stable JSON
```

In the Ruby implementation, `Details.from_payload` normally builds the intermediate record, the entity query
validates it, and `Serializer` constructs the public JSON projection.

## Invoice example

QuickBooks may return:

```json
{
  "Id": "147",
  "DocNumber": "1009",
  "TxnDate": "2026-07-01",
  "DueDate": "2026-07-31",
  "CustomerRef": {
    "value": "42",
    "name": "Acme Ltd"
  },
  "TotalAmt": 1250.5,
  "Balance": 250.5,
  "Line": [
    {
      "DetailType": "SalesItemLineDetail",
      "Amount": 1250.5,
      "Description": "Consulting",
      "SalesItemLineDetail": {
        "ItemRef": {
          "value": "7",
          "name": "Consulting services"
        }
      }
    },
    {
      "DetailType": "SubTotalLineDetail",
      "Amount": 1250.5
    }
  ],
  "MetaData": {},
  "SyncToken": "2",
  "CustomField": []
}
```

The bridge returns:

```json
{
  "id": "147",
  "doc_number": "1009",
  "txn_date": "2026-07-01",
  "due_date": "2026-07-31",
  "customer_id": "42",
  "customer_name": "Acme Ltd",
  "total_amount": "1250.5",
  "balance": "250.5",
  "lines": [
    {
      "description": "Consulting",
      "amount": "1250.5",
      "item_id": "7",
      "item_name": "Consulting services"
    }
  ]
}
```

The entity parser and serializer are implemented in
[`Invoices::Details`](../app/services/quickbooks/invoices/details.rb) and
[`Invoices::Serializer`](../app/services/quickbooks/invoices/serializer.rb).

## Technical terms used in this document

| Operation | Standard data term | Contract effect |
|---|---|---|
| Select and rename supported fields | Schema projection and naming canonicalization | Removes fields outside the application contract and produces one stable snake_case vocabulary. |
| Flatten `*Ref` objects | Reference-object flattening and foreign-key projection | Exposes relationships as predictable identifier/name pairs. |
| Parse monetary values | Numeric type canonicalization | Represents money as arbitrary-precision decimals and serializes it as decimal text. |
| Convert blanks to `null` | Missing-value canonicalization | Gives optional text one unambiguous absent representation. |
| Convert IDs to strings | Lexical identifier canonicalization | Gives every identifier one scalar type. |
| Resolve optional booleans | Boolean domain canonicalization | Produces explicit `true` or `false` values. |
| Normalize arrays and line kinds | Collection cardinality normalization and discriminated-record filtering | Produces arrays containing only supported record variants. |
| Check the canonical record | Structural and semantic contract validation | Rejects incomplete or contradictory upstream responses. |
| Flatten report trees | Hierarchy-preserving tree linearization | Produces ordered rows while retaining nesting depth. |
| Merge tax resources | Catalog consolidation, identity deduplication, and conflict detection | Produces one deterministic, internally consistent tax catalog. |

## The ten ways we normalize QuickBooks data

### 1. Selecting and renaming fields

**Upstream variability.** QuickBooks returns large vendor-owned entity schemas using names such as `Id`,
`TxnDate`, and `CustomerRef`. The response can include transport or synchronization fields that the application
does not use, including `MetaData`, `SyncToken`, and `CustomField`.

**Transformation.** Each serializer is an allowlist. It explicitly projects supported fields and assigns their
canonical snake_case names:

```ruby
{
  id: invoice.id,
  txn_date: invoice.txn_date,
  customer_id: invoice.customer_id,
  total_amount: invoice.total_amount.to_s("F")
}
```

This is two related operations:

- **schema projection** selects the subset belonging to the public application contract;
- **naming canonicalization** maps QuickBooks names to one repository-wide naming convention.

**Output invariant.** A caller sees the same documented fields regardless of additional fields QuickBooks may
add to its upstream representation. Unknown fields do not leak through automatically.

**Why it matters.** The Ruby bridge, rather than QuickBooks, owns the stable contract consumed by the dashboards
and API clients. Upstream schema growth therefore cannot silently increase the data exposed to callers.

### 2. Simplifying nested references

**Upstream variability.** QuickBooks represents relationships as nested reference objects:

```json
{
  "VendorRef": {
    "value": "18",
    "name": "Office Supplies Ltd"
  }
}
```

The container name and nesting path vary by entity. A Bill uses `VendorRef`; a sales line contains
`SalesItemLineDetail.ItemRef`; a Journal Entry line contains `JournalEntryLineDetail.AccountRef`.

**Transformation.** The parser extracts the relationship identifier and optional display label into ordinary
fields:

```json
{
  "vendor_id": "18",
  "vendor_name": "Office Supplies Ltd"
}
```

This is **reference-object flattening**. The identifier is a **foreign-key projection**, while the accompanying
name is a human-readable label copied from the upstream reference.

**Output invariant.** Customer, Vendor, Employee, Account, Item, TaxAgency, Invoice, Bill, and payment-account
relationships use predictable `*_id` and, where available, `*_name` fields.

**Why it matters.** Downstream code does not need entity-specific knowledge of QuickBooks reference envelopes
or nested paths to identify and display a relationship.

### 3. Keeping financial numbers exact

**Upstream variability.** Monetary amounts, balances, prices, costs, quantities, and tax rates can cross the JSON
boundary as numbers or strings. Ruby floating-point arithmetic is inappropriate for exact financial values.

**Transformation.** Parsers convert supported numeric values to `BigDecimal`:

```ruby
BigDecimal(value.to_s, exception: false)
```

Serializers then emit non-exponential decimal text:

```ruby
amount.to_s("F")
```

For example:

```json
{"amount": "1250.5"}
```

This is **numeric type canonicalization**: accepted lexical forms converge on one internal numeric domain and one
wire representation. The bridge does not promise a fixed display scale, so `"1250.5"` and not necessarily
`"1250.50"` is the canonical output.

**Output invariant.** Financial numbers used by the bridge are validated as arbitrary-precision decimals and
leave the bridge as JSON strings in ordinary decimal notation.

**Why it matters.** Ruby and downstream callers do not need to perform financial calculations using binary
floating-point values. Invalid decimal input becomes `nil` during tolerant parsing and is then rejected by
contract validation.

### 4. Handling blank and missing values

**Upstream variability.** An absent optional text value may appear as a missing key, `null`, an empty string, or
whitespace.

**Transformation.** Optional text fields use Rails `presence`:

```ruby
company_name: payload["CompanyName"].presence
```

Blank representations converge on `nil`, which JSON serializes as `null`:

```json
{"company_name": null}
```

This is **missing-value canonicalization**, not data imputation. The bridge does not invent a replacement value.

**Output invariant.** Optional blank text has one absent representation: JSON `null`. Required fields are
validated separately and cannot become silently optional.

**Why it matters.** Callers do not need separate branches for missing, `null`, empty, and whitespace-only forms.

### 5. Keeping identifiers consistent

**Upstream variability.** QuickBooks identifiers are opaque identifiers even when they contain only digits.
Different parsing paths could otherwise treat them as either numeric or textual values.

**Transformation.** Entity and reference identifiers are converted to strings:

```ruby
id: payload["Id"].to_s
```

**Lexical canonicalization** means choosing one textual representation without interpreting the identifier as a
number:

```json
{"id": "147"}
```

**Output invariant.** QuickBooks entity identifiers and foreign keys are strings everywhere in the stable
contract. Required identifiers are checked for the entity-specific accepted format before serialization.

**Why it matters.** Leading zeros, large values, and opaque identifier semantics are not subjected to numeric
comparison or arithmetic.

### 6. Making true and false values explicit

**Upstream variability.** Some QuickBooks boolean fields are explicitly present; others may be absent and carry
entity-specific default semantics.

**Transformation.** Parsers map the upstream field into the two-value Boolean domain using rules defined for
that entity:

```ruby
taxable: payload["Taxable"] == true
active: payload["Active"] != false
```

This is **Boolean domain canonicalization**. The first rule is true only for an explicit upstream `true`; the
second treats anything except an explicit `false` as active. These are deliberately different semantics.

**Output invariant.** The serialized field is always JSON `true` or `false`, never an object, string, or implicit
Ruby truthiness result.

**Why it matters.** Callers receive the intended domain meaning rather than having to infer whether absence
means false, true, or unknown for each QuickBooks entity.

### 7. Standardizing lists and supported line types

**Upstream variability.** QuickBooks may omit an empty collection, return `null`, or return an array containing
multiple line variants distinguished by `DetailType`.

**Transformation.** `Array(...)` normalizes a missing collection to an empty array while preserving an existing
array:

```ruby
Array(payload["Line"])
```

The parser then uses the discriminator to project only supported variants:

```ruby
.filter_map do |line|
  next unless line["DetailType"] == "SalesItemLineDetail"
  # Build the supported sales line.
end
```

These are two operations:

- **collection cardinality normalization** guarantees an array-shaped result;
- **discriminated-record filtering** retains only variants the stable contract knows how to represent.

For example, an Invoice projection keeps `SalesItemLineDetail` records and omits subtotal or unsupported line
types. Bills similarly retain account-based expense lines, and Journal Entries retain journal-entry line
details.

**Output invariant.** Public collection fields are arrays, including when empty, and every retained element
matches the documented element schema.

**Why it matters.** Downstream code can iterate without checking for `null`, and unsupported QuickBooks union
variants cannot masquerade as supported financial records.

### 8. Rejecting incomplete or inconsistent data

**Upstream variability.** A successful HTTP response does not guarantee that its JSON has the shape or business
meaning required by this bridge. It may be malformed, incomplete, internally inconsistent, or changed from the
expected QuickBooks contract.

**Transformation.** After parsing, entity queries apply:

- **structural validation** for object/array shapes, field presence, scalar types, and accepted formats;
- **semantic validation** for cross-field rules and domain constraints.

For example, a normalized Invoice requires:

- a valid QuickBooks identifier;
- exact ISO transaction and due dates;
- a Customer identifier;
- valid total and balance decimals; and
- supported line records whose identifiers and amounts satisfy the Invoice projection.

Reports additionally require valid metadata, columns, row/cell alignment, currency, timestamp, dates, basis, and
decimal `Money` cells.

**Output invariant.** Only records satisfying the complete stable-contract predicate are serialized. An
inconsistent upstream success becomes a safe `UnexpectedResponse` error instead of partial financial data.

**Why it matters.** This is a **fail-closed integration boundary**. Missing values are not imputed, malformed
financial values are not coerced to zero, and contradictory records are not returned to callers.

### 9. Turning nested reports into ordered rows

**Upstream variability.** QuickBooks reports encode presentation and accounting hierarchy as recursively nested
`Section`, `Data`, and `Summary` rows. That tree is awkward for pagination, tabular rendering, evidence
extraction, and deterministic traversal.

An upstream section can resemble:

```json
{
  "type": "Section",
  "group": "Expenses",
  "Header": {"ColData": []},
  "Rows": {
    "Row": [
      {"type": "Data", "ColData": []},
      {
        "type": "Section",
        "Rows": {"Row": []},
        "Summary": {"ColData": []}
      }
    ]
  },
  "Summary": {"ColData": []}
}
```

**Transformation.** The report parser performs a depth-first, order-preserving traversal:

1. Emit the section header when present.
2. Recursively process child rows at `depth + 1`.
3. Emit the section summary when present.
4. Preserve the original sibling order.

The resulting flat sequence retains explicit hierarchy metadata:

```json
[
  {
    "kind": "section",
    "group": "Expenses",
    "depth": 0,
    "cells": []
  },
  {
    "kind": "data",
    "group": null,
    "depth": 1,
    "cells": []
  },
  {
    "kind": "summary",
    "group": "Expenses",
    "depth": 0,
    "cells": []
  }
]
```

This is **tree linearization**, not lossless generic flattening: the supported hierarchy is preserved through
`kind`, `group`, `depth`, row order, and aligned cells, while the original QuickBooks envelopes are discarded.

The parser also:

- recursively linearizes nested column groups;
- requires every row to contain the same number of cells as the flattened columns;
- validates each nonblank `Money` cell as a decimal; and
- validates report-level basis, currency, timestamps, dates, and no-data metadata.

**Output invariant.** Reports expose one ordered column vector and one ordered row sequence. Every row aligns
positionally with the columns, and hierarchy can be reconstructed for supported display and evidence use cases.

**Why it matters.** Downstream callers can process a report deterministically without implementing QuickBooks'
recursive report grammar. Rails preserves QuickBooks-provided totals; it does not recalculate them.

See [`Reports::Details`](../app/services/quickbooks/reports/details.rb) and
[`Reports::Serializer`](../app/services/quickbooks/reports/serializer.rb).

### 10. Combining and cleaning tax data

**Upstream variability.** QuickBooks tax configuration is split across TaxCode, TaxRate, and TaxAgency resources.
TaxCode applicability lists also contain nested TaxRate references:

```json
{
  "SalesTaxRateList": {
    "TaxRateDetail": [
      {"TaxRateRef": {"value": "12"}},
      {"TaxRateRef": {"value": "15"}}
    ]
  }
}
```

**Transformation.** The bridge:

1. Queries TaxCode, TaxRate, and TaxAgency separately.
2. Parses each resource into its canonical record type.
3. Converts nested TaxRate references into identifier arrays:

   ```json
   {
     "sales_rate_ids": ["12", "15"]
   }
   ```

4. Consolidates the three collections into one tax catalog.
5. Deduplicates records by QuickBooks identifier.
6. Accepts repeated identifiers only when the complete normalized records are identical.
7. Rejects the response when one identifier maps to conflicting normalized records.
8. Sorts each collection by its canonical display field.

This combines **catalog consolidation**, **identity-based deduplication**, **conflict detection**, and
**deterministic ordering**.

**Output invariant.** Each tax collection contains at most one canonical record per QuickBooks identifier; a
duplicate cannot silently overwrite conflicting data, and output order does not depend on upstream response
order.

**Why it matters.** Downstream callers receive a reproducible, internally consistent tax catalog even when
QuickBooks repeats records across query results.

See [`TaxCodes::Details`](../app/services/quickbooks/tax_codes/details.rb),
[`TaxCodes::Query`](../app/services/quickbooks/tax_codes/query.rb), and
[`TaxCodes::Serializer`](../app/services/quickbooks/tax_codes/serializer.rb).

## What this normalization does not do

This is structural and contract normalization. It does not perform question-specific aggregation, financial
interpretation, forecasting, currency conversion, or language-model reasoning. Those concerns belong outside
the Ruby QuickBooks adapter.
