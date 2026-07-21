# Phase 00 — Repository bootstrap, Rails reference review, and learning framework

Status: **COMPLETE locally**
Completed: 2026-07-14
Ruby: 3.4.6
Rails: 8.1.3
Database: PostgreSQL 16.11

## A. Phase objective

Phase 0 turns an empty directory into a conventional Rails application named `qbo_cfo_bridge`, configured for PostgreSQL and accompanied by the documentation needed to learn, validate, and control later phases. It adds a local JSON liveness endpoint and records the initial pragmatic-monolith decision.

The developer learns how Rails generates its default structure, how a request moves from the router to a controller, why the framework's built-in health endpoint is close to—but not identical to—the requested contract, and how phase/reference status is preserved for later sessions.

This phase intentionally does not add OAuth, QuickBooks models or HTTP calls, accounting endpoints, financial records, idempotency, background jobs, package tooling, engines, generic service layers, or automated test files.

## B. Accounting meaning

This is an infrastructure phase. It creates no accounting record locally or in QuickBooks. There are no debits, credits, posting transactions, or non-posting QuickBooks master-data records. Profit and Loss, Balance Sheet, Cash Flow, Trial Balance, General Ledger, Accounts Receivable, and Accounts Payable reports do not change.

## C. Rails pattern and reference review

The selected pattern is a full, conventional Rails 8.1 monolith with PostgreSQL, the generated defaults, one explicit route, and one focused controller action.

Official references checked on 2026-07-14:

- Rails 8.1 Getting Started guide: the generated application and use of application-local binstubs.
- Rails Doctrine: convention over configuration, omakase defaults, and integrated systems.
- Installed Rails 8.1.3 source: `railties-8.1.3/lib/rails/health_controller.rb`, the generated `config/routes.rb.tt`, and `app_generator.rb`.
- Installed `rubocop-rails-omakase` 1.1.0 `rubocop.yml` plus the generated project configuration.

Mature application inspected:

- Mastodon `main` at commit `d70f1f983c945b3aa4c2089e540c67d706d762d9`.
- Exact files: `app/controllers/health_controller.rb` and the `/health` declaration in `config/routes.rb`.
- Observed pattern: even a large Rails system keeps liveness as a tiny `ActionController::Base` action with an explicit route and no dependency checks.

Adopted: the generated Rails structure, Omakase defaults, integrated monolith, conventional route/controller locations, direct `ActionController::Base` inheritance for the isolated probe, and no dependency query in the action.

Adapted: Mastodon's plain-text health response became the required JSON body. Rails' generated `/up` endpoint remains available, while `/health` gets an application-owned contract.

Rejected or deferred:

- Routing `/health` directly to `rails/health#show`: Rails 8.1.3 JSON is `status: "up"` plus a timestamp, not `{"status":"ok"}`.
- A Rack lambda inside routes: fewer files, but less discoverable and less conventional for an application response contract.
- Health service objects, database/Redis/QuickBooks probes, custom middleware, an API controller hierarchy, or a health-check gem: no current problem requires them.
- Mastodon-specific Redis, Sidekiq, Devise, and RuboCop context: it belongs to that application's scale and stack.
- API-only Rails: the backlog will need a small development-only connection page, and the full generated stack is a reasonable default.
- Packwerk, Rails Engines, microservices, command buses, repository layers, and generic service bases: no domains or coupling exist yet.

This is idiomatic because every runtime file is in the location a Rails developer expects, names align with Zeitwerk, the controller uses standard `render json:`, and defaults are kept until a real need justifies change. Namespaces and entity-specific collaborators can be added later without changing the deployment boundary. Formal modularity reviews are scheduled after Phases 4, 8, 12, 20, and 30.

Full evidence is in `docs/reference_review.md`.

## D. Request lifecycle

