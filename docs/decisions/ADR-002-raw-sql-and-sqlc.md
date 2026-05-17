# ADR-002: Use Raw SQL With sqlc Instead Of GORM

## Status

Accepted

## Context

The backend has important transactional and data-isolation requirements:

- checkout idempotency
- country-partitioned reads and writes
- explicit order and order-item transactions
- immutable price and customization snapshots
- worker retry safety
- predictable SQL for assessment review

An ORM would speed up early CRUD, but it hides query shape and can blur ownership around transactions. For this assignment, visible SQL is more valuable than ORM convenience.

## Decision

Use `database/sql` for connections and transactions. Use `sqlc` as the preferred lightweight query layer once repositories need typed query methods.

Handwritten SQL migrations and queries are the source of truth. Repositories call generated `sqlc` code or direct `database/sql` for small bootstrap paths.

## Alternatives Considered

- **GORM**: convenient for CRUD and model tags, but too implicit for checkout/order-worker correctness and makes generated SQL less obvious during review.
- **sqlx**: lighter than GORM and keeps handwritten SQL, but does not generate compile-time checked query methods from SQL files.
- **database/sql only**: minimal dependency footprint, but scanning boilerplate grows quickly once catalog and order queries expand.

## Consequences

Positive:

- SQL behavior is reviewable and predictable.
- Transactions remain explicit.
- Generated methods reduce repetitive row scanning.
- The codebase avoids ORM model/tag drift.

Negative:

- More upfront SQL writing.
- Schema changes require query regeneration.
- Developers need to understand SQL instead of relying on ORM associations.

## Trade-Off

The backend prioritizes correctness, auditability, and explicit transactional behavior over rapid ORM-based CRUD scaffolding.

## Implementation Notes

- `internal/platform/database` owns `*sql.DB` setup and pool configuration.
- Domain repositories own query usage and transaction boundaries.
- `sqlc` generated code should stay under a platform or generated package, not inside domain models.
- Domain types should not contain database tags.
- Migrations should be plain SQL files and run separately from application startup.
