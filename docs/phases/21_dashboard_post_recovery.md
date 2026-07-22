# Phase 21 — Dashboard POST recovery and TaxCode applicability

## Outcome

Phase 21 makes the three write-capable dashboards reconcile through their existing GET APIs after every POST
outcome, renews browser idempotency keys only for definitive reusable states, retries safe transient GET failures
once, and prevents a TaxCode applicability mismatch before another sandbox write.

No route, response schema, database object, gem, generic service, or production behavior was added. OpenAPI
v1.5.2 documents the stricter existing-field applicability rule. Automated tests remain disabled.

## Observed TaxCode incident

Before the correction, the user submitted `Test TAX 2` with active TaxRate `3` and `Purchase` applicability. The
QuickBooks TaxService POST returned TaxCode ID `6`. Its collection readback then showed:

```text
name                Test TAX 2
sales_rate_ids      ["3"]
purchase_rate_ids   []
```

Rails returned `quickbooks_tax_code_unexpected` and preserved local operation `36` as uncertain because the
native record did not match the request. This was the safe result. The connected US sandbox's agency for rate `3`
tracks sales but not purchases, consistent with Intuit's separate US and non-US tax models.

Phase 21 does not rewrite operation `36`, relabel TaxCode `6`, delete either record, or send a compensating POST.
The independent GET exposes the native result for operator reconciliation.

## Implemented behavior

- `Quickbooks::TaxCodes::Create` now proves the selected active rate's current TaxAgency advertises the requested
  Sales or Purchase capability before setting `post_attempted` or calling TaxService.
- The operations dashboard derives the applicability options from the selected rate's agency. Rate `3` now offers
  only `Sales` in this sandbox.
- The workforce/tax/inventory, sales/payables, and Journal Entry dashboards execute their related GET refreshes
  after every POST response, including local validation, idempotency conflict, upstream error, and success.
- Each result message distinguishes POST outcome from GET refresh outcome. A successful POST remains confirmed if
  its later dashboard refresh fails; an errored POST remains errored even if GET refresh succeeds.
- Dashboard GET calls retry once after 500 ms only for `quickbooks_timeout` or `quickbooks_unavailable`. POST calls
  are never automatically retried.
- Invalid, rejected, entity-validation, and same-key/different-payload errors receive a new browser UUID. Pending
  and uncertain keys remain held for reconciliation.
- Operational select refreshes preserve still-valid selections so a failure reconciliation GET does not erase
  form choices.

## Read-only acceptance

Codex sent no QuickBooks POST in this phase. A read-only operations-dashboard load returned:

```text
Employees        3
TimeActivities   6
TaxCodes         8
TaxRates         3
TaxAgencies      2
Inventory Items  5
```

All four capability sources loaded, the error alert stayed hidden, and TaxCode IDs `5` (`Test TAX`) and `6`
(`Test TAX 2`) were visible. Selecting California TaxRate `3` produced one enabled applicability option:
`Sales`. No confirmation dialog was accepted and no form was submitted.

## Non-test validation

The final validation used only syntax, formatting, lint, load, security, database-status, documentation, and
read-only runtime checks. No automated test was created, modified, or run. See `docs/phase_status.md` for the
final command results.