```mermaid
sequenceDiagram
  participant Caller
  participant Router as Rails router
  participant Health as HealthController
  Caller->>Router: GET /health; Accept: application/json
  Router->>Health: show
  Health-->>Caller: HTTP 200; {"status":"ok"}
```

Execution order:

1. Puma accepts `GET /health`.
2. Rails recognizes `get "health" => "health#show"` in `config/routes.rb`.
3. Zeitwerk resolves `HealthController` from `app/controllers/health_controller.rb`.
4. `HealthController#show` asks Rails to render a Ruby hash as JSON.
5. Rails serializes it and returns HTTP 200 with `application/json; charset=utf-8`.

The action performs no database query, authentication, external request, or background work. In development, Rails' generated pending-migration middleware can initialize/check Active Record metadata before controller processing; the observed controller action itself reported zero Active Record queries. Production liveness should remain independent of QuickBooks and other upstream dependencies.

## E. File-by-file explanation

Closely related generated files are grouped, but every added or materially changed repository path is listed below.

| File path(s) | Why the file exists / why logic belongs here | Caller → what it calls | Input → output | Database / external calls / side effects | Scope, Rails convention, and reference |
|---|---|---|---|---|---|
| `.ruby-version` | Pins the project Ruby selected during generation. | rbenv/tooling → Ruby runtime. | Version text → selected interpreter. | None. | Project runtime convention; reusable infrastructure. |
| `Gemfile`<br>`Gemfile.lock` | Declare and lock Rails 8.1, PostgreSQL, Puma, generated Rails components, lint, and security tooling. | Bundler → gem resolver/runtime loader. | Gem declarations → reproducible dependency graph. | `bundle install` downloaded gems; no runtime accounting effect. | Standard Bundler/Rails files; Rails-generated, not entity-specific. |
| `Rakefile`<br>`config.ru` | Expose Rails tasks and Rack application entry point. | Rake/Rack/Puma → Rails application. | CLI task or Rack environment → task execution/HTTP app. | Depends on invoked task; no Phase 0 external API calls. | Standard Rails boot infrastructure. |
| `.gitignore` | Ignores all local environment files, logs, temp/storage output, Bundler config, assets, and credential keys. | Git → ignore rules. | Paths → tracked/untracked classification. | No runtime effect. | Security/repository convention. |
| `.gitattributes`<br>`.dockerignore` | Configure Git diff behavior and Docker build context exclusions. | Git/Docker → file selection. | Repository files → metadata/build context. | No application runtime effect. | Rails-generated infrastructure. |
| `.rubocop.yml` | Inherits the Rails Omakase ruleset without custom overrides. | `bin/rubocop` → installed Omakase config. | Ruby files → lint findings/exit code. | Cache write only. | Rails-generated current style convention. |
| `AGENTS.md` | Preserves phase, security, architecture, accounting, and source-control constraints for future Codex sessions. | Future agents/developers → project workflow. | Repository context → operating constraints. | None. | Project governance, not runtime code. |
| `README.md` | Provides purpose, versions, setup, database, server, validation, sandbox boundary, and next-command instructions. | Developer → documented commands. | Human reading → reproducible setup. | Commands may prepare PostgreSQL/start Rails; document itself has none. | Standard repository entry point. |
| `.github/workflows/ci.yml`<br>`.github/dependabot.yml` | Preserve Rails' generated CI and dependency-update defaults. Phase 0 does not rely on or run them. | GitHub Actions/Dependabot → generated lint/security/dependency tasks. | Repository events → automation. | External CI only if repository is hosted and enabled. | Rails-generated defaults, reusable infrastructure; no custom test files added. |
| `Dockerfile`<br>`bin/docker-entrypoint`<br>`bin/thrust` | Preserve Rails' generated container, entrypoint, and HTTP acceleration setup. | Container runtime → Rails server/process. | Image/process environment → running app. | Container/process side effects only when invoked. | Generated deployment infrastructure; unused in Phase 0 validation. |
| `bin/rails`<br>`bin/rake`<br>`bin/setup`<br>`bin/dev` | Project-local command entry points and setup/dev workflows. | Developer/CI → bundled Rails, Rake, setup, server. | CLI arguments → task/process output. | Depends on command; setup can create databases. | Rails binstub convention. |
| `bin/rubocop`<br>`bin/brakeman`<br>`bin/bundler-audit`<br>`bin/ci` | Generated lint, security, dependency-audit, and local CI entry points. | Developer/CI → respective bundled tools. | Repository → diagnostics/exit status. | Tool caches and reports only; Phase 0 ran RuboCop, not the aggregate CI task. | Rails Omakase/security defaults; no competing tools. |
| `config/boot.rb`<br>`config/environment.rb`<br>`config/application.rb` | Configure Bundler boot, load the app, select Rails frameworks, set Rails 8.1 defaults, autoload `lib`, and disable system-test generation. | `bin/rails`/Rack → Rails initialization. | Environment/config → `QboCfoBridge::Application`. | Loads configuration; no QuickBooks call. | Standard Rails application boot; app name is explicit. |
| `config/environments/development.rb`<br>`config/environments/test.rb`<br>`config/environments/production.rb` | Generated environment-specific Rails behavior. The test environment config is framework scaffolding, not an automated test. | Rails boot → environment configuration. | `RAILS_ENV` → settings. | Production config references generated Solid databases; no Phase 0 use. | Rails environment convention. |
| `config/database.yml` | Configures PostgreSQL databases and pooling; application name yields `qbo_cfo_bridge_*` database names. | Active Record → PostgreSQL adapter. | Environment/`DATABASE_URL` → DB connection configs. | Local PostgreSQL connections when DB tasks/app boot require them. | Rails database convention; reusable infrastructure. |
| `config/routes.rb` | Maps Rails' generated `/up` and the required `/health` endpoint. | Rails router → controller action. | HTTP method/path → endpoint. | Route declaration itself has no side effects. | Conventional routing DSL; `/health` is application-specific. |
| `config/puma.rb` | Configures Rails' generated Puma server defaults. | Rails server → Puma. | Environment/thread settings → listener/process config. | Binds TCP when server starts. | Standard Rails server config. |
| `config/cable.yml`<br>`config/storage.yml` | Configure generated Action Cable and Active Storage adapters. | Rails frameworks → adapters. | Environment → adapter configuration. | Local storage/framework DB use only when those features run; unused here. | Preserved generated defaults. |
| `config/ci.rb`<br>`config/bundler-audit.yml` | Configure Rails' local CI orchestration and dependency audit. | `bin/ci`/Bundler Audit → tool settings. | Repository/dependency data → diagnostics. | Network may be used by audit when run; not invoked in Phase 0. | Generated quality tooling. |
| `config/credentials.yml.enc` | Holds generated encrypted Rails credentials. | Rails credentials loader → decrypted values when key is available. | Ciphertext + ignored key → secrets. | No Phase 0 credential reads; ciphertext may be committed, key may not. | Rails encrypted-credentials convention and security boundary. |
| `config/initializers/assets.rb`<br>`config/initializers/content_security_policy.rb`<br>`config/initializers/filter_parameter_logging.rb`<br>`config/initializers/inflections.rb` | Generated initialization points for assets, CSP guidance, sensitive-parameter filtering, and inflection customization. | Rails initialization → framework configuration. | Configuration code → initialized settings. | None beyond process configuration. | Conventional initializer locations; token filtering will be expanded when OAuth fields exist. |
| `config/locales/en.yml` | Seed location for English I18n strings. | Rails I18n → translations. | Locale keys → text. | None. | Generated Rails convention. |
| `app/controllers/application_controller.rb` | Base for future application controllers; retains generated modern-browser and importmap cache behavior. | Future controllers → Action Controller. | HTTP request → inherited behavior. | No Phase 0 endpoint inherits it. | Rails MVC convention; application-wide behavior remains separate from liveness. |
| `app/controllers/health_controller.rb` | Implements the exact stable health JSON contract with one public action. Direct `ActionController::Base` inheritance avoids unrelated application browser/session behavior. | Router → Rails `render`. | GET request → HTTP 200 JSON hash. | No action-level database or external call; response rendering only. | Entity-specific to liveness; Rails/Mastodon focused-controller pattern, adapted to JSON. |
| `app/controllers/concerns/.keep`<br>`app/models/concerns/.keep` | Preserve empty conventional concern directories without inventing concerns. | Git/file tree only. | None. | None. | Generated structure; no speculative shared behavior. |
| `app/models/application_record.rb` | Base for future Active Record models. | Future models → Active Record. | Model operations → persistence behavior. | No custom model calls it yet. | Rails model convention; reusable base. |
| `app/jobs/application_job.rb` | Base for future Active Job classes. | Future jobs → Active Job. | Job arguments → job execution. | No jobs created/enqueued in Phase 0. | Generated default, deliberately unused. |
| `app/mailers/application_mailer.rb` | Base for future mailers. | Future mailers → Action Mailer. | Mail inputs → messages. | No email sent. | Generated default. |
| `app/helpers/application_helper.rb` | Conventional application view-helper module. | Future views → helper methods. | View context → rendered values. | Empty; none. | Generated default. |
| `app/assets/stylesheets/application.css`<br>`app/assets/images/.keep` | Preserve the generated asset entry point and image directory. | Propshaft/views → assets. | Static files → served assets. | Asset compilation/serving only. | Full Rails scaffold default; not used by `/health`. |
| `app/views/layouts/application.html.erb`<br>`app/views/layouts/mailer.html.erb`<br>`app/views/layouts/mailer.text.erb` | Generated HTML and mail layouts for later development pages/messages. | Controllers/mailers → view renderer. | View content → HTML/text. | Rendering only; unused by JSON health. | Rails view convention. |
| `app/views/pwa/manifest.json.erb`<br>`app/views/pwa/service-worker.js` | Generated but unrouted PWA templates. | Would be called by commented routes → template rendering. | Template context → manifest/service worker. | None because routes remain disabled. | Preserved harmless Rails default; no PWA behavior adopted. |
| `db/seeds.rb` | Conventional future seed entry point; contains no project data. | `db:seed` → seed code. | None → no custom records. | No Phase 0 data writes from this file. | Rails database convention. |
| `lib/tasks/.keep`<br>`script/.keep`<br>`vendor/.keep` | Preserve generated extension/script/vendor directories without adding code. | File tree/tooling only. | None. | None. | Rails-generated structure; no speculative tasks/scripts/vendor code. |
| `log/.keep`<br>`tmp/.keep`<br>`tmp/pids/.keep`<br>`tmp/storage/.keep`<br>`storage/.keep` | Preserve ignored runtime directories for logs, caches, PIDs, and local storage. | Rails/tools → runtime files. | Runtime activity → ignored local artifacts. | Local filesystem writes only. | Rails-generated runtime structure. |
| `public/400.html`<br>`public/404.html`<br>`public/406-unsupported-browser.html`<br>`public/422.html`<br>`public/500.html` | Static error pages served when applicable. | Rack/web server → static responses. | HTTP errors → HTML. | File reads only. | Rails-generated public fallbacks. |
| `public/icon.png`<br>`public/icon.svg`<br>`public/robots.txt` | Generated public icon and crawler metadata. | Browser/crawler → static server. | GET → static bytes/text. | File reads only. | Generated defaults; unrelated to accounting. |
| `docs/architecture.md` | Describes current/future boundaries, dependency direction, security, scale checkpoints, and deferred options. | Developer/future phases → architecture context. | Human reading → decisions. | None. | Durable architecture documentation. |
| `docs/data_flow.md` | Records only the implemented health flow and explicitly defers future diagrams. | Developer → trace. | Human reading → request understanding. | None. | Phase-controlled documentation. |
| `docs/data_dictionary.md` | States that no custom tables exist and defines the later field-documentation shape. | Developer → schema context. | Human reading → data ownership. | None. | Data governance skeleton. |
| `docs/engineering_principles.md` | Stores durable Rails, integration, security, and scale rules. | Future work → engineering constraints. | Human reading → decisions. | None. | Project learning framework. |
| `docs/reference_review.md` | Records sources, exact files/versions, observed patterns, applicability, and rejections for Phase 0. | Future phases/reviewers → evidence. | Research → documented decision. | None. | Mandatory reference record. |
| `docs/qbo_capability_matrix.md` | Creates the required classification structure while marking every QuickBooks claim unverified. | Future entity phases → evolving capability evidence. | Official research later → verified rows. | None. | Planning/documentation only; no invented entity support. |
| `docs/references.md` | Establishes the official-Intuit evidence ledger and accurately records that Phase 0 verified no QuickBooks capability. | Future QuickBooks phases → source log. | Intuit research later → entries. | None. | QuickBooks source-of-truth boundary. |
| `docs/phase_status.md` | Captures completion, validation, limitations, blockers, and exact next command. | Future session → resume point. | Phase result → current status. | None. | Phase-control document. |
| `docs/phases/00_repository_bootstrap.md` | Provides the required learning-first Phase 0 explanation and actual validation evidence. | Developer/reviewer → phase understanding. | Implementation evidence → narrative. | None. | Entity-specific phase record. |
| `docs/decisions/0001_pragmatic_rails_monolith.md` | Records the significant, hard-to-reverse deployment/architecture choice and revisit conditions. | Future architecture reviews → decision context. | Evidence/alternatives → accepted ADR. | None. | Lightweight ADR; not one per class. |
| `docs/api_examples/.keep` | Preserves the required examples directory until a QuickBooks API flow exists. | Git/file tree only. | None. | None. | Avoids inventing Phase 0 QuickBooks examples. |

