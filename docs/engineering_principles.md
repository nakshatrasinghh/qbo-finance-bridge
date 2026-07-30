# Engineering principles

## Obvious Rails request flow

Prefer conventional controllers and explicit domain objects:

```text
route -> controller -> entity Submit -> entity Create -> Quickbooks::Client -> readback -> serializer
```

Controllers own HTTP concerns. Entity objects own accounting rules and payload verification. The QuickBooks
client owns transport. The process store owns connection lifecycle and synchronization.

## Deliberate Ruby

- Use intention-revealing domain names.
- Use keyword arguments at multi-value boundaries and keyword/hash shorthand where supported.
- Do not rebind a value to itself or create a same-value local alias merely to rename it.
- Avoid parameter/local shadowing.
- Prefer guard clauses and small cohesive methods.
- Do not add `ApplicationService`, generic repositories, result monads, dynamic dispatch, or metaprogramming to
  compress eleven explicit entity flows.
- Use `Time.current`, strict ISO 8601 date parsing, `BigDecimal`, and `SecureRandom.uuid`.
- Use `Hash#fetch` for required internal keys and bounded allowlists for untrusted input.

## Security

- Keep OAuth access/refresh tokens and Intuit client secrets in server memory or encrypted credentials only.
- Never log, inspect, serialize, render, or return tokens or Authorization headers.
- Keep only the opaque connection UUID in the Rails session after OAuth.
- Preserve OAuth state validation, CSRF, TLS verification, parameter filtering, and revocation.
- Fix QuickBooks hosts server-side and reject production configuration.

## Concurrency

MemoryStore's individual operations are thread-safe; refresh and disconnect are compound operations and must use
the same per-connection lock. Re-fetch and re-check after acquiring the lock. Replace immutable connection
values; never mutate token fields in place.

Do not hold a database transaction—or any broad global lock—across an external HTTP call.

## Writes

- Each POST is one deliberate sandbox operation.
- Generate QBO `requestid` inside the outbound client, never from caller input.
- Never automatically retry an ambiguous POST.
- Perform current-reference/accounting validation and verify a QuickBooks readback.
- Do not maintain local idempotency, replay, audit, submission state, or create-time duplicate-name checks.
- Make no unsupported claim about an ambiguous result.

## Scope

This is a database-free, single-process sandbox demonstration. Prefer the smallest coherent implementation.
Production persistence, worker coordination, background jobs, modular packaging, or another integration layer
would require a separate architecture and security review.
