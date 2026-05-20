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
- **Persistence:** Raw SQL via `database/sql`;
- **Caching/status:** Redis
- **Queue:** AWS SQS FIFO as the target cloud adapter for post-payment order processing
- **Authentication:** Firebase ID token verification, with explicit local mock mode for assessment runs
- **API Documentation:** Swagger / OpenAPI

## Local Setup

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

Authenticated user-owned APIs require `Authorization: Bearer <token>`.

- For local assessment runs without Firebase credentials, use `AUTH_MODE=mock`. Mock tokens are accepted only in this explicit mode.
- For Firebase verification, set `AUTH_MODE=firebase` and `FIREBASE_PROJECT_ID`, then send Firebase Auth ID tokens from the mobile app.
- The backend derives `user_id` from the verified token subject. Client-supplied `user_id` query/body/header values are ignored on protected endpoints.

Catalog Redis cache settings use Go duration strings:

- `CATALOG_MENU_CACHE_TTL`, default `24h`
- `CATALOG_STORE_CONTEXT_CACHE_TTL`, default `5m`
- `CATALOG_MENU_REBUILD_LOCK_TTL`, default `10s`

Useful smoke checks:

```bash
curl -sS http://127.0.0.1:8080/health
curl -sS -H 'X-Country-Code: MY' -H 'Accept-Language: ms-MY' 'http://127.0.0.1:8080/api/v1/catalog/categories?store_id=1'
curl -sS -H 'X-Country-Code: MY' -H 'Accept-Language: ms-MY' 'http://127.0.0.1:8080/api/v1/catalog/categories/1/items?store_id=1'
curl -sS -H 'X-Country-Code: MY' 'http://127.0.0.1:8080/api/v1/catalog/stores'
curl -sS -H 'X-Country-Code: MY' 'http://127.0.0.1:8080/api/v1/campaigns/home'
curl -sS -H 'Authorization: Bearer <firebase-id-token>' -H 'X-Country-Code: MY' 'http://127.0.0.1:8080/api/v1/vouchers/wallet'
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

The worker profile exists as a separate entrypoint, but the local assignment checkout flow is payment-first: checkout creates a `PAYMENT_PENDING` order intent plus payment transaction, and the mock gateway callback moves successful payments to `READY_TO_COLLECT`. SQS consumption is not required for the local assessment runtime.

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
- **Payment-first checkout:** Checkout creates an order intent plus pending payment transaction atomically, then returns `202 Accepted` with status and payment details.
- **Worker-ready boundary:** Durable paid-order processing can move behind SQS later; the local assignment runtime does not require AWS credentials.
- **Traceability:** API and worker logs should carry the same `trace_id` and `order_tracking_id`.
