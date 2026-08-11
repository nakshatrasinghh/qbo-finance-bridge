# Phase 40 QuickBooks Model Separation Design

Date approved: 2026-08-11

## Status

This document records the approved design. Phase 40 does not move application files or change runtime behavior.
Implementation requires the user's review of this written specification followed by a separate implementation
plan and phase authorization.

## Goal

Give `app/models` a truthful Rails responsibility by moving the application's immutable QuickBooks domain,
read, and parameter value objects out of `app/services`. Keep request-running workflows, serialization,
process-local storage, and QuickBooks HTTP behavior in `app/services`.

This is an organizational refactor. It must preserve every constant name, public method, response shape, error,
QuickBooks request, session rule, and database-free runtime property.

## Context

Phase 34 removed Active Record, `ApplicationRecord`, database configuration, migrations, and four persisted
models. The generated `app/models/concerns/.keep` file remained, while new plain Ruby domain and read objects
were placed under `app/services/quickbooks` with request-running workflows.

Rails models are not limited to Active Record. This application already has immutable objects that represent
domain state, validated parameters, QuickBooks records, and paginated read results without persistence. Those
objects are models even though they do not inherit from `ApplicationRecord` or include Active Model modules.

## Boundary

An object belongs in `app/models/quickbooks` when it primarily represents validated state or data and does not
perform external I/O, own process storage, orchestrate a use case, or serialize an HTTP response.

An object stays in `app/services/quickbooks` when it performs one or more of these responsibilities:

- calls QuickBooks or an OAuth endpoint;
- coordinates create, readback, and verification steps;
- owns process-local connection storage or synchronization;
- converts an application object into a public response shape;
- executes an entity query, submission, or OAuth workflow.

Phase 40 separates model/value objects; it does not claim every remaining file is an executable service.
Existing shared support such as `Quickbooks::Error`, entity-ID policy, and configuration remains in place to
avoid silently expanding the approved 19-file scope.

No generic model base class, service base class, repository, engine, persistence abstraction, or dependency is
introduced.

## Model File Moves

Move these 19 files without changing the constants they define:

| Current path under `app/services/quickbooks` | Destination under `app/models/quickbooks` |
|---|---|
| `sandbox_connection.rb` | `sandbox_connection.rb` |
| `oauth/token_set.rb` | `oauth/token_set.rb` |
| `accounts/details.rb` | `accounts/details.rb` |
| `bill_payments/details.rb` | `bill_payments/details.rb` |
| `bills/details.rb` | `bills/details.rb` |
| `company_info/details.rb` | `company_info/details.rb` |
| `customer_payments/details.rb` | `customer_payments/details.rb` |
| `customers/details.rb` | `customers/details.rb` |
| `employees/details.rb` | `employees/details.rb` |
| `inventory_items/details.rb` | `inventory_items/details.rb` |
| `invoices/details.rb` | `invoices/details.rb` |
| `journal_entries/details.rb` | `journal_entries/details.rb` |
| `journal_entries/read_page.rb` | `journal_entries/read_page.rb` |
| `journal_entries/read_parameters.rb` | `journal_entries/read_parameters.rb` |
| `reports/details.rb` | `reports/details.rb` |
| `reports/parameters.rb` | `reports/parameters.rb` |
| `tax_codes/details.rb` | `tax_codes/details.rb` |
| `time_activities/details.rb` | `time_activities/details.rb` |
| `vendors/details.rb` | `vendors/details.rb` |

Delete `app/models/concerns/.keep` because the generated empty concerns directory has no application purpose.

The nested `Data` types inside each moved file remain with their owning model. Examples include report rows and
cells, invoice lines and catalogs, tax code/rate/agency values, and payment applications.

## Services That Stay Put

The following remain under `app/services/quickbooks`:

- `Quickbooks::Client`, `Quickbooks::Oauth::TokenClient`, and transport configuration;
- `Quickbooks::SandboxConnectionStore` and its synchronization behavior;
- every entity `Create`, `Submit`, `Query`, `RecordsQuery`, `Serializer`, and `Fetch` class;
- OAuth authorization-code exchange and disconnect workflows;
- `Quickbooks::Items::SalesChoices`, because it queries QuickBooks;
- shared errors, entity-ID policy, and configuration objects;
- each `Submit::Result`, because it is private to its submission workflow.

The nested `Items::SalesChoices::Choice` remains with `SalesChoices`; splitting one private result type away from
the I/O service would add indirection without creating an independently meaningful domain model.

## Dependency Direction

The resulting dependency flow is:

```text
Controllers
    -> QuickBooks services and workflows
        -> QuickBooks models and value objects
        -> QuickBooks and OAuth clients -> Intuit

QuickBooks models and clients
    -> shared Quickbooks::Error hierarchy
```

Models may depend on Ruby, Active Support value helpers, `BigDecimal`, and the shared `Quickbooks::Error`
hierarchy. Five approved model files already raise those domain errors. The error hierarchy remains physically
under `app/services` in this phase because it is shared support rather than a model; that existing physical
dependency is explicit and does not permit models to invoke service workflows.

Models must not call QuickBooks, access controllers or sessions, fetch from the connection store, or serialize
HTTP responses.

