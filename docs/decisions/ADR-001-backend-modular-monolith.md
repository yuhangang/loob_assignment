# ADR-001: Use A Profiled Go Modular Monolith For The Backend

## Status

Accepted

## Context

The Loob assessment needs to demonstrate credible architecture for a multi-brand, multi-country ordering app. The backend must support menu browsing, checkout, order status, vouchers, campaigns, and flash-sale traffic behavior.

The current repository is a small Go Echo service. A full microservices implementation would add unnecessary operational complexity for the assessment, but a flat monolith would make the checkout and worker boundaries unclear.

## Decision

Use a Go modular monolith with explicit runtime profiles:

- `api`: serves Echo HTTP endpoints for mobile and admin clients.
- `worker`: consumes order intents from SQS and writes durable orders.

The codebase remains one Go module. Business domains are split into internal packages such as `catalog`, `checkout`, `ordering`, `campaigns`, and `users`. Infrastructure concerns live under `internal/platform`.

## Alternatives Considered

- **Flat monolith**: fastest to start, but encourages business logic in handlers and makes async checkout hard to reason about.
- **Microservices**: clean independent deployments, but too much infrastructure, coordination, and transaction complexity for the assignment timeline.
- **Serverless functions**: good burst scaling, but weaker fit for a cohesive Go domain model and local development flow in this repo.

## Consequences

Positive:

- Clear implementation boundaries without service sprawl.
- API and worker can scale independently in ECS/Fargate later.
- Checkout can be made queue-first without splitting repositories.
- Local development remains simple.

Negative:

- Package discipline must be enforced by review and tests.
- All domains still share one release artifact.
- The database remains shared, so ownership rules must be documented and followed.

## Trade-Off

The architecture prioritizes implementation speed, local testability, and clear order-processing boundaries over maximum independent deployability.

## Implementation Notes

- `cmd/api` and `cmd/worker` should be separate entrypoints.
- Domain packages must not import Echo, `database/sql`, generated SQL code, Redis, or AWS SDK types.
- External integrations should sit behind small interfaces owned by the consuming domain.
- Queue messages must carry `trace_id`, `country_code`, schema version, and idempotency identifiers.
