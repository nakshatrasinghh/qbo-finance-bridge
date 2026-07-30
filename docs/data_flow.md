# Data flow

All application traffic follows a same-origin browser-to-Rails boundary. Rails is the only QuickBooks client,
and connection state exists only in the current Rails process.

## OAuth connection

```mermaid
sequenceDiagram
  participant B as Browser
  participant R as Rails
  participant I as Intuit OAuth
  participant M as Process memory

  B->>R: GET /quickbooks/connections/connect
  R->>R: Store expiring OAuth state in Rails session
  R-->>B: Redirect to Intuit sandbox consent
  B->>I: Approve accounting scope
  I-->>R: Callback with code, realmId, and state
  R->>R: Consume and securely compare state
  R->>I: Exchange code server-side
  I-->>R: Access/refresh token set
  R->>M: Store immutable SandboxConnection under UUID
  R->>R: Store only UUID in Rails session
  R-->>B: Redirect to connection page
```

The browser never receives the token response. Production selection fails closed.

## GET through Swagger

```mermaid
sequenceDiagram
  participant S as Swagger UI
  participant R as Rails API
  participant M as Process-local store
  participant Q as QuickBooks sandbox

  S->>R: GET finance route with opaque connection UUID
  R->>R: Match route UUID to session UUID
  R->>M: Fetch connection
  alt token expired
    R->>M: Acquire per-connection lock and re-fetch
    R->>Q: Refresh latest token once
    Q-->>R: Rotated token set
    R->>M: Replace immutable connection
  end
  R->>Q: Realm-scoped GET
  Q-->>R: QuickBooks JSON
  R-->>S: Normalized JSON
```

A GET may refresh once and retry once after a 401. It never writes accounting data.

## POST through Swagger

```mermaid
sequenceDiagram
  participant U as User
  participant S as Swagger UI
  participant R as Rails API
  participant D as Entity Submit/Create
  participant Q as QuickBooks sandbox

  U->>S: Execute POST
  S->>U: Confirm real sandbox write and duplicate risk
  U-->>S: Confirm
  S->>S: Add same-origin session and X-CSRF-Token
  S->>R: POST allowlisted JSON
  R->>R: Match connection UUID and session
  R->>D: Validate and normalize input
  D->>Q: Read current references where required
  D->>Q: One POST with server-generated requestid
  Q-->>D: Created entity ID
  D->>Q: GET entity by ID
  Q-->>D: Readback
  D->>D: Verify and serialize
  D-->>R: Verified entity
  R-->>S: HTTP 201 entity JSON
```

Cancellation, a missing CSRF token, or a cross-origin target is blocked before the network request. The OpenAPI
document has no OAuth/bearer scheme.

Rails performs no application-level duplicate-name query before create. Every confirmed execution is a new
operation with a new QBO `requestid` and can create a duplicate.

If the QBO POST times out or has another ambiguous transport failure, Rails does not retry and does not claim
whether the entity exists. There is no local uncertain state; inspect QuickBooks before deciding to retry.

## Concurrent refresh and disconnect

```mermaid
sequenceDiagram
  participant A as Request A
  participant B as Request B
  participant M as Store lock
  participant I as Intuit

  A->>M: Acquire connection lock
  A->>M: Re-fetch and check expiry
  B->>M: Wait for same connection lock
  A->>I: Refresh latest token
  I-->>A: Rotated tokens
  A->>M: Replace connection and release
  B->>M: Acquire, re-fetch, see rotation
  B-->>B: Reuse current connection
```

Disconnect shares this lock, revokes the latest refresh token, and deletes the value before releasing it.

## Connection loss

When the Rails process restarts, reloads, or loses the cache entry:

```json
{
  "error": {
    "code": "quickbooks_reconnect_required",
    "message": "The QuickBooks sandbox connection is missing or expired. Reconnect QuickBooks."
  }
}
```

The API returns HTTP 401. No database fallback or migration exists.