Generated `config/master.key` exists locally but is ignored by `.gitignore` and therefore is not a repository artifact. It must never be committed or exposed.

## F. Important code walkthrough

### `config/routes.rb`: `get "health" => "health#show", as: :health`

- Input: an HTTP GET whose path is `/health`, with any optional Rails format suffix.
- Return: route recognition metadata that dispatches to `HealthController#show` and exposes the `health_path` helper.
- Failures: non-GET methods do not match; an unavailable controller would fail boot/dispatch and be caught by boot/route/zeitwerk checks.
- Database/external calls: none.
- Visibility/location: the public routing DSL belongs in the only application route file.

The adjacent generated `/up` route calls the framework's `Rails::HealthController`. It is retained for default Rails tooling, but its JSON contract differs from this phase's required contract.

### `HealthController#show`

- Parameters: no domain parameters; Rails provides `request` implicitly.
- Return: terminates the request with HTTP 200 and JSON `{"status":"ok"}`.
- Exceptions/failures: ordinary Rails serialization/response failures propagate through Rails. It does not rescue broad exceptions or mask a broken boot.
- Database changes: none from the action.
- External calls: none.
- Side effects: writes an HTTP response and ordinary sanitized request log metadata.
- Public/private: `show` is public because the router invokes it.
- Correct caller: the Rails router/dispatcher.
- Incorrect callers: domain models, background jobs, or QuickBooks operations should not use a controller action as a health library.
- Why here: an HTTP representation belongs in a controller; there is no business operation to extract.

