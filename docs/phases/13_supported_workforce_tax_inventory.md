# Phase 13 — Supported workforce, tax, and inventory capabilities

## Outcome

Phase 13 adds eight explicit connection-scoped Rails JSON operations and one separate Rails-rendered dashboard:

```text
GET  /api/v1/quickbooks/connections/:connection_id/employees
POST /api/v1/quickbooks/connections/:connection_id/employees
GET  /api/v1/quickbooks/connections/:connection_id/time_activities
POST /api/v1/quickbooks/connections/:connection_id/time_activities
GET  /api/v1/quickbooks/connections/:connection_id/tax_codes
POST /api/v1/quickbooks/connections/:connection_id/tax_codes
GET  /api/v1/quickbooks/connections/:connection_id/inventory_items
POST /api/v1/quickbooks/connections/:connection_id/inventory_items
```

Together with the seven earlier CFO operations, the public CFO API surface is exactly fifteen operations plus
`GET /health`. The new HTML shell is
`GET /quickbooks/connections/:connection_id/operations`; it performs no QuickBooks exchange while rendering.

## Supported boundary

Current official Intuit documentation was reviewed before implementation and is recorded in
`docs/reference_review.md` and `docs/references.md`. The dedicated Payroll API is closed beta and this sandbox's
CompanyInfo reports `PayrollFeature=false`. Phase 13 therefore supports only public Accounting API Employee and
employee TimeActivity records. It does not run payroll, calculate wages, create paychecks, manage compensation,
deductions or benefits, or submit payroll taxes.

Tax support reads TaxCodes, TaxRates, and TaxAgencies and creates one TaxCode from one existing active rate for
Sales or Purchase. It does not create rates/agencies, calculate transaction tax, submit returns, or make tax
payments. Inventory support reads Inventory Items and eligible supporting Accounts and creates one Inventory Item.
It does not create Accounts, purchases, sales, categories, bundles, or inventory adjustments.

## Implementation

- Four explicit controllers permit only entity-specific documented input and delegate vendor behavior.
- Each entity namespace owns `Query`, `Create`, `Details`, `Serializer`, and `Submit` behavior. Controllers do not
  build QuickBooks payloads or apply accounting policy.
- Employee creation accepts GivenName, FamilyName, optional email, and optional phone only. SSN, birth date,
  address, pay rate, and compensation are neither accepted nor returned.
- TimeActivity creation validates an active current Employee, exact ISO date, whole hours/minutes, a nonzero
  duration, and a bounded description.
- TaxCode creation validates a unique name and one active current TaxRate, posts through TaxService, and queries
  the new code back.
- Inventory Item creation validates exact ISO date, unique name, decimal-string quantity/cost/price with
  `BigDecimal`, and freshly queried eligible sales-income, COGS, and inventory-asset Accounts. JSON decimal values
  do not pass through Ruby floating point.
- Every creator makes exactly one POST and then verifies the returned entity through readback before success.
- `Quickbooks::CreateSubmission` centralizes only connection-scoped UUID reservation, request digest comparison,
  safe replay/refusal, and succeeded/rejected/uncertain audit state. Entity payloads and rules stay outside it.
- Migration `20260721100000` expands the existing database constraint to exactly five operation/entity pairs and
  safely broadens realm-scoped entity IDs. No database transaction spans external HTTP.
- Existing Journal Entry audit history now explicitly filters `journal_entry_create`, so the new operation types
  cannot leak into that entity-specific API.
- API cache prevention now runs before controller actions, so rescued 4xx/5xx JSON failures also retain
  `Cache-Control: no-store`.

No generic entity endpoint, generic service base, repository, internal engine, background job, or second frontend
was introduced.

## Dashboard and API documentation

The operations dashboard starts four GETs independently and renders Employee, TimeActivity, TaxCode/TaxRate, and
Inventory Item tables. It enables each POST only after its required source data has loaded. Every form states the
real sandbox mutation, requests confirmation, sends Rails CSRF plus one browser-generated UUID, preserves an
uncertain key, refreshes only its own source after success, and shows failures in the existing visible alert style.

