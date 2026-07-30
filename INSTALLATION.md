# Installation

This guide installs the database-free QuickBooks sandbox bridge for local use.

## Requirements

- Ruby 3.4.10 from `.ruby-version`
- a QuickBooks Online sandbox company
- an Intuit developer application with the Accounting scope

No PostgreSQL server, database role, `DATABASE_URL`, migration, or database preparation is required.

## 1. Install Ruby

Install Ruby with your preferred version manager, then confirm:

```bash
ruby --version
gem --version
```

Ruby must report `3.4.10`. The recommended installer provisions Bundler 2.7.2 from `Gemfile.lock` and installs the
application dependencies.

## 2. Configure the Intuit sandbox application

In the Intuit developer portal:

1. select the application's development/sandbox credentials;
2. enable the QuickBooks Accounting scope;
3. register this exact local redirect URI:

```text
http://localhost:3000/quickbooks/connections/callback
```

Production QuickBooks configuration fails closed; use development credentials for a sandbox company.

## 3. Choose a credentials source

The recommended local workflow uses ignored encrypted Rails credentials. In the next step, `bin/install` reuses
an existing credentials/master-key pair or prompts for the Intuit development Client ID and Client Secret before
creating one with this structure:

```yaml
secret_key_base: ...
quickbooks:
  client_id: ...
  client_secret: ...
  redirect_uri: http://localhost:3000/quickbooks/connections/callback
```

For an environment-only workflow, export:

```bash
export QUICKBOOKS_ENV=sandbox
export QUICKBOOKS_CLIENT_ID="your-development-client-id"
export QUICKBOOKS_CLIENT_SECRET="your-development-client-secret"
export QUICKBOOKS_REDIRECT_URI="http://localhost:3000/quickbooks/connections/callback"
```

Never paste decrypted credentials or OAuth tokens into logs, documentation, screenshots, or issue trackers.
Existing unused Active Record encryption entries in a developer-owned credentials file may remain, but this
application neither generates nor requires them.

## 4. Run setup

For the recommended encrypted-credentials workflow, run:

```bash
bin/install
```

The installer selects the Bundler version from `Gemfile.lock`, installs missing gems, creates ignored encrypted
credentials when needed, validates the sandbox configuration, and runs `bin/setup --skip-server`. It never
creates, prepares, migrates, or connects to a database.

If all QuickBooks settings are supplied through environment variables, prepare the application without creating
local encrypted credentials:

```bash
gem install bundler --version 2.7.2 --no-document
bin/setup --skip-server
```

## 5. Start the application

```bash
bin/dev
```

Open:

```text
http://localhost:3000/quickbooks/connections
```

Choose **Connect a QuickBooks sandbox**, complete Intuit consent, and return to the connection page. Rails stores
the access and refresh tokens only in its current process. The browser session stores only the opaque connection
UUID and temporary OAuth state.

## 6. Open a GET/POST dashboard

The connected-company page provides four interfaces:

- `/quickbooks/connections/:connection_id/journal_entries` for financial records;
- `/quickbooks/connections/:connection_id/transactions` for sales and payables;
- `/quickbooks/connections/:connection_id/operations` for workforce, tax, and inventory; and
- `/api-docs` for the Swagger GET/POST console.

Swagger has no bearer-token input, Authorize workflow, or protected-operation locks. It exposes GET and POST
controls only. Use the opaque connection handle displayed on the connection page for `{connection_id}`.

For POST, Swagger automatically supplies the same-origin Rails session and CSRF header and asks for one explicit
confirmation. Every execution is a fresh sandbox write and can create a duplicate. The application performs no
local idempotency, replay, audit, or duplicate-name preflight.

## Runtime constraints

- Run one Rails/Puma process with normal thread concurrency.
- Do not set `WEB_CONCURRENCY`, use Puma `--workers`, or deploy multiple replicas.
- Restarting Rails loses the connection and requires OAuth reconnection.
- Development code reload may also replace the in-memory store.
- Existing PostgreSQL records are not read or migrated.
- The design is sandbox-only and unsuitable for production.

Production would require encrypted persistent realm/refresh-token storage, durable ownership, multi-process
coordination, and operational recovery controls.

## Optional settings

```bash
export QUICKBOOKS_MINOR_VERSION=75
export QUICKBOOKS_OPEN_TIMEOUT=5
export QUICKBOOKS_READ_TIMEOUT=10
```

The dashboard is enabled automatically in development. Outside development, explicitly set:

```bash
export ENABLE_QUICKBOOKS_CONNECTION_DASHBOARD=true
```

This does not make the application production-ready.

## Verification

After setup, run the same complete pipeline used by CI:

```bash
bin/ci
```

It checks Rails boot and Zeitwerk loading, runs the Rails tests, checks formatting and style, and performs
dependency and static security audits. It does not start the server or contact QuickBooks.

For focused checks:

```bash
bin/install --check
bin/rails test
bin/format check
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit
bin/rails zeitwerk:check
bin/rails routes
node --check app/assets/javascripts/api_docs.js
```

`bin/install --check` validates the ignored encrypted credentials/master-key pair. Skip that command when the
application is configured only through environment variables.

## Troubleshooting

- **Configuration missing:** set the three `QUICKBOOKS_*` values or add them to encrypted credentials.
- **Redirect URI rejected:** make the Intuit portal value and `QUICKBOOKS_REDIRECT_URI` identical.
- **Production disabled:** ensure `QUICKBOOKS_ENV=sandbox`.
- **Reconnect required:** Rails restarted, reloaded, evicted the in-memory value, or the browser session changed.
- **Puma worker error:** remove `WEB_CONCURRENCY` and any `--workers` option.
- **Swagger POST blocked locally:** reconnect, remain on the same origin, and confirm the page includes Rails'
  CSRF meta tag.
- **Ambiguous POST failure:** do not retry automatically; inspect the QuickBooks sandbox first because the entity
  may have been created.