## G. Validation performed

All commands were actually run on 2026-07-14. No automated test command was run and no test files were created.

| Command/check | Actual result |
|---|---|
| `ruby --version` (system path) | Revealed macOS Ruby 2.6.10, which has no Rails and was not used. |
| `rbenv versions`; `RBENV_VERSION=3.4.6 rbenv exec ruby --version`; `... rails --version` | Found installed Ruby 3.4.6 and 3.4.9; selected the existing default 3.4.6. Confirmed Rails 8.1.3. |
| `RBENV_VERSION=3.4.6 rbenv exec rails new . --name=qbo_cfo_bridge --database=postgresql --skip-test --skip-bundle` | Generated the standard application. The generator's nested `git init` was sandbox-blocked; the scaffold itself completed. |
| `git init -b main` | Succeeded when invoked directly; repository is on `main` with no commits. |
| `RBENV_VERSION=3.4.6 rbenv exec bundle install` | First attempt could not reach Rubygems in the network sandbox. Approved retry completed: 21 Gemfile dependencies and 115 gems installed. |
| `RBENV_VERSION=3.4.6 rbenv exec bundle check` | Final dependency check printed `The Gemfile's dependencies are satisfied` (exit 0). |
| `RBENV_VERSION=3.4.6 rbenv exec ruby bin/rails db:prepare` | First attempt proved the sandbox blocked `/tmp/.s.PGSQL.5432`. Approved local-service retry created `qbo_cfo_bridge_development` and `qbo_cfo_bridge_test`. |
| `RBENV_VERSION=3.4.6 rbenv exec ruby bin/rails db:migrate:status` | Final result: database `qbo_cfo_bridge_development`; migration table displayed with no migration rows, as expected because Phase 0 has no migrations. |
| `RBENV_VERSION=3.4.6 rbenv exec ruby -c app/controllers/health_controller.rb` | `Syntax OK` (exit 0). |
| `RBENV_VERSION=3.4.6 rbenv exec ruby bin/rails runner 'puts "Rails booted successfully"'` | Printed `Rails booted successfully` (exit 0). |
| `RBENV_VERSION=3.4.6 rbenv exec ruby bin/rails routes` | Exit 0; showed `GET /up` → `rails/health#show` and `GET /health` → `health#show`, plus generated framework routes. |
| `RBENV_VERSION=3.4.6 rbenv exec ruby bin/rails zeitwerk:check` | `Hold on, I am eager loading the application.` then `All is good!` (exit 0). |
| `RBENV_VERSION=3.4.6 rbenv exec ruby bin/rubocop` | Initial run was blocked before inspection because RuboCop attempted a cache under `~/.cache`. Retry with `RUBOCOP_CACHE_ROOT=tmp/rubocop_cache` inspected 23 files: `23 files inspected, no offenses detected` (exit 0). |
| Rails server on `127.0.0.1:3000` | Initial sandbox bind failed with `Errno::EPERM`. Approved retry booted Puma 8.0.2 on Rails 8.1.3/Ruby 3.4.6 and listened successfully. |
| `curl --silent --show-error --include -H 'Accept: application/json' http://127.0.0.1:3000/health` | Approved localhost retry returned `HTTP/1.1 200 OK`, `content-type: application/json; charset=utf-8`, and `{"status":"ok"}`. Server log confirmed `HealthController#show`, 200, and zero queries during the action. Puma was then stopped gracefully. |
| `git status --short --branch` | `## No commits yet on main`; all scaffold/documentation files are untracked, as expected. No commit was created. |
| `find test spec -type f` | No files returned; test generation was skipped. |