OpenAPI 3.0.3 document version 1.4.1 documents all fifteen CFO operations and health with exact request/response
schemas. Swagger rendered 16 operations. Its `supportedSubmitMethods` remains GET-only, and browser acceptance
found zero **Try it out** controls for POST.

## Live read acceptance

Connection `2` returned these values through both service-level reads and the new local Rails APIs on 2026-07-21:

| Source | Live result |
|---|---:|
| Active Employees | 2 |
| Recent TimeActivities | 5 |
| TaxCodes | 5 |
| TaxRates | 3 |
| TaxAgencies | 2 |
| Inventory Items | 4 |
| Eligible inventory income/COGS/asset Account choices | 1 / 1 / 1 |

Every GET returned HTTP 200 JSON with `Cache-Control: no-store`. Browser acceptance rendered exactly those row
counts, showed the full-payroll boundary, left the failure alert hidden, and enabled all four form buttons only
after prerequisites were present.

## Write-safety acceptance

Phase 13 deliberately sent no valid Employee, TimeActivity, TaxCode, or Inventory Item POST to QuickBooks. Direct
creator validation with a forbidden HTTP client rejected all four malformed inputs with `post_attempted: false`.
Each local HTTP POST was then sent a deliberately invalid idempotency key with valid CSRF/session handling; all
four returned HTTP 422 `idempotency_key_invalid` with `Cache-Control: no-store`. The audit ledger remained exactly
one row, the previously accepted `journal_entry_create` operation.

The four create paths are implemented, documented, idempotent, audited, and readback-gated, but are not claimed as
live-write validated. A first valid sandbox record requires separate explicit approval and exact record details.

## Final non-test verification

```text
bundle check                                      dependencies satisfied
bin/rails db:migrate:status                       all five migrations up
bin/rails routes -g quickbooks                    15 CFO API operations + HTML/OAuth routes present
bin/rails zeitwerk:check                          all is good
bin/rails runner                                  Rails booted; audit ledger count 1
four live Rails GETs                              HTTP 200, no-store, expected counts
four invalid-key Rails POSTs                      HTTP 422, no-store, no audit/vendor write
node --check                                      three JavaScript assets passed
OpenAPI assertion                                 3.0.3 / v1.4.1 / 11 paths / 16 operations / all refs resolve
RUBOCOP_CACHE_ROOT=tmp/rubocop_cache rubocop      91 files, no offenses
bundle exec brakeman --no-pager                   0 errors, 0 warnings
```

Automated tests were not created, modified, or run. Production QuickBooks remains disabled. Nothing was staged or
committed. The temporary local server used for acceptance was stopped after validation.

## Correction review

A follow-up schema consumer reported incompatible types. The contract had used valid OpenAPI 3.1 union types and
`const`, but those constructs are rejected by older/common 3.0-oriented consumers. The contract now declares
OpenAPI 3.0.3, represents nullable values with a scalar `type` plus `nullable: true`, and represents constants as
single-value enums. Endpoint behavior is unchanged; the contract patch version advances from 1.4.0 to 1.4.1.

The architecture and data-flow Mermaid diagrams were also corrected so response arrows pass back through
`Quickbooks::Client`, create flows include `CreateSubmission`, OAuth shows the browser redirect, and Phase 13 no
longer merges entity policy with the audit coordinator. Obsolete empty legacy Account-mapping/demo directories
and the redundant `docs/api_examples/.keep` were removed. Rails/runtime `.keep` files remain intentionally.

The corrected contract passed a local OpenAPI 3.0 compatibility audit covering scalar types, nullable fields,
enums, required properties, local references, reference siblings, unique operation IDs, and path/operation
counts. Swagger rendered all 16 operations as OAS 3.0 with zero schema error panels. All 10 Mermaid blocks passed
local fence/header/participant/arrow/control-block validation after their topology was reviewed against the code.
