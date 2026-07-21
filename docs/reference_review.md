# Reference review

## Current implementation decision

The application is a conventional Rails monolith with three QuickBooks operation pages and twenty-nine versioned JSON
operations. The ERB routes render only frontend shells; vanilla JavaScript exchanges JSON with namespaced API
controllers. Entity-specific plain Ruby objects translate QuickBooks data, the existing `Quickbooks::Client`
owns vendor HTTP, and `QuickbooksConnection` stores encrypted OAuth state.

## Official Rails references

- [Action Controller Overview](https://guides.rubyonrails.org/action_controller_overview.html): conventional resource actions, permitted JSON parameters, CSRF protection, and JSON rendering. Adopted by the explicit API controllers; HTML controllers render shells only.
- [Rails Routing](https://guides.rubyonrails.org/routing.html): namespaces, nested resource ownership, and `only`-limited routes. Adopted under `/api/v1/quickbooks` with twenty-nine fixed connection-scoped operations.
- [Rails Asset Pipeline](https://guides.rubyonrails.org/asset_pipeline.html): Rails 8 Propshaft serves browser-ready JavaScript and CSS from application asset paths. Adopted for the small Swagger initializer without introducing a Node build.
- [Active Record Encryption](https://guides.rubyonrails.org/active_record_encryption.html): encrypted token attributes and credential-owned keys. Adopted for access/refresh tokens.
- Rails/Zeitwerk conventions: file paths match constants; no custom autoloading, base service class, repository layer, or dependency container was added.

## Official QuickBooks references

See `docs/references.md`. The implementation follows Intuit's OAuth, realm-scoped REST, query, Account, and JournalEntry contracts. One balanced JournalEntry request contains both a positive debit and equal positive credit with Account references.

## Mature Rails patterns retained

- Mastodon `app/lib/request.rb` at commit `d70f1f983c945b3aa4c2089e540c67d706d762d9`: one HTTP boundary owns timeouts/error translation/instrumentation. Adapted into the existing QuickBooks-specific client; arbitrary-host federation machinery is not copied.
- Discourse `app/controllers/users/omniauth_callbacks_controller.rb` at commit `939248f3690e3557207a3e4cd90bb7760201d4b0`: thin callback/controller delegation. Adapted for the OAuth browser flow; a generic provider framework is not needed.

## OpenAPI references reviewed for Phase 4

- [OpenAPI Specification 3.0.3](https://spec.openapis.org/oas/v3.0.3.html): paths, path parameters, schemas, reusable responses, nullable values, and operation security. The checked-in contract uses 3.0.3-compatible scalar types and single-value enums because downstream 3.0-oriented validators rejected 3.1 union types and `const` as incompatible.
- [Official Swagger UI installation](https://swagger.io/docs/open-source-tools/swagger-ui/usage/installation/): `swagger-ui-dist` is the server-side/static distribution and supports configuration with a specification URL and DOM element. Adopted with the pinned `5.32.8` browser distribution.

`rswag` was not introduced because this project has not enabled automated tests and does not need a test-driven documentation DSL. The contract stays framework-neutral YAML, the Rails controller only serves it, and a tiny browser initializer configures Swagger UI. Interactive submission is restricted to GET so the documentation page cannot create a QuickBooks transaction.

## Simplicity decisions

- Removed: demo Account controller/service/route/view.
- Removed: account mapping controller/service/routes/view from the active product.
- Not added: generic financial-entity framework, background jobs, SDK, local JournalEntry table, JavaScript SPA, Redis, Packwerk, or microservice.
- Kept: Account query, because QuickBooks requires Account IDs for JournalEntry lines.
- Kept: one small `JournalEntries::Create` object, because validation, payload construction, QuickBooks POST, and readback do not belong in the JSON controller or Active Record model.
- Kept: one small `JournalEntries::Query` and immutable `Details`, because the view should not parse vendor JSON.

This is the minimum separation that keeps the browser action readable and prevents QuickBooks transport/accounting payload code from spreading through the controller and view.

## Phase 4 architecture review checkpoint

- Namespace boundaries remain clear: HTML controllers render shells, versioned API controllers own JSON, entity-specific objects own QuickBooks translation, and one client owns Faraday.
- Dependency direction remains one-way from browser to Rails API to entity operation/query to `Quickbooks::Client`; models and vendor HTTP do not depend on controllers or views.
- Repeated orchestration and payload logic are not present across the three CFO operations, so no generic service base, repository, engine, or Packwerk boundary is justified.
- Normalized QuickBooks error rendering remains centralized in the API base controller, while vendor HTTP error mapping remains centralized in the client.
- The OpenAPI contract is documentation, not a second implementation. It adds no runtime QuickBooks path and no write capability.

Decision: retain the small Rails monolith and current namespaces. No modularity refactor is approved or needed at this checkpoint.

## Phase 5 failure-notification decision

The existing normalized Rails JSON error envelope is sufficient. The dashboard now presents it with a native
`role="alert"` region, a dismiss button, and explicit unavailable states for failed startup data. No toast gem,
JavaScript framework, polling loop, or new Rails layer was introduced. `Promise.allSettled` is used only because
Accounts and Journal Entries load independently and both failure messages should remain visible when both fail.

## Phase 7 idempotency and integrity review

- [Active Record Migrations](https://guides.rubyonrails.org/active_record_migrations.html): current Rails guidance
  for unique indexes, foreign keys, check constraints, and reversible migrations. Adopted for the
  connection/key uniqueness rule and audit-state integrity checks.
- [Active Record `create_or_find_by`](https://api.rubyonrails.org/v8.1.1/classes/ActiveRecord/Relation.html): Rails
  documents that concurrency-safe create-or-find behavior depends on a database uniqueness constraint and handles
  `RecordNotUnique`. The submission object follows that principle directly because it must also distinguish a new
  audit reservation from an existing one. There is intentionally no race-prone validation-only uniqueness check.
- [Intuit request ID field definition](https://developer.intuit.com/app/developer/qbpayments/docs/learn/learn-basic-field-definitions):
  Intuit documents the QuickBooks Online Accounting API `requestid` query parameter as the write idempotency key,
  unique per company, with a maximum of 50 characters. A UUID is therefore used as both the Rails
  `Idempotency-Key` and Intuit `requestid`.
- [Intuit QuickBooks error codes](https://developer.intuit.com/app/developer/qbo/docs/develop/troubleshooting/error-codes):
  reviewed duplicate request ID (`600`), invalid request ID (`2130`), and unbalanced Journal Entry (`2300`)
  behavior before changing the write path.

The implementation adds one entity-specific `Quickbooks::JournalEntries::Submit` coordinator and one
`QuickbooksSyncOperation` record. `Submit` owns only idempotency/audit orchestration; the existing `Create` object
still owns accounting validation, payload construction, POST, and readback, while the existing client remains the
only HTTP boundary. The audit reservation is committed before the external call, and no database transaction is
held open while QuickBooks is called. This solves the current duplicate-write risk without adding a generic
service base, repository, background job, engine, or multi-entity sync framework.

## Phase 8 — Read-only Journal Entry audit history

Date reviewed: 2026-07-15
Installed Ruby version: 3.4.6
Installed Rails version: 8.1.3

### Official Rails references

- Source: [Rails Routing from the Outside In](https://guides.rubyonrails.org/routing.html)
- Relevant section: resource routing, controller namespaces, nested resources, generated path helpers, and
  restricting routes with `only`.
- Pattern observed: a collection read is an `index` action on a plural resource; nesting expresses ownership and
  generates helpers instead of hard-coded URLs.
- Applicability: adopted as nested `journal_entry_operations`, `only: :index`, under the existing versioned
  QuickBooks connection namespace.

- Source: [Action Controller Overview](https://guides.rubyonrails.org/action_controller_overview.html)
- Relevant section: conventional actions and rendering JSON responses.
- Pattern observed: controllers receive request parameters, retrieve the resource, and render a response in the
  requested representation.
- Applicability: the new controller has one `index` action, finds the owning connection, performs a bounded local
  association query, and renders the existing normalized JSON boundary.

- Source: [Active Record Query Interface](https://guides.rubyonrails.org/active_record_querying.html)
- Relevant section: association relations, ordering, limiting, read-only retrieval, and method chaining.
- Pattern observed: `order` and `limit` compose on an Active Record relation without raw SQL or a repository layer.
- Applicability: adopted for a newest-first, 50-row maximum query using the existing
  `(quickbooks_connection_id, created_at)` index.

### Official QuickBooks references

- Source: none newly required.
- Relevant endpoint or behavior: none. This phase reads local PostgreSQL audit rows only.
- Pattern observed: not applicable.
- Applicability: no QuickBooks entity support, field mapping, report semantics, or external request was added.

### Mature Rails repositories inspected

No new external mature-application review was needed for Phase 8. The phase repeats the repository's existing
nested API `index` pattern and adds no new architectural mechanism. Copying a serializer framework, pagination
gem, repository, policy layer, or background job from a larger application would not solve a current problem.

### Resulting decision

- Chosen pattern: one nested read-only Rails resource, a bounded connection association query, and one small
  entity-specific serializer that excludes sensitive/internal idempotency fields.
- Why it is idiomatic: resourceful routing, a conventional `index`, Active Record relation chaining, generated
  path helpers, and `render json:` are standard Rails mechanisms already present in this application.
- Why it is appropriate at the current scale: there is one local table, one connection owner, one response shape,
  and a fixed 50-row dashboard requirement.
- Simpler alternatives considered: inline serialization in the controller. Rejected because the safe audit field
  boundary is easier to review and reuse in a named serializer.
- More complex alternatives rejected: generic repositories, pagination gems, presenter frameworks, background
  jobs, polling, Packwerk, engines, and a separate audit application.

## Phase 9 — Read-only CFO filters and CSV export

Date reviewed: 2026-07-15
Installed Ruby version: 3.4.6
Installed Rails version: 8.1.3

### Official Rails references

- Source: [The Rails Asset Pipeline](https://guides.rubyonrails.org/asset_pipeline.html)
- Relevant section: Propshaft browser-ready JavaScript/CSS assets and explicit view inclusion with Rails asset
  helpers.
- Pattern observed: Rails 8 can serve plain browser-compatible JavaScript and CSS from `app/assets` without a
  bundler when the application does not need transpilation or a package dependency.
- Applicability: the existing `financial_records.js` and `application.css` assets remain the correct location for
  small in-browser filtering and export behavior. No JavaScript framework, package manager, or build step was
  introduced.

- Source: [Action View Form Helpers](https://guides.rubyonrails.org/form_helpers.html)
- Relevant section: text, date, and select controls.
- Pattern observed: standard HTML controls represent text/date inputs and a constrained choice list clearly.
- Applicability: the filter panel uses labeled HTML date/search inputs and an explicit status select. It is not a
  server form and JavaScript prevents submission, so it creates no controller parameters, route, or persistence.

### Browser and export safety references

- Source: [MDN `URL.createObjectURL`](https://developer.mozilla.org/en-US/docs/Web/API/URL/createObjectURL_static)
  and [MDN `URL.revokeObjectURL`](https://developer.mozilla.org/en-US/docs/Web/API/URL/revokeObjectURL_static).
- Pattern observed: an in-memory `Blob` can be exposed temporarily through a blob URL, and the object URL should
  be released after use.
- Applicability: CSV content is created from the already-loaded JSON, downloaded through a temporary blob URL,
  and the URL is revoked. No new Rails response, filesystem file, or external request is created.

- Source: [OWASP CSV Injection](https://owasp.org/www-community/attacks/CSV_Injection).
- Pattern observed: untrusted spreadsheet cells beginning with formula-trigger characters require explicit
  neutralization in addition to normal CSV quoting.
- Applicability: every exported value is string-normalized, formula-trigger prefixes are neutralized inside the
  quoted field, embedded quotes are doubled, and every field is quoted. QuickBooks names, memos, descriptions,
  and local error text are therefore not treated as trusted spreadsheet formulas.

### Official QuickBooks references

- Source: none newly required.
- Relevant endpoint or behavior: none. Phase 9 makes no QuickBooks request of its own and adds no entity, field,
  query parameter, or accounting behavior. It only derives filtered views and downloads from the JSON already
  returned by the existing APIs.

### Resulting decision

- Chosen pattern: retain the latest bounded API arrays in page memory, derive visible arrays from four explicit
  controls, render those arrays, and export the same visible arrays with two fixed CSV schemas.
- Accounting safety: filters never alter source values or calculate money. Decimal amount strings are copied to
  CSV unchanged, and Journal Entry lines remain separate debit/credit rows.
- API safety: applying, clearing, or exporting filters makes no fetch call. Initial dashboard loading and the
  existing post-success refresh remain the only data-fetch behavior.
- Simpler alternatives rejected: server-side CSV formats and new export endpoints, because both bounded datasets
  already exist in the browser and the user requested the existing four-API surface.
- More complex alternatives rejected: a grid library, CSV gem, SPA state framework, saved-filter model,
  background export, pagination framework, or generic reporting service.
- Mature Rails repositories: no new external application pattern was inspected because this phase introduces no
  Rails server architecture. Current official Rails and web-platform mechanisms fully cover the bounded local
  behavior.

## Phase 10 — Read-only server date filtering and pagination

Date reviewed: 2026-07-15
Installed Ruby version: 3.4.6
Installed Rails version: 8.1.3

### Official Rails references

- Source: [Action Controller Overview](https://guides.rubyonrails.org/action_controller_overview.html)
- Relevant section: request parameters and permitted parameters.
- Pattern observed: controllers should explicitly permit only the parameters accepted at an HTTP boundary.
- Applicability: both GET controllers permit only `txn_date_from`, `txn_date_to`, `page`, and `per_page`, then
  pass the plain hash to an entity-specific parameter object. They do not implement date or pagination policy.

- Source: [Active Record Query Interface](https://guides.rubyonrails.org/active_record_querying.html)
- Relevant section: `where`, `order`, `limit`, `offset`, `select`, association relations, and read-only records.
- Pattern observed: bounded, ordered pages compose directly on an Active Record relation; a repository or
  pagination gem is unnecessary for one query.
- Applicability: `JournalEntries::AuditHistory` starts with the owning connection association, selects the safe
  columns needed by the serializer, applies optional original-transaction-date predicates, orders by
  `created_at DESC, id DESC`, offsets, reads one lookahead row, and marks returned records read-only.

### Official QuickBooks references

- Source: [QuickBooks Online query operations and syntax](https://developer.intuit.com/app/developer/qbo/docs/learn/explore-the-quickbooks-online-api/data-queries)
- Relevant section: `WHERE`, `AND`, `ORDERBY`, `STARTPOSITION`, and `MAXRESULTS`.
- Pattern observed: supported query properties can be combined with `AND`; pagination is one-based and positive;
  result size is bounded by `MAXRESULTS`.
- Applicability: the Journal Entry read emits only validated ISO dates and integers into an explicit query,
  orders by `TxnDate DESC, Id DESC`, and requests one extra row to compute `has_more`.

- Source: [Intuit transaction `TxnDate` schema](https://static.developer.intuit.com/sdkdocs/qbv3doc/ippdotnetdevkitv3/html/0b5f8961-f32e-e396-3a39-7b3e241434e8.htm)
- Relevant field: `TxnDate` is a filterable and sortable transaction date.
- Applicability: `txn_date_from`/`txn_date_to` constrain the native Journal Entry transaction date, not its API
  retrieval time. The local audit API mirrors that meaning by filtering the preserved submitted transaction date.

### Resulting decision

- Chosen pattern: one immutable `ReadParameters` value validates a four-field read contract and one immutable
  `ReadPage` carries records plus metadata. Two entity-specific readers apply that contract to their own stores.
- HTTP behavior: direct requests default to page 1 and 50 records, cap `per_page` at 50 and `page` at 10,000,
  require exact ISO `YYYY-MM-DD` values, reject reversed ranges, and return HTTP 422 with a stable error code.
- Pagination behavior: each reader retrieves `per_page + 1`, returns only `per_page`, and derives `has_more` and
  `next_page` without issuing a count query. The dashboard uses 25 and loads each table independently.
- Scope and safety: the QuickBooks query remains realm-scoped through `Quickbooks::Client`; the audit query starts
  from the route-owned connection association. This phase performs reads only.
- Database decision: no JSON-expression index was added for `request_payload.txn_date`. The only live audit set is
  one row and the existing connection/chronology index supports ownership/order. Revisit with real growth and an
  `EXPLAIN` plan instead of adding a speculative migration.
- Known tradeoff: offset/`STARTPOSITION` pagination can shift when a new record is inserted between page reads.
  Deterministic ordering and browser ID de-duplication avoid displaying duplicates, but do not create a
  point-in-time snapshot. Snapshot/cursor export remains future scope if required.
- More complex alternatives rejected: Kaminari/Pagy, a generic repository, generic query/filter DSL, saved
  report model, background export, cursor framework, or a local mirror of every QuickBooks Journal Entry.
- Mature Rails repositories: no external application pattern was needed. The official Rails query/controller
  mechanisms and Intuit query contract solve the current two-read-endpoint requirement directly.

## Phase 11 — Local sandbox MVP closeout

Date reviewed: 2026-07-15
Installed Ruby version: 3.4.6
Installed Rails version: 8.1.3

### Official Rails references

- Source: [The Rails Command Line](https://guides.rubyonrails.org/command_line.html)
- Relevant section: starting the development server and inspection/database commands.
- Pattern observed: Rails' checked-in `bin/rails` commands are the conventional operator surface for server,
  route, runner, database, and Zeitwerk inspection.
- Applicability: the handoff uses the repository's checked-in `bin/setup`, `bin/dev`, and `bin/rails` commands. No
  deployment wrapper, process manager, or second frontend toolchain was added for a localhost MVP.

- Source: [Securing Rails Applications — Custom Credentials](https://guides.rubyonrails.org/security.html#custom-credentials)
- Relevant section: environmental security and custom credentials.
- Pattern observed: encrypted `config/credentials.yml.enc` may be versioned, while `config/master.key` or
  `RAILS_MASTER_KEY` must be kept safe and the key must not be committed.
- Applicability: the operator handoff explicitly separates encrypted ciphertext from the ignored local key and
  requires secure out-of-band key transfer.

### Official QuickBooks references

- Source: no new capability reference required.
- Relevant endpoint or behavior: none added. Phase 11 only reuses existing CompanyInfo, Account query, and Journal
  Entry query reads to close the already-documented sandbox MVP.
- Applicability: no new entity, field, payload, write, production endpoint, or accounting interpretation was
  introduced.

### Mature Rails repositories inspected

None. This phase adds operational documentation and validates existing repository conventions; copying a larger
application's deployment/runbook or secrets platform would imply requirements that the local MVP does not have.

### Resulting decision

- Chosen pattern: one repository-local operator handoff document linked from README, backed by the existing phase
  evidence and checked-in Rails commands.
- Why it is idiomatic: it uses Rails' normal credentials and command boundaries and changes no runtime layer.
- Legacy decision: retain the unused local mapping and active demo sandbox Account as explicitly excluded
  historical evidence. Cleanup requires separate authorization because local deletion and QuickBooks
  deactivation are different effects.
- Source-control decision: report the absence of an initial commit; do not infer authorization to stage/commit.
- More complex alternatives rejected: deployment automation, secrets manager integration, authentication,
  background processing, production configuration, or a documentation portal.

## Phase 12 — Read-only core CFO financial statements

Date reviewed: 2026-07-16
Installed Ruby version: 3.4.6
Installed Rails version: 8.1.3

### Official Rails references

- Source: [Rails Routing from the Outside In](https://guides.rubyonrails.org/routing.html)
- Relevant section: controller namespaces, explicit `get` routes, route defaults, and named route helpers.
- Pattern observed: fixed read-only URLs can route to one conventional controller action while route defaults
  identify the specific resource requested; generated helpers keep URLs out of views and JavaScript.
- Applicability: three explicit nested GET URLs identify Profit & Loss, Balance Sheet, and Cash Flow. Each routes
  to one `FinancialReportsController#show` action with a fixed internal report key; callers cannot supply an
  arbitrary QuickBooks report endpoint.

- Source: [Action Controller Overview](https://guides.rubyonrails.org/action_controller_overview.html)
- Relevant section: query parameters, permitted parameters, and controller request/response responsibility.
- Pattern observed: controllers should accept an explicit HTTP parameter boundary, delegate domain/vendor work,
  and render the resulting representation.
- Applicability: the controller permits only `start_date`, `end_date`, `as_of_date`, and `accounting_method`, then
  delegates date policy, QuickBooks GET construction, and response normalization to report-specific Ruby objects.

- Source: [Action View Form Helpers](https://guides.rubyonrails.org/form_helpers.html) and
  [The Rails Asset Pipeline](https://guides.rubyonrails.org/asset_pipeline.html)
- Relevant section: standard date/select controls and browser-ready application assets.
- Pattern observed: a small server-rendered Rails page can use labeled native controls and plain JavaScript
  without introducing a second frontend toolchain.
- Applicability: the existing ERB shell and Propshaft-served JavaScript gain one report selector, period/as-of
  dates, accounting basis, a dynamic table, and browser-only CSV export.

### Official QuickBooks references

- Source: [Run reports](https://developer.intuit.com/app/developer/qbo/docs/workflows/run-reports)
- Relevant endpoints: `BalanceSheet`, `ProfitAndLoss`, and `CashFlow` beneath
  `/v3/company/<realmId>/reports/`.
- Relevant parameters and response fields: `start_date`, `end_date`; `accounting_method` for Profit & Loss and
  Balance Sheet; `Header`, `Columns`, and
  recursively nested `Rows`; `ReportBasis`, `StartPeriod`, `EndPeriod`, `Currency`, and `NoReportData`.
- Pattern observed: reports are read-only generated views of existing QuickBooks accounting data. Section rows
  can contain nested section/data rows and summaries. Intuit recommends limiting report ranges to six months.
- Applicability: period reports enforce a maximum six-calendar-month range; Balance Sheet exposes one
  `as_of_date` and sends it as QuickBooks `end_date`. Cash Flow neither accepts an accounting method nor returns
  `ReportBasis`, so its public API rejects that unsupported parameter. The response is flattened only for
  presentation while
  preserving row kind, depth, group, column order, cell strings, and realm-scoped reference IDs.

- Source: [Reporting in QuickBooks Online](https://developer.intuit.com/app/developer/qbo/docs/learn/learn-basic-bookkeeping/business-analytics)
- Relevant behavior: Balance Sheet reports assets, liabilities, and equity at a point in time; Profit & Loss
  reports income and expenses; reports derive from existing accounts and transactions.
- Applicability: the dashboard labels the Balance Sheet as an as-of report and the other two as period reports.
  It does not present reports as stored documents or create local accounting totals.

### Resulting decision

- Chosen pattern: three explicit GET contracts share one narrowly bounded reports query/parser because all three
  use the same Intuit report envelope. The accepted report keys and vendor paths are fixed constants, not a
  generic caller-controlled QuickBooks gateway.
- Request policy: exact ISO `YYYY-MM-DD` dates, ordered period dates, and a maximum six-calendar-month period.
  Profit & Loss and Balance Sheet accept `Cash`/`Accrual`; Cash Flow does not. Defaults are a rolling six-month
  period ending today or a
  Balance Sheet as of today.
- Response policy: expose report metadata, ordered column definitions, and flattened rows. Money remains a
  validated decimal string; Rails and the browser do not calculate or reclassify QuickBooks report values.
- Live response note: the sandbox Cash Flow response included one leaf row with `ColData` and no `type`, although
  the overview describes data leaves as `type: Data`. The parser accepts that exact observed omission only when
  `ColData` is an array; other missing or unknown row shapes still fail closed as an unexpected response.
- Runtime scope: no model, migration, persistence, background job, write, idempotency record, or local audit row.
  Each request reads the currently connected sandbox company through the existing encrypted connection and
  `Quickbooks::Client` HTTP boundary.
- UI decision: load only Profit & Loss initially. The operator explicitly selects another statement and submits
  its controls, avoiding three simultaneous report calls while still exposing three distinct APIs.
- More complex alternatives rejected: a generic arbitrary report endpoint, report-type metaprogramming, local
  report snapshots, caching, a reporting gem, a SPA/grid library, database-backed exports, or a second frontend.

## Phase 13 — Supported payroll-adjacent, tax, and inventory operations

Date reviewed: 2026-07-21
Installed Ruby version: 3.4.6
Installed Rails version: 8.1.3

### Official Rails references

- Source: [Rails Routing from the Outside In](https://guides.rubyonrails.org/routing.html)
- Relevant section: resource routing, nested resources, namespaces, `only`, and generated path helpers.
- Pattern observed: related GET/POST collection operations belong in explicit resource controllers and should be
  nested only one level beneath their owning connection.
- Applicability: Employee, TimeActivity, TaxCode, and inventory Item each receive an explicit connection-scoped
  `index`/`create` resource. Rails never accepts a caller-selected QuickBooks entity name or vendor path.

- Source: [Action Controller Overview](https://guides.rubyonrails.org/action_controller_overview.html)
- Relevant section: parameters, permitted parameters, request headers, JSON rendering, and exception handling.
- Pattern observed: controllers define the HTTP input boundary while domain objects validate accounting/vendor
  rules and construct outbound payloads.
- Applicability: each new controller permits only its documented payload fields, requires the existing UUID
  `Idempotency-Key` for POST, and delegates QuickBooks queries, payload creation, readback, and audit state.

- Source: [Action View Form Helpers](https://guides.rubyonrails.org/form_helpers.html)
- Relevant section: `form_with`, namespaced parameter hashes, select fields, date fields, authenticity tokens, and
  standard browser controls.
- Pattern observed: server-rendered forms preserve Rails CSRF behavior while a small JavaScript layer can submit
  the same JSON contracts and render source-specific failures.
- Applicability: Phase 13 uses one separate operational-data page instead of expanding the already large
  financial-records page. Each write form is labeled as a real sandbox mutation and uses native controls.

- Source: [Active Record Migrations](https://guides.rubyonrails.org/active_record_migrations.html)
- Relevant section: check constraints and reversible schema changes.
- Pattern observed: integrity rules that must survive application mistakes belong in the database as well as the
  model.
- Applicability: the existing write-audit table remains connection-scoped and gains fixed allowed operation and
  entity types for the four new create flows; no generic or arbitrary entity type is accepted.

### Official QuickBooks references

- Source: [Explore the QuickBooks Online Accounting API](https://developer.intuit.com/app/developer/qbo/docs/learn/explore-the-quickbooks-online-api)
- Relevant behavior: Employee is a list resource, TimeActivity is a transaction resource, and Item is the
  inventory resource; supported operations vary by entity and must be checked in the API Explorer.

- Source: [QuickBooks Online release notes](https://developer.intuit.com/app/developer/qbo/docs/release-notes/general-release-notes)
- Relevant behavior: the modern Payroll API is closed beta and is not open to new developers.
- Applicability: Phase 13 does not expose payroll runs, checks, compensation, deductions, benefits, corrections,
  filings, or Payroll API endpoints. Public Accounting API Employee and TimeActivity operations are presented as
  payroll-adjacent workforce/time capabilities, not full payroll.

- Source: [Employee entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/employee)
- Relevant operations: create, query, read, and update/deactivate are public with or without QuickBooks Payroll.
- Relevant rules: name components cannot contain colon, tab, or newline; display names must be unique across
  Customer/Employee/Vendor; payroll-enabled companies restrict several fields and masked SSNs must not be sent.
- Applicability: the API reads active Employees and creates only GivenName, FamilyName, optional email, and
  optional phone. It never requests, stores, returns, or sends SSN, birth date, pay rate, address, or compensation.

- Source: [TimeActivity entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/timeactivity)
- Relevant operations: create, query, read, full update, and delete. `NameOf: Employee` requires EmployeeRef;
  Hours/Minutes or start/end times are required, and TxnDate is filterable/sortable.
- Applicability: Phase 13 reads bounded recent TimeActivities and creates employee time using exact ISO TxnDate,
  validated integer Hours/Minutes, an active EmployeeRef, and a plain description. It does not use the closed-group
  PayrollItemRef or claim that a time entry calculates payroll.

- Sources: [TaxCode](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/taxcode),
  [TaxRate](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/taxrate), and
  [TaxService](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/taxservice)
- Relevant operations: TaxCode and TaxRate support query/read; creation goes through
  `POST /taxservice/taxcode`. TaxService can associate existing rates or dynamically create rates, requires a
  unique code name, and limits rates to 0–100 percent. US companies expose system-created agencies/rates.
- Applicability: one GET returns current codes, rates, and agencies. The POST creates a code from one existing,
  active rate and an explicit Sales/Purchase applicability. Phase 13 does not create tax agencies/rates, calculate
  transaction tax, submit returns, or make tax payments.

- Sources: [Item entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/item),
  [Items and inventory](https://developer.intuit.com/app/developer/qbo/docs/learn/learn-basic-bookkeeping/manage-inventory),
  and [Basic inventory implementation](https://developer.intuit.com/app/developer/qbo/docs/develop/basic-implementations/basic-inventory-implementation)
- Relevant operations/rules: Item supports create, query, read, and update. Inventory Items require Name, Type,
  InvStartDate, QtyOnHand, TrackQtyOnHand, and income, cost-of-goods-sold, and inventory-asset Account references.
  QuickBooks uses FIFO inventory accounting and transactions can alter quantity and asset/COGS balances.
- Applicability: the GET returns inventory Items plus only eligible account choices. The POST creates one
  Inventory Item using decimal strings converted without binary floating point and verifies the created Item by
  readback. Positive opening quantity/cost can affect QuickBooks inventory value and is clearly labeled. Phase 13
  does not create Accounts, purchases, sales, categories, bundles, or InventoryAdjustment transactions.

### Live sandbox capability review

Read-only queries on 2026-07-21 returned two Employees, five TimeActivities, five TaxCodes, three TaxRates, two
TaxAgencies, and eighteen Items, four of which were Inventory. CompanyInfo reported `PayrollFeature=false` and
`ItemCategoriesFeature=true`. These observations prove the connected sandbox can read the selected public
entities; they do not authorize or prove any new external write.

### Resulting decision

- Add exactly eight new CFO JSON operations: GET/POST Employees, TimeActivities, TaxCodes, and InventoryItems.
- Keep four explicit entity-specific query/create/readback implementations. Reuse only the existing HTTP client
  and a narrowly scoped idempotent-create audit coordinator; entity validation and payload construction stay in
  their domain namespaces.
- Generalize only the fixed database allowlists required for the four new audited create types. Existing Journal
  Entry audit reads must explicitly remain limited to `journal_entry_create` rows.
- Put Phase 13 on a separate conventional Rails page linked from the connection page. This prevents payroll/tax/
  inventory concerns from crowding the existing CFO statements and Journal Entry dashboard.
- Do not execute Employee, TimeActivity, TaxCode, or Item POST during Phase 13 acceptance. A real sandbox write
  requires a deliberate record, account/rate choice, and operator confirmation; local rejection paths and all GET
  paths can be validated without changing QuickBooks.
- More complex alternatives rejected: full Payroll API emulation, generic arbitrary-entity CRUD, dynamic tax-rate
  or tax-agency creation, tax payments/filings, inventory adjustments, account auto-creation, bulk/scheduled sync,
  background jobs, and a second frontend framework.

## Phase 14 — Customers, vendors, receivables, payables, and accountant reports

Date reviewed: 2026-07-21
Installed Ruby version: 3.4.6
Installed Rails version: 8.1.3

### Official Rails references

- [Rails Routing from the Outside In](https://guides.rubyonrails.org/routing.html): retained explicit nested
  `index`/`create` resources under the owning connection and generated path helpers. No caller-controlled entity
  or vendor path is accepted.
- [Action Controller Overview](https://guides.rubyonrails.org/action_controller_overview.html): each controller
  permits only its entity's fixed input and renders normalized JSON; all accounting and QuickBooks rules remain
  outside controllers.
- [Action View Form Helpers](https://guides.rubyonrails.org/form_helpers.html): the third Rails page uses
  `form_with`, native date/number/select controls, and the existing CSRF session. JavaScript only exchanges JSON
  and renders state.
- [Active Record Migrations](https://guides.rubyonrails.org/active_record_migrations.html): one reversible
  migration expands the existing check constraint with six exact operation/entity pairs. No new domain table or
  generic mapping store was added.

### Official Intuit review

- [Accounting API resource model](https://developer.intuit.com/app/developer/qbo/docs/learn/explore-the-quickbooks-online-api):
  Customer and Vendor are list resources; Invoice, Bill, Payment, and BillPayment are transaction resources.
- [Create basic invoices](https://developer.intuit.com/app/developer/qbo/docs/workflows/create-an-invoice) and
  [basic invoicing implementation](https://developer.intuit.com/app/developer/qbo/docs/develop/basic-implementations/basic-invoicing-implementation):
  Invoice requires Customer and sales Item references; Payment can link one amount to an Invoice.
- [Basic billing implementation](https://developer.intuit.com/app/developer/qbo/docs/develop/basic-implementations/basic-billing-implementation):
  Bill uses Vendor plus an account- or item-based expense line; check BillPayment uses Vendor, bank Account, and
  a link to the source Bill.
- [Run reports](https://developer.intuit.com/app/developer/qbo/docs/workflows/run-reports): the report inventory
  names `TrialBalance` and `GeneralLedgerDetail`; report responses use the existing Header/Columns/Rows structure.
- [QuickBooks error codes](https://developer.intuit.com/app/developer/qbo/docs/develop/troubleshooting/error-codes):
  live GeneralLedgerDetail returned `5020`, officially defined as Permission Denied. The implementation keeps the
  documented endpoint and exposes the safe error instead of using an unrelated substitute. Phase 15 later
  supersedes this Phase 14 decision using the verified `GeneralLedger` report resource documented below.

### Resulting decision

- Add fourteen CFO operations: six explicit GET/POST pairs plus two report GETs.
- Use one separate sales/payables page so the financial-report and Phase 13 pages remain readable.
- Restrict Invoice and Bill to one line, Payment to one open Invoice, and BillPayment to one open Bill using
  check pay type. Current references and balances are reloaded immediately before POST.
- Preserve decimal strings through `BigDecimal`, exact ISO dates, UUID/Intuit `requestid`, connection-scoped audit
  state, conservative uncertainty, and entity readback.
- Reuse the existing report parser for Trial Balance and General Ledger because both use the documented report
  envelope. This is an extension of a proven explicit map, not a new generic report architecture.
- No mature third-party Rails code was copied: standard Rails resource/controller/form/migration patterns and the
  existing repository flow fully cover this phase.
- Reject bulk sync, arbitrary payloads, multi-line editors, document delivery, online payment processing,
  background jobs, and a generalized accounting engine as outside Phase 14.

## Phase 15 — General Ledger endpoint correction

Date reviewed: 2026-07-21
Installed Ruby version: 3.4.6
Installed Rails version: 8.1.3

### Reference reconciliation

- [Run reports](https://developer.intuit.com/app/developer/qbo/docs/workflows/run-reports) lists the General
  Ledger Reports API name as `GeneralLedgerDetail` and documents the standard report envelope and recommended
  six-month request limit.
- [Accounting API resource model](https://developer.intuit.com/app/developer/qbo/docs/learn/explore-the-quickbooks-online-api)
  separately names `GeneralLedger` among relevant reporting resources.
- [QuickBooks error codes](https://developer.intuit.com/app/developer/qbo/docs/develop/troubleshooting/error-codes)
  defines `5020` as Permission Denied, but that code alone does not prove the whole company lacks General Ledger
  access when another documented resource name may exist.

### Live read-only comparison

- `reports/GeneralLedgerDetail` returned `5020` with full dashboard parameters, date-only parameters, and no
  parameters.
- `reports/GeneralLedger` returned HTTP 200 for the same sandbox and date period. With the dashboard's Accrual
  request, the existing strict parser produced 8 columns and 452 rows with `no_data: false`.
- `reports/ProfitAndLossDetail` also returned HTTP 200, disproving a general ban on detail reports for this
  connection.

### Rails decision

- Change only the fixed `Quickbooks::Reports::Query::ENDPOINTS[:general_ledger]` value. The public Rails route,
  controller action, parameters, parser, serializer, dashboard, and response schema remain unchanged.
- No new Rails architectural pattern is introduced, so the existing explicit service/controller boundary and
  the Rails references reviewed for Phase 12/14 remain sufficient.
- Do not catch `5020` and synthesize HTTP 200. A genuine upstream failure must still use the normalized error
  response; HTTP 200 is returned only when QuickBooks supplies and Rails successfully parses the report.

## Phase 16 — Controlled sales and payables lifecycle acceptance

Date reviewed: 2026-07-21
Installed Ruby version: 3.4.6
Installed Rails version: 8.1.3

### Reference and architecture decision

- Phase 16 introduces no new QuickBooks resource, field, report, route, or Rails architectural pattern. It uses
  only the Customer, Vendor, Invoice, Payment, Bill, BillPayment, linked-transaction, and Reports API contracts
  already reviewed and recorded for Phases 12–15.
- Use Service Item `1` to avoid changing inventory quantity; Office Expenses `15`, Accounts Payable `33`, and
  Checking `35` are freshly queried active references rather than invented or cached IDs.
- Keep the lifecycle deliberately small: $2 Invoice/Payment and $1 Bill/BillPayment on one ISO date. Capture
  baseline statements, require readback after every create, then independently query current balances and all
  four reconciliation reports.
- Exercise same-key replay only after all six operations have succeeded. A replay must return the stored original
  result with HTTP 200 and must not call QuickBooks or create another audit row. Use entity GET for current state
  because a replay is the immutable creation-time response, not a refreshed transaction.
- Preserve rejected preflight attempts as local audit facts. A later stale Customer confirmation used a new key;
  the existing active-name query found Customer `58`, returned HTTP 422 before any Customer POST, and left the
  native sandbox and reports unchanged. This validates the current entity-specific guard and does not justify a
  new service or persistence pattern.
- No new abstraction or corrective code is justified: the existing explicit controllers, entity submitters,
  shared narrow idempotency coordinator, strict report parser, and dashboard GET flows all passed live acceptance.

## Phase 17 — Controlled workforce, tax, and inventory acceptance

Date reviewed: 2026-07-21
Installed Ruby version: 3.4.6
Installed Rails version: 8.1.3

### Reference and architecture decision

- Current official Intuit Employee, TimeActivity, TaxService, Item, query, error-code, time-tracking, and
  inventory guidance was rechecked before the first controlled write. Phase 17 adds no entity, field, route, or
  architectural pattern beyond the Phase 13 implementation.
- Use one new Employee followed by one 15-minute TimeActivity that references the returned Employee ID. This is
  Accounting API workforce/time data only; the connected sandbox reports Payroll disabled.
- Use existing active TaxRate `3` for a Sales TaxCode. Preserve any Intuit locale/business validation as a safe
  rejected or uncertain audit outcome rather than weakening the entity-specific contract.
- Use current eligible Accounts `79` (sales income), `80` (COGS), and `81` (inventory asset) for one Inventory
  Item with quantity zero, purchase cost `0.01`, and unit price `0.02`. This exercises decimal/reference readback
  while expecting no accounting entry.
- Keep the existing explicit controllers, entity creators, and narrow `Quickbooks::CreateSubmission` coordinator.
  Correct code only if live acceptance proves a concrete mismatch; do not introduce a generic service or new
  persistence layer.

### Live correction decision

- After TaxCode `4` reused TaxRate `3`, QuickBooks returned two identical TaxRate records with ID `3`. Passing
  both through made the dashboard count four rates although only three IDs were distinct.
- Correct only `Quickbooks::TaxCodes::Query`: collapse duplicate records when the full normalized value is
  identical, but continue to raise the existing safe unexpected-response error when one ID has conflicting data.
  This mirrors the defensive uniqueness handling already used by the Account query and adds no public contract,
  database change, or generic abstraction.
- A zero-opening Inventory Item still caused QuickBooks to emit two `.00` General Ledger rows. This is preserved
  and displayed as native QuickBooks report data; Rails must not suppress or recalculate it.

## Phase 18 — Importmap CI executable and push-readiness preflight

Date reviewed: 2026-07-21
Installed Ruby version: 3.4.6
Installed Rails version: 8.1.3
Installed importmap-rails version: 2.2.3

### Installed Rails dependency reference

- Source inspected: the installed `importmap-rails` package files `lib/install/bin/importmap`,
  `lib/install/config/importmap.rb`, `lib/importmap/commands.rb`, and `lib/importmap/npm.rb`.
- Pattern observed: the Rails executable loads `config/application` and `importmap/commands`; the audit command
  reads `config/importmap.rb` and audits only versioned npm pins.
- Applicability: this application uses asset-pipeline JavaScript and has no Importmap-managed npm packages.
  Retain the canonical executable and a valid empty package map so the existing CI audit correctly reports an
  empty dependency set. Do not invent an `application` pin for a nonexistent `app/javascript/application.js`.

### Resulting decision

- Add only the canonical four-line `bin/importmap` executable and make it executable.
- Add `config/importmap.rb` with the canonical usage comment and no package pins.
- Keep the existing CI jobs; they contain static analysis, dependency audits, and linting but no automated test
  command.
- Update only the two transitive dependencies flagged by Bundler Audit: `loofah` from `2.25.1` to `2.25.2` and
  `rails-html-sanitizer` from `1.7.0` to `1.7.1`.
- No application architecture, QuickBooks behavior, route, schema, production configuration, or test boundary
  changes in this phase.

## Phase 19 — Deterministic Ruby formatting

Date reviewed: 2026-07-21
Installed Ruby version: 3.4.6
Installed Rails version: 8.1.3
Installed syntax_tree version: 6.3.0

### Formatter references

- Source: [Syntax Tree project documentation](https://github.com/ruby-syntax-tree/syntax_tree). Relevant
  sections: bundled installation, `stree check`, `stree write`, `.streerc`, globbing, and the official RuboCop
  compatibility configuration.
- Source: [syntax_tree on RubyGems](https://rubygems.org/gems/syntax_tree). Version `6.3.0` was the current
  published release reviewed for this phase and supports the project's Ruby version requirement.
- Source: [RuboCop autocorrect documentation](https://docs.rubocop.org/rubocop/usage/autocorrect.html). RuboCop
  can apply layout-only corrections, but this repository already uses it as the Rails Omakase linter; using it
  as a second formatter would leave formatting ownership ambiguous.

### Resulting decision

- Add `syntax_tree ~> 6.3` to the development bundle as the single deterministic Ruby formatter.
- Use the official Syntax Tree RuboCop compatibility config after Rails Omakase in inheritance resolution, so
  Syntax Tree owns layout while Omakase retains non-overlapping lint rules and double-quoted strings.
- Use print width 100. Keep RuboCop's line limit at 140 because Syntax Tree cannot split four existing SQL/check
  constraint string literals between 121 and 130 characters.
- Provide `bin/format write` and `bin/format check`. The wrapper discovers current Ruby binstubs and includes
  application/configuration Ruby, migrations, seeds, `Gemfile`, `Rakefile`, and `config.ru`.
- Exclude generated `db/schema.rb`, automated tests, ERB, JavaScript, CSS, Markdown, YAML, encrypted credentials,
  and runtime artifacts. One Ruby formatter cannot safely rewrite unrelated languages.
- Add `bin/format check` to both GitHub Actions and the local `bin/ci` sequence before RuboCop.
- Standard Ruby was not adopted because it would replace the existing Rails Omakase lint policy. No ERB or
  JavaScript formatter gem was added because the authorized phase explicitly selected an idiomatic Ruby
  formatter and one ownership boundary.