After documentation was finalized, the boot runner, Zeitwerk check, and RuboCop command were repeated; all three again exited 0 with the same successful results recorded above.

Code-quality inspection result:

- File names and constants align for Zeitwerk.
- The request path has one route and one action; no service layer is justified.
- No model callback, HTTP client, token, financial payload, or remote call exists.
- The controller does not query all records or allocate an unbounded collection.
- No custom database constraint is needed because no custom persistence exists.
- Secrets are not committed, all `.env*` files and `config/*.key` are ignored, and the endpoint returns no configuration.

Checks not performed:

- QuickBooks readback/report reconciliation: not applicable; no QuickBooks operation exists.
- Production deployment/container execution: not required for the local Phase 0 slice.
- Git commit: prohibited unless explicitly requested.

## H. Manual sandbox validation

### Local endpoint

Status: **MANUALLY VALIDATED by Codex**

1. Ensure PostgreSQL 16 is running: `brew services start postgresql@16` if required.
2. Run `RBENV_VERSION=3.4.6 rbenv exec bundle install`.
3. Run `RBENV_VERSION=3.4.6 rbenv exec ruby bin/rails db:prepare`.
4. Start Rails: `RBENV_VERSION=3.4.6 rbenv exec ruby bin/rails server --binding 127.0.0.1 --port 3000`.
5. In another terminal, run:

   ```bash
   curl --fail-with-body --silent --show-error \
     -H 'Accept: application/json' \
     http://127.0.0.1:3000/health
   ```

