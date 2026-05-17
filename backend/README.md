# Loob Unified App: Backend

This directory contains the Go backend for the Loob Unified App assessment.

## Architecture

The backend should be implemented as a profiled Go modular monolith:

- `api` profile: serves Echo HTTP APIs for the Flutter app and admin panel.
- `worker` profile: consumes queued order intents and persists orders asynchronously.

The implementation contract lives in [`../docs/architecture/BACKEND_ARCHITECTURE.md`](../docs/architecture/BACKEND_ARCHITECTURE.md). Accepted architecture decisions are documented in [`../docs/decisions/ADR-001-backend-modular-monolith.md`](../docs/decisions/ADR-001-backend-modular-monolith.md) and [`../docs/decisions/ADR-002-raw-sql-and-sqlc.md`](../docs/decisions/ADR-002-raw-sql-and-sqlc.md).

### Tech Stack

- **Language:** Go
- **Framework:** Echo v4
- **Database:** MySQL 8 locally, Aurora MySQL-compatible in the target cloud design
- **Persistence:** Raw SQL via `database/sql`; `sqlc` planned for typed query generation
- **Caching/status:** Redis
- **Queue:** AWS SQS FIFO for order intents
- **Authentication:** Firebase Auth Admin SDK, planned for authenticated checkout/admin paths
- **API Documentation:** Swagger / OpenAPI

## Local Setup

### Prerequisites
*   Go 1.25 or higher
*   Docker & Docker Compose

### Installation
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   go mod tidy
   ```
3. Start the infrastructure (MySQL & Redis) using Docker:
   ```bash
   docker-compose up -d
   ```
4. Configure environment variables:
   ```bash
   cp .env.example .env
   # Update .env if necessary
   ```

### Running The API

Start MySQL and Redis from the backend directory:

```bash
docker compose up -d db redis
```

Then start the API profile from this directory:

```bash
go run ./cmd/api
```

### Testing

Run all unit tests in the backend:

```bash
go test ./...
```

To run tests with coverage:

```bash
go test -cover ./...
```

To run tests for a specific module (e.g., catalog):

```bash
go test ./internal/catalog/...
```


### Database Seeding

To populate the database with realistic regional data (brands, stores, categories, and menu items), use the seeding tool:

```bash
# Seed all countries
go run ./cmd/seed

# Seed only Malaysia
COUNTRY=MY go run ./cmd/seed

# Seed only Thailand
COUNTRY=TH go run ./cmd/seed

# Clear existing data before seeding
CLEAN=true go run ./cmd/seed
```

The seed data is managed via JSON files in `cmd/seed/data/`.

By default the API applies SQL migrations from `sql/migrations` at startup. Set `AUTO_MIGRATE=false` to disable this behavior.

Useful smoke checks:

```bash
curl -sS http://127.0.0.1:8080/health
curl -sS -H 'X-Country-Code: MY' -H 'Accept-Language: ms-MY' 'http://127.0.0.1:8080/api/v1/catalog/categories?store_id=1'
curl -sS -H 'X-Country-Code: MY' -H 'Accept-Language: ms-MY' 'http://127.0.0.1:8080/api/v1/catalog/categories/1/items?store_id=1'
curl -sS -H 'X-Country-Code: MY' 'http://127.0.0.1:8080/api/v1/catalog/stores'
curl -sS -H 'X-Country-Code: MY' 'http://127.0.0.1:8080/api/v1/campaigns/home'
curl -sS -H 'X-Country-Code: MY' 'http://127.0.0.1:8080/api/v1/vouchers/wallet?user_id=demo-user'
```

Mock payment gateway callback:

```bash
curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -H 'X-Mock-Gateway-Secret: change-me-local-only' \
  -d '{"transaction_id":"PAY-MY-EXAMPLE","gateway_reference":"mock-ref-1","gateway_event_id":"evt-1","status":"success"}' \
  http://127.0.0.1:8080/api/v1/payments/mock-gateway/callback
```

Set `MOCK_GATEWAY_SECRET` in your environment before using the mock callback endpoint.
Set `PUBLIC_BASE_URL` to the API origin used by mobile clients so app config and feed assets do not point at localhost outside local development.

The worker profile exists as a separate entrypoint, but SQS consumption is not wired yet:

```bash
go run ./cmd/worker
```

## API Documentation (Postman)

This project uses `swaggo/swag` to automatically generate OpenAPI/Swagger documentation from code comments.

1. Ensure the swag CLI is installed:
   ```bash
   go install github.com/swaggo/swag/cmd/swag@latest
   ```
2. Generate the documentation:
   ```bash
   ~/go/bin/swag init -g main.go --output docs
   ```
3. **Import to Postman:** Open Postman, click "Import", and select the `backend/docs/swagger.json` file. Postman will automatically generate the collection with the correct endpoints and header configurations.

## Core Concepts

- **Contextual routing:** Public reads use `X-Country-Code` and `Accept-Language`; checkout requires a validated country context.
- **Lean mobile payloads:** The backend resolves translations, country pricing, and tax rules before returning data to Flutter.
- **Async checkout:** Checkout should enqueue an order intent and return `202 Accepted` only after SQS accepts the message.
- **Worker-owned persistence:** Durable order creation belongs to the worker profile, not the HTTP request path.
- **Traceability:** API and worker logs should carry the same `trace_id` and `order_tracking_id`.
