# ADR 0002: Direct QuickBooks REST client

- Status: Accepted for sandbox use
- Date: 2026-07-14

## Context

The application must make QuickBooks behavior visible to a developer learning the integration: host, method,
realm-scoped path, minor version, bearer header, JSON boundary, OAuth refresh, bounded retry, timeout, Intuit fault
status, and correlation metadata. The same client supports CompanyInfo and entity-specific reads and writes.

A large QuickBooks SDK could hide those mechanics and introduce its own object model. Calling Faraday from each operation would keep requests visible but duplicate authentication, refresh, timeout, error, and logging rules. A generic `BaseApiClient` would abstract a second vendor that does not exist.

## Decision

Use Faraday through one QuickBooks-specific `Quickbooks::Client` for Accounting API requests and one narrow `Quickbooks::Oauth::TokenClient` collaborator for Intuit's distinct token/revocation hosts and encodings.

`Quickbooks::Client` owns:

- the fixed sandbox Accounting API base URL;
- connection/realm scoping;
- bearer authorization;
- GET and explicitly approved POST requests;
- explicit minor version;
- connect/read timeouts;
- proactive expiry detection and one retry after refresh;
- safe persistence of rotated tokens;
- JSON parsing, fault/status normalization, and sanitized instrumentation.

Entity-specific operations own entity paths, validated payloads, accounting behavior, and response-shape checks. Controllers, models, payload builders, and entity operations do not call Faraday directly.

## Alternatives considered

- **Official/third-party QuickBooks Ruby SDK:** rejected because it obscures the direct REST learning objective,
  adds a larger compatibility/maintenance surface, and is unnecessary for the supported operations.
- **Ruby `Net::HTTP` directly:** viable and dependency-free, but Faraday 2.14.3 provides a maintained explicit connection/adapter API, normalized timeout/connection exceptions, and an exit path to another adapter without creating a custom HTTP framework.
- **Faraday in each entity operation:** rejected because token refresh, retry, timeouts, and safe errors would diverge.
- **Generic external API base client:** rejected because QuickBooks is the only external integration and its realm/minor-version/fault behavior is vendor-specific.
- **Background job for all requests:** deferred until synchronous flows are understood and real duration/volume requires asynchronous execution.

## Consequences

- Direct request behavior remains inspectable and consistent.
- Faraday is the only new runtime dependency and is isolated at the infrastructure boundary.
- The client is intentionally QuickBooks-specific and can evolve without pretending other vendors share its semantics.
- OAuth has a separate narrow transport because its hosts, Basic authentication, and form/revocation bodies differ from Accounting API calls.
- The current row-lock strategy prevents stale token overwrite but does not fully serialize refresh calls across processes.
- Production URLs are known constants, but production selection hard-fails until a dedicated readiness review.

## Evidence

- Intuit: [Set up OAuth 2.0](https://developer.intuit.com/app/developer/qbo/docs/develop/authentication-and-authorization/oauth-2.0)
- Intuit: [Create basic requests](https://developer.intuit.com/app/developer/qbo/docs/get-started/create-a-request)
- Intuit: [REST API features](https://developer.intuit.com/app/developer/qbo/docs/learn/rest-api-features)
- Rails: [Active Record Encryption](https://guides.rubyonrails.org/active_record_encryption.html)
- Faraday: [official documentation](https://lostisland.github.io/faraday/)
- Mature implementation review: Mastodon `app/lib/request.rb` at commit `d70f1f983c945b3aa4c2089e540c67d706d762d9` and Discourse OAuth files at commit `939248f3690e3557207a3e4cd90bb7760201d4b0`.

## Revisit conditions

Reconsider this decision if Intuit requires SDK-only behavior, direct maintenance becomes unsafe, a second external integration reveals a genuinely stable shared transport concern, or measured multi-process refresh races require a dedicated coordinator. Do not generalize merely because several QuickBooks entities reuse this same client.