Services may construct and consume models. Controllers continue to call services rather than reaching into
model factories to perform external workflows.

## Rails Autoloading

Both `app/models` and `app/services` are Rails autoload roots. The path beneath each root maps to the same
constant namespace, so moving
`app/services/quickbooks/customers/details.rb` to
`app/models/quickbooks/customers/details.rb` continues to define `Quickbooks::Customers::Details`.

No `require`, `require_dependency`, custom autoload path, custom inflector, or initializer is needed. The
implementation must confirm that no application or test code depends on a physical source path.

## Tests

This phase changes no behavior and adds no test dependency. The implementation phase should use the existing
suite as characterization coverage before and after the moves.

Move the one directly corresponding unit test:

```text
test/services/quickbooks/reports_parameters_test.rb
    -> test/models/quickbooks/reports/parameters_test.rb
```

Tests for stores, clients, workflows, controllers, integration boundaries, and views remain in their current
locations even when they construct a moved model as test data. No test should assert a source file path merely
to enforce folder organization.

## Documentation

The implementation phase updates:

- `docs/architecture.md` to identify plain Ruby models as a responsibility separate from services;
- `docs/reference_review.md` with the official Rails autoloading and model-layer rationale;
- `docs/phase_status.md` with validation and final file-move evidence.

Documentation must continue to say that the application has no Active Record models or database. It may no
longer describe the application as having zero models without qualifying that statement as zero Active Record
models.

## Validation

The implementation phase must run and inspect:

- the full Rails test suite before and after the file moves;
- development and production Rails boot;
- `bin/rails zeitwerk:check`;
- deterministic formatting and RuboCop;
- `bin/bundler-audit` and Brakeman;
- a source-path search for obsolete `app/services/quickbooks/...` references;
- the required Ruby-source scan for `Enumerable#any?`;
- `git diff --check`;
- a focused diff proving the moved Ruby file contents and constants are unchanged.

No OAuth callback, Intuit request, QuickBooks readback, sandbox write, database setup, or external infrastructure
change is authorized by this design.

## Risks and Mitigations

### Autoload mismatch

A moved path could stop matching its constant. Preserve every relative path below the autoload root and require
`bin/rails zeitwerk:check` plus eager boot before completion.

### Accidental behavior change

Editing files while moving them would make the refactor harder to verify. Move files mechanically and compare
their contents; limit code edits to references that demonstrably depend on a physical path.

### Treating every data-shaped object as a model

Private workflow results and I/O-specific choices do not become clearer merely by moving them. Keep
`Submit::Result` and `Items::SalesChoices::Choice` with their owning services.

### Shared error location

Five moved models raise the existing `Quickbooks::Error` subclasses. Keep that hierarchy unchanged for this
approved 19-file move and document it as shared domain support. Moving errors to another root would be a separate
boundary decision rather than an unreviewed addition to this refactor.

### Reintroducing persistence by implication

Using `app/models` must not lead to `ApplicationRecord`, Active Record configuration, migrations, tables, or a
database dependency. Runtime compatibility continues to prove Active Record is not loaded.

## Alternatives Considered

### Delete the empty models directory

This would remove misleading scaffolding with minimal churn, but it would leave model/value objects mixed with
request-running services and preserve the unclear boundary.

### Move only `SandboxConnection` and `Oauth::TokenSet`

This would establish a small model layer, but the `Details`, parameter, and page objects would remain misplaced.
It was rejected in favor of the user-approved full separation.

### Move every `Data.define` declaration

This would also extract private `Submit::Result` and `Items::SalesChoices::Choice` types. It was rejected because
those types have meaning only inside their owning workflows and would create unnecessary cross-file navigation.

## Acceptance Criteria

- Exactly the 19 approved model/value-object files live under `app/models/quickbooks`.
- Their constants, methods, visibility, and Ruby contents remain behaviorally unchanged.
- Request-running workflows, clients, serializers, and the connection store remain under `app/services`.
- The empty generated `app/models/concerns/.keep` file is removed.
- No Active Record railtie, `ApplicationRecord`, database configuration, migration, or dependency is added.
- No path-based require depends on the old service locations.
- Rails boots and eager loads the new paths successfully.
- Existing behavior and security validation pass without a QuickBooks request.
- Documentation distinguishes plain Ruby models from absent Active Record persistence.

## Decisions

- **Use the full separation, not only the two core connection objects.** The user asked to see the full
  separation and approved the 19-file boundary so `app/services` no longer mixes value objects with workflows.
- **Treat `Reports::Parameters` and `JournalEntries::ReadParameters` as models.** The user approved these
  immutable, validated value objects as part of the model layer.
- **Keep external I/O and orchestration in services.** This preserves an obvious controller-to-workflow request
  flow and prevents models from becoming QuickBooks gateways.
- **Preserve constants and behavior.** The refactor changes physical Rails locations only and does not rename or
  redesign the public objects.
- **Keep the application database-free.** `app/models` contains plain Ruby models; it does not imply Active
  Record or persistence.
- **Keep Phase 40 design-only.** The user started Phase 40 after being told it would write the specification for
  review before implementation.
