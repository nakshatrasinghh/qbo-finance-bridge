# Phase 11 — Local sandbox MVP closeout

## Outcome

Phase 11 closes the simplified local sandbox MVP without adding product behavior. It validates the documented
setup/operator path, confirms the live read-only state, reviews retained legacy artifacts, verifies credential and
source-control boundaries, and adds `docs/operator_handoff.md` as the operational source of truth.

No controller, model, service, route, migration, view, JavaScript behavior, QuickBooks payload, or API schema was
changed. No QuickBooks or local financial/audit write occurred. Automated tests were not created, modified, or
run.

## Acceptance boundary

Accepted:

- local Rails development server;
- one connected QuickBooks Online sandbox company;
- exactly four CFO API operations for Account choices, Journal Entry read/create, and local audit read;
- CompanyInfo readback, safe GET pagination/filtering, CSV of visible loaded rows, API alerts, idempotent Journal
  Entry submission, verified readback, local audit history, and Swagger documentation;
- encrypted Rails credentials and Active Record-encrypted OAuth tokens.

Not accepted or implied:

- production QuickBooks;
- public/network deployment or multi-user authentication;
- automated tests;
- new QuickBooks entities or bulk/background workflows;
- deletion/deactivation of legacy evidence;
- a Git/source-control handoff without an explicitly authorized initial commit.

## Reference review

No new architectural pattern was introduced. The closeout rechecked the official Rails Command Line guide for
the conventional development server/inspection commands and the Rails Security guide for encrypted credentials.
The latter explicitly distinguishes versionable encrypted `credentials.yml.enc` from the master key that must be
kept safe and out of version control. Details are recorded in `docs/reference_review.md`.

No new Intuit capability was implemented. The only Phase 11-specific QuickBooks call was a read-only Account
query confirming the retained demo Account's current sandbox state.

## Clean-start validation

The exact README setup command completed:

```text
RBENV_VERSION=3.4.6 rbenv exec ruby bin/setup --skip-server
```

It found the bundle satisfied, prepared the configured databases, and cleared logs/temp files. Preparing the test
schema is Rails setup behavior; no test command or automated test ran. A subsequent development runner confirmed
that the setup preserved one active connection (ID `2`), one legacy mapping, and one succeeded audit operation
(ID `1`, QuickBooks ID `146`). All four development migrations remained `up`.

The exact README server command booted Rails 8.1.3/Puma 8.0.2 on localhost:

```text
QUICKBOOKS_ENV=sandbox RBENV_VERSION=3.4.6 rbenv exec ruby bin/dev
```

## Browser acceptance

The real operator path was exercised without submitting a form:

1. `/quickbooks/connections` showed one active sandbox connection and no token/secret values.
2. **Inspect** showed successful CompanyInfo readback for the expected sandbox company.
3. **Open financial records dashboard** loaded 87 eligible Accounts, five Journal Entries, and one local audit
   operation through JSON APIs.
4. Both selectors excluded `CFO Bridge Demo Operating Expense`; POST was available for deliberate use but never
   clicked.
5. Journal Entry IDs were `146`, `145`, `8`, `7`, `6`; the failure alert was hidden and the layout had no
   horizontal overflow.
6. Exact date `2026-07-15` made read-only server calls and returned two Journal Entries plus one audit operation;
   clear restored five/one.
7. `/api-docs` rendered OpenAPI 1.2.0/OAS 3.1 with four GET blocks (three CFO GETs plus health) and one POST block.
   Expanding POST showed disabled inputs and zero **Try it out** buttons.

## Legacy cleanup review

A read-only PostgreSQL/QuickBooks reconciliation found:

```text
local mapping ID:       5
source identity:        qbo_cfo_bridge_demo / operating_expense
QuickBooks Account ID:  1150040000
QuickBooks name:        CFO Bridge Demo Operating Expense
QuickBooks type/state:  Expense / active
```

Disposition: retain and explicitly exclude. The mapping has no active route/controller/view or request-flow role.
Deleting it would erase historical evidence but not affect QuickBooks. Deactivating the sandbox Account is an
external write and was not authorized. The existing name exclusion remains necessary while that Account is
active.

## Credential and repository review

- `config/credentials.yml.enc` exists as encrypted ciphertext.
- `config/master.key` exists locally with owner-only file permissions and is ignored by `/config/*.key`.
- `.env*`, logs, temp files, storage, and compiled assets are ignored.
- A filename-first plaintext-secret scan found only the documented placeholder and source-code token/secret
  attribute names; no actual value was emitted or found in application/documentation text.
- OAuth tokens remain encrypted database attributes and are not serialized.
- Git reports `No commits yet on main`; all application files are untracked. No file was staged or committed.
- Four Phase 9 QA CSVs remain in the user's Downloads directory. They are outside the repository, contain sandbox
  financial metadata, and were not deleted without authorization.

The absent initial commit is a handoff task requiring explicit user authorization, not an application-runtime
failure. `docs/operator_handoff.md` records the safe initial-commit preconditions.

## Accounting effect

None. Phase 11 made read-only QuickBooks CompanyInfo, Account, and Journal Entry calls and read local audit/mapping
rows. It did not submit, retry, reverse, deactivate, or delete any accounting or integration record.

## Final verification

Final command results are summarized in `docs/phase_status.md`. The server used for acceptance was stopped after
validation. The local sandbox MVP is closed; no next feature phase is implied.
