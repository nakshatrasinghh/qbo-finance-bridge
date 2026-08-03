# Ruby CFO Bridge

Ruby CFO Bridge is a Rails 8.1 application for working with a QuickBooks Online sandbox through three focused
HTML dashboards and a Swagger API console. Rails exposes 28 finance operations while keeping every OAuth token
and QuickBooks request on the server.

```text
Browser / Swagger UI
  -> same-origin Rails controller
  -> entity-specific validation and accounting rules
  -> QuickBooks Online sandbox
  -> QuickBooks readback and Rails verification
  -> normalized JSON response
```

Rails is the only QuickBooks client. The browser never receives an Intuit access token, refresh token, client
secret, or Authorization header.

## Current runtime model

- Database-free and PostgreSQL-free.
- One process-local QuickBooks sandbox connection per browser session.
- OAuth tokens exist only in the Rails process memory store.
- The Rails session contains only an opaque connection UUID, plus temporary OAuth state during connection.
- Restarting Rails discards the connection. Development code reload can do the same.
- Multiple Puma workers and multiple application replicas are unsupported.
- Existing PostgreSQL records are intentionally abandoned and are not migrated.
- There is no local audit history, request replay, idempotency ledger, or submission-status polling.
- Create flows do not perform application-level duplicate-name checks.
- Every deliberate POST is a new operation and can create a duplicate sandbox record.
- Every outbound QuickBooks POST receives a fresh server-generated QBO `requestid`.
- This is a sandbox-only demonstration and is unsuitable for production.

A production design would require encrypted persistent refresh-token and realm storage, durable ownership,
multi-process coordination, recovery evidence, and a separate production-readiness review.

## GET/POST dashboards

After connecting a sandbox company, the connection page links to:

- `/quickbooks/connections/:connection_id/journal_entries` for financial records;
- `/quickbooks/connections/:connection_id/transactions` for sales and payables;
- `/quickbooks/connections/:connection_id/operations` for workforce, tax, and inventory; and
- `/api-docs` for the Swagger GET/POST console.

The three HTML dashboards and Swagger call the same connection-scoped Rails endpoints. Replace
`:connection_id` with the opaque handle shown on the connected-company page. POST creates a real sandbox record,
and repeating a POST may create a duplicate.

## Browser and internal API boundaries

Rails exposes two QuickBooks API namespaces because browser requests and service-to-service requests have
different authorization and connection-selection rules:

| Consumer | Namespace | Connection selection | Allowed operations |
| --- | --- | --- | --- |
| Rails dashboards and Swagger | `/api/v1/quickbooks/connections/:connection_id/...` | The URL UUID must match the opaque UUID in the signed and encrypted Rails browser session | GET and the explicitly supported sandbox POST operations |
| FastAPI/MCP backend | `/internal/v1/quickbooks/...` | Rails selects the current operator-managed, process-local connection; the caller supplies no UUID or cookie | GET only |

The browser UUID is an opaque handle into Rails process memory. It is not a QuickBooks company ID, realm ID, or
OAuth token. Requiring the URL handle to match the session handle prevents one browser session from selecting
another session's connection. The internal API does not use this browser ownership model: FastAPI never copies or
receives a Rails session cookie, connection UUID, realm ID, or QuickBooks credential.

Add a new endpoint only to the namespace used by its consumer:

- browser or Swagger operation: add it under `/api/v1/...`;
- FastAPI/MCP read: add it under `/internal/v1/...`;
- operation needed by both: expose two thin routes/controllers that share the same QuickBooks query and serializer;
- write operation: keep it under `/api/v1/...`; never expose it through `/internal/v1/...`.

The internal API is loopback-only in development and test and is disabled by default in production. It returns 404
to unauthorized callers. Azure deployment requires workload-level service authentication before the internal API
can be enabled; browser session authentication must not be reused for that purpose. Because the connection store is
database-free, a Rails restart requires an operator to reconnect in the Rails UI, but FastAPI needs no copied value,
restart, or reconfiguration.

## Finance API

API contract version 2.0.0 contains exactly 28 finance operations:

| Capability | GET | POST |
| --- | ---: | ---: |
| Eligible Accounts | 1 | 0 |
| Financial reports: Profit & Loss, Balance Sheet, Cash Flow, General Ledger, Trial Balance | 5 | 0 |
| Journal Entries | 1 | 1 |
| Employees | 1 | 1 |
| Time Activities | 1 | 1 |
| Tax Codes | 1 | 1 |
| Inventory Items | 1 | 1 |
| Customers | 1 | 1 |
| Vendors | 1 | 1 |
| Invoices | 1 | 1 |
| Bills | 1 | 1 |
| Customer Payments | 1 | 1 |
| Bill Payments | 1 | 1 |
| **Total** | **17** | **11** |

`GET /health` is a separate liveness endpoint and is not included in those finance counts.

Each of the eleven entity-specific `Submit` objects keeps an explicit request path:

1. accept only allowlisted input;
2. normalize decimal strings with `BigDecimal` and dates with strict ISO 8601 parsing;
3. apply entity-specific accounting and current-reference validation;
4. make one QuickBooks sandbox POST with an internal UUID `requestid`;
5. read the entity back by its QuickBooks ID;
6. verify the readback;
7. serialize the verified entity and return HTTP 201.

The application does not preflight Customer, Vendor, Inventory Item, or Tax Code names for duplicates. QuickBooks
may still reject a request under its own rules. Ambiguous POST failures are never retried automatically and Rails
does not claim whether QuickBooks created the entity.

## Swagger API console

After connecting a sandbox company, open:

```text
http://localhost:3000/api-docs
```

Swagger exposes GET and POST only. The OpenAPI document has no browser bearer scheme, login control, or
operation-level security declaration. For a same-origin POST, the Swagger initializer:

- reads the Rails authenticity token from the page;
- adds `X-CSRF-Token`;
- sends the current same-origin Rails session cookie;
- displays one confirmation before the request;
- aborts locally if the URL is cross-origin, the token is absent, or the user cancels.

POST creates a real record in the connected QuickBooks sandbox. Repeating Execute may create another record.

## Requirements and setup

- Ruby 3.4.10
- Bundler 2.7.2
- Rails 8.1.3.1
- one Intuit developer sandbox application

PostgreSQL, SQLite, Redis, and another persistence service are not required.

Follow [INSTALLATION.md](INSTALLATION.md) to enable the Accounting permission, copy the application's Development
Client ID and Client Secret, and register the exact local callback URI in the Intuit Developer Portal.
`bin/install` does not retrieve or remotely validate those values; it prompts for them and stores them in ignored
encrypted Rails credentials.

The recommended first-time local setup is:

```bash
bin/install
bin/dev
```

Open `http://localhost:3000/quickbooks/connections`, connect a sandbox, and choose an HTML dashboard or Swagger.
Intuit must be configured with the exact callback URI shown in the installation guide.

## Configuration

The application accepts these secrets from environment variables or encrypted Rails credentials:

```yaml
secret_key_base: ...
quickbooks:
  client_id: ...
  client_secret: ...
  redirect_uri: http://localhost:3000/quickbooks/connections/callback
```

Runtime settings:

| Variable | Default | Purpose |
| --- | --- | --- |
| `QUICKBOOKS_ENV` | `sandbox` | Must remain `sandbox`; another value fails closed |
| `QUICKBOOKS_CLIENT_ID` | credentials | Intuit client ID |
| `QUICKBOOKS_CLIENT_SECRET` | credentials | Intuit client secret |
| `QUICKBOOKS_REDIRECT_URI` | credentials | Exact OAuth callback URI |
| `QUICKBOOKS_MINOR_VERSION` | `75` | Minimum supported QBO minor version |
| `QUICKBOOKS_OPEN_TIMEOUT` | `5` | Connection timeout in seconds |
| `QUICKBOOKS_READ_TIMEOUT` | `10` | Response timeout in seconds |
| `ENABLE_QUICKBOOKS_CONNECTION_DASHBOARD` | development only | Explicitly expose the local dashboard outside development |
| `QUICKBOOKS_INTERNAL_API_AUTH_MODE` | `loopback` outside production; `disabled` in production | Restrict or disable the FastAPI/MCP read API; production rejects `loopback` |

Do not configure `WEB_CONCURRENCY`; this process-local design deliberately runs Puma in single mode.

## Security boundaries

- OAuth state is time-limited and compared securely.
- API connection handles must match the current browser session and missing process state returns
  `quickbooks_reconnect_required` with HTTP 401.
- Rails CSRF protection remains enabled for Swagger and dashboard POSTs.
- QuickBooks hosts are fixed server-side and production selection fails closed.
- Token and secret parameter names are filtered from logs.
- Token-bearing value objects redact inspection and are never rendered or serialized.
- Disconnect revocation and token refresh share the same per-connection synchronization boundary.

## Verification

Run the complete local verification pipeline:

```bash
bin/ci
```

After setup, `bin/ci` verifies Rails boot and Zeitwerk loading, runs the Rails test suite, checks Ruby formatting
and style, and runs dependency and static security audits. These checks do not make a live QuickBooks request.

Use `bin/install --check` to validate an ignored local credentials pair and sandbox configuration. Use
`node --check app/assets/javascripts/api_docs.js` for a focused JavaScript syntax check.

## Current documentation

- [Installation](INSTALLATION.md)
- [Architecture](docs/architecture.md)
- [Data flow](docs/data_flow.md)
- [Data dictionary](docs/data_dictionary.md)
- [OpenAPI contract](docs/openapi.yaml)
- [Capability matrix](docs/qbo_capability_matrix.md)
- [QuickBooks data model](docs/quickbooks_data_model.md)
- [QuickBooks data normalization](docs/quickbooks_data_normalization.md)
- [Engineering principles](docs/engineering_principles.md)
