# Phase 22 status — Phase 21 GitHub handoff complete

Phase 22 is complete. The validated Phase 21 dashboard recovery and TaxCode applicability changes are committed
on `main` with the authorized lowercase message and pushed normally to the canonical GitHub repository. No later
phase has started or is implied.

| Item | Final status |
|---|---|
| Product boundary | Local QuickBooks sandbox only; production remains out of scope |
| Canonical repository | `https://github.com/nakshatrasinghh/qbo-finance-bridge.git` |
| Branch | `main`, tracking `origin/main` |
| Remote preflight | Local and remote both started Phase 22 at `83e9cde`; no upstream history required merging |
| Commit message | `fix: improve dashboard api recovery` |
| Included application change | Related GET refresh after every dashboard POST outcome; POST never auto-retried |
| Included transient recovery | One browser retry for `quickbooks_timeout` or `quickbooks_unavailable` GET failures |
| Included idempotency change | Definitive invalid/rejected/reused-input states renew browser keys; uncertain keys remain held |
| Included TaxCode change | TaxRate agency capability is required and presented before Sales/Purchase submission |
| Existing sandbox evidence | TaxCodes `5` and `6`, plus uncertain operations `33` and `36`, remain unchanged |
| Phase 21 runtime acceptance | 4/4 capability GET sources loaded; incompatible Purchase validation stopped before POST |
| Formatter/lint/load | Syntax Tree, JavaScript syntax, RuboCop, and Rails Zeitwerk passed |
| Database | All six migrations remain `up`; no migration was added |
| Security/dependencies | Brakeman, Bundler Audit, and Importmap Audit passed |
| OpenAPI | v1.5.2 parsed as OpenAPI 3.0.3 with 19 paths; routes/shapes unchanged |
| Candidate integrity | Staged diff and whitespace review passed; no raw secret/private-key pattern detected |
| Additional QuickBooks requests | None in Phase 22 |
| Automated tests | Intentionally not created, modified, or run |
| Push policy | Normal `main` push only; no force push |

Implementation and runtime evidence: `docs/phases/21_dashboard_post_recovery.md`. Git handoff evidence:
`docs/phases/22_phase21_git_handoff.md`. Operator guidance: `docs/operator_handoff.md`.
