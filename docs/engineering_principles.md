# Engineering principles

- Rails conventions first
- Pragmatic monolith
- Explicit domain language
- Few dependencies
- Rails built-ins preferred
- No speculative abstraction
- No external API calls from models or callbacks
- No database transaction held open across an external HTTP request
- Database constraints for critical integrity
- QuickBooks writes are explicit
- Idempotency is mandatory
- OAuth secrets are encrypted and redacted
- External API hosts are allowlisted in code, not supplied by request data
- Rotated OAuth tokens replace older persisted values; stale responses must not overwrite newer rotations
- Upstream request/response bodies are not normal application logs
- Controllers coordinate HTTP concerns only
- Business and accounting rules remain outside controllers
- Payload builders remain pure
- Infrastructure code does not contain accounting policy
- Scale considerations are introduced when a real flow requires them
- Documentation explains both adopted and rejected patterns
- Packwerk, engines, and microservices are deferred until justified

These are durable project rules. Implementation details belong in the architecture, data-flow, and API
documentation.