6. Expected HTTP status: `200 OK`.
7. Expected response body: `{"status":"ok"}`.
8. Expected local business records: none.

### QuickBooks sandbox

Status: **NOT APPLICABLE**

No QuickBooks environment variable, sandbox company, API request, entity, readback, report, debit, credit, duplicate-avoidance step, or cleanup is relevant in Phase 0. Starting OAuth or validating a sandbox here would violate the one-phase rule.

## I. Failure scenarios

- Rails cannot boot: `/health` is unavailable, which correctly fails liveness rather than returning a false success.
- Wrong HTTP method or path: Rails returns a routing error/404; only GET is declared.
- Port already in use or process lacks bind permission: Puma fails before the request; choose an available port or grant local bind permission.
- PostgreSQL unavailable in development: the health action has no database logic, but Rails' development pending-migration middleware may access the database before dispatch. Start PostgreSQL or configure `DATABASE_URL`. Do not add QuickBooks/database probes to the action merely to mask setup errors.
- Malformed JSON/invalid input/missing fields: not relevant because this GET endpoint accepts no body or business input.
- QuickBooks/OAuth/rate-limit/timeout failures: not relevant because no external integration exists.

## J. Scale and maintenance review

- Request-volume assumption: local and deployment liveness probes at low frequency.
- Data-volume assumption: none; the endpoint does not load application data.
- Indexes/constraints: none added because no custom table exists.
- Query risks: no action query, unbounded load, pagination, or N+1. Development migration checks are framework setup behavior, not endpoint domain work.
- Background job: rejected; a liveness response must remain synchronous and immediate.
- Concurrency: the action is stateless and has no shared mutable state.
- Idempotency: GET is safe and has no write; a sync operation would be unnecessary.
- Observability: standard Rails/Puma request logging and request ID headers are sufficient now; no vendor SDK or custom instrumentation was added.
- At 10× volume: no architecture change expected; operational rate and latency monitoring may be configured outside the action.
- At 100× volume: still keep liveness dependency-free; tune web-server/probe configuration based on measurements rather than add application objects.

## K. Rollback or cleanup

No destructive cleanup was executed.

- To remove only the Phase 0 application-specific endpoint, remove the `/health` route and `app/controllers/health_controller.rb`; Rails' generated `/up` remains.
- To remove local databases, first stop Rails, verify the environment, then use `RBENV_VERSION=3.4.6 rbenv exec ruby bin/rails db:drop`. This is destructive and should only be run deliberately; it removes local development/test databases but changes no QuickBooks data or financial report.
- To remove the entire uncommitted scaffold, delete the workspace only after confirming it contains no wanted work. Do not use a destructive Git cleanup command.
- There is no QuickBooks sandbox record to delete, void, deactivate, or reverse.

## L. What comes next

Phase 1 will research and implement QuickBooks sandbox OAuth, encrypted connection state, one reusable read-only client, and CompanyInfo retrieval. It must not begin until the developer sends the exact command `START PHASE 1`.
