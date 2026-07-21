# ADR 0001: Use a pragmatic Rails monolith

Status: Accepted
Date: 2026-07-14

## Context

The application must teach and validate one QuickBooks accounting flow at a time. It currently has one liveness endpoint, no custom tables, no external client, no OAuth, and no operational evidence that multiple deployments or enforced packages would improve delivery.

## Decision

Build one conventional Rails 8.1 application backed by PostgreSQL. Use Rails' generated structure and integrated defaults. Add clear Ruby namespaces and small domain-specific objects only when an implemented flow needs a real boundary. Keep QuickBooks HTTP infrastructure centralized when it is introduced, while keeping accounting policy entity-specific.

## Alternatives considered

- Microservices or separate repositories: rejected because distributed calls, deployments, and failure modes would obscure the learning flow without providing current value.
- Rails Engines for internal organization: rejected because no independently mounted or reusable subsystem exists.
- Packwerk packages: deferred because there are not yet multiple domains with demonstrated dependency violations.
- Generic service, repository, command-bus, or dependency-injection layers: rejected because Rails controllers/models and focused plain Ruby collaborators will provide simpler boundaries as needed.
- API-only Rails: rejected for now because the backlog includes a minimal development-only connection page, and the full standard Rails scaffold is a reasonable generated default.

## Consequences

- A developer can trace requests through familiar Rails locations.
- Database transactions, external calls, mappings, and idempotency can remain in one deployable system while still having explicit boundaries.
- Generated components such as Solid Queue/Cache/Cable and Kamal remain available but are not adopted for business flows before their phases justify them.
- Namespace discipline and documentation carry modularity initially; this requires periodic architecture review as the code grows.

## Evidence

- Rails Doctrine: convention over configuration, the omakase stack, and integrated systems.
- Rails 8.1.3 generated application structure and built-in health endpoint.
- Mastodon's current focused health controller demonstrates that even a large Rails application can keep liveness behavior small and conventional.
- Full evidence and inspected paths are recorded in `docs/reference_review.md`.

## Revisit conditions

Reconsider package tooling, engines, background processing, or deployment boundaries only when implemented flows show repeated cross-domain coupling, ownership/deployment needs, job durability requirements, or scale evidence that namespace conventions cannot address. Formal checkpoints occur after Phases 4, 8, 12, 20, and 30.
