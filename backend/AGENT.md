# Agent Guidelines — Loob Backend (Go)

This document defines the coding conventions, architecture patterns, and best practices that AI agents **must** follow when working on the Go backend codebase.

---

## Project Overview

The Loob backend is a **Go modular monolith** serving the Tealive & Baskbear mobile app and admin panel. It runs as two profiles from the same codebase:

- **`api`** — Echo HTTP server for mobile/admin clients (`cmd/api`)
- **`worker`** — Background SQS consumer for async order processing (`cmd/worker`)

**Key design documents:**
- [`docs/architecture/BACKEND_ARCHITECTURE.md`](../docs/architecture/BACKEND_ARCHITECTURE.md)
- [`docs/decisions/ADR-001-backend-modular-monolith.md`](../docs/decisions/ADR-001-backend-modular-monolith.md)
- [`docs/decisions/ADR-002-raw-sql-and-sqlc.md`](../docs/decisions/ADR-002-raw-sql-and-sqlc.md)

---

## Tech Stack

| Layer            | Technology                    | Notes                                               |
| :--------------- | :---------------------------- | :-------------------------------------------------- |
| Language         | Go 1.25                       |                                                     |
| HTTP Framework   | Echo v4                       | `labstack/echo/v4`                                  |
| Database         | MySQL 8                       | Local Docker; Aurora MySQL in production             |
| Persistence      | `database/sql` (raw SQL)      | GORM intentionally avoided — see ADR-002            |
| Query Gen        | `sqlc` (planned)              | For typed query generation on non-trivial queries   |
| Caching          | Redis                         | Menu cache, inventory, order status                  |
| Queue            | AWS SQS FIFO                  | Order intents only                                   |
| Auth             | Firebase Auth Admin SDK        | Planned for checkout/admin paths                     |
| API Docs         | `swaggo/swag` (OpenAPI)        | Swagger annotations on handlers                     |
| Config           | Environment variables          | Loaded via `internal/platform`                      |

---

## Project Structure

```text
backend/
├── cmd/
│   ├── api/main.go             # HTTP server entry point
│   ├── seed/                   # Database seeding tool
│   └── worker/main.go          # SQS worker entry point
├── internal/
│   ├── appconfig/              # App config endpoint (/api/v1/config)
│   ├── campaigns/              # Banners, promotions, home feed
│   ├── catalog/                # Brands, stores, categories, menu, pricing
│   ├── checkout/               # Cart validation, order intent creation
│   ├── contextx/               # Request context middleware (trace, country, lang)
│   ├── database/               # DB connection, migrations
│   ├── payments/               # Payment gateway (mock + real)
│   ├── platform/               # Config loading, trace ID generation
│   ├── queue/                  # SQS producer/consumer interfaces
│   ├── users/                  # User profile, Firebase UID mapping
│   └── vouchers/               # Voucher wallet, redemption
├── sql/
│   └── migrations/             # Handwritten SQL migration files
├── cdn/                        # Static asset serving
├── docs/                       # Generated Swagger docs
├── go.mod
└── main.go                     # Stub redirecting to cmd/api
```

---

## Architecture Rules

### Module Structure

Each domain module in `internal/` follows a flat, consistent pattern:

```text
internal/<module>/
├── handler.go          # HTTP handlers (Echo request/response only)
├── service.go          # Business logic, orchestration
├── repository.go       # Database access (raw SQL)
├── models.go           # Domain types and API response DTOs
├── service_test.go     # Unit tests for business logic
└── <module>_test.go    # Additional tests
```

**Rules:**
- `handler.go` — decodes HTTP requests and encodes responses. **Must be thin.** No business logic in handlers.
- `service.go` — owns all business rules and orchestration. This is where domain logic lives.
- `repository.go` — owns all database queries. Must not contain business rules.
- `models.go` — defines both internal domain types and JSON-serializable API response structs.

### Module Registration Pattern

Every module exposes a `Register(db, group)` function called from `cmd/api/main.go`:

```go
// In internal/catalog/handler.go
func Register(db *sql.DB, g *echo.Group) {
    h := NewHandler(NewService(NewRepository(db)))
    catalog := g.Group("/catalog")
    catalog.GET("/categories", h.listCategories)
    catalog.GET("/categories/:category_id/items", h.listCategoryItems)
    catalog.GET("/brands", h.listBrands)
    catalog.GET("/stores", h.listStores)
}
```

```go
// In cmd/api/main.go
v1 := e.Group("/api/v1")
catalog.Register(db, v1)
campaigns.Register(db, v1)
vouchers.Register(db, v1)
users.Register(db, v1)
```

### Dependency Direction

```text
cmd/api ──→ internal/<module>
internal/<module>/handler ──→ internal/<module>/service ──→ internal/<module>/repository
internal/<module> ──→ internal/contextx (for request context)
internal/<module> ──→ internal/platform (for config/utilities)
```

**Never:**
- Import one domain module from another domain module directly. If modules need to collaborate, coordinate in `cmd/api/main.go` or create a shared service.
- Import Echo types in `service.go` or `repository.go`.
- Import `database/sql` in `handler.go` or `service.go`.
- Put Loob business logic in `platform/` packages.

---

## Request Context

### contextx Middleware

Every request passes through `contextx.Middleware()` which extracts and normalizes:
- `TraceID` — from `X-Trace-Id` header or auto-generated
- `CountryCode` — from `X-Country-Code` header, defaults to `"MY"`
- `Language` — from `Accept-Language` header, normalized via `normalizeLanguage()`

### Accessing Context in Handlers

```go
func (h *Handler) listCategories(c echo.Context) error {
    rc := contextx.FromEcho(c) // typed RequestContext
    // Use rc.CountryCode, rc.Language, rc.TraceID
}
```

**Rules:**
- Handlers must **not** read raw headers repeatedly — use `contextx.FromEcho(c)`.
- Country and language are resolved **once** per request, in middleware.
- For checkout endpoints, validate country header presence with `contextx.RequireCountryHeader(c)`.

---

## Database Patterns

### Raw SQL — No ORM

This project intentionally avoids GORM. All database access uses `database/sql` with hand-written SQL:

```go
func (r *Repository) ListStores(ctx context.Context, countryID string, brandID int, activeOnly bool) ([]storeRow, error) {
    query := `SELECT id, brand_id, country_id, ... FROM stores WHERE country_id = ?`
    // Build query dynamically as needed
    rows, err := r.db.QueryContext(ctx, query, args...)
    // ...
}
```

**Rules:**
- Write explicit SQL — make joins, filters, and ordering visible.
- Use `?` placeholders for MySQL — never interpolate user input into SQL strings.
- Use `context.Context` from the request in all DB calls (`QueryContext`, `ExecContext`).
- Store currency values as integers in the smallest unit (e.g., cents/sen).
- Use JSON columns for translations and immutable snapshots, not for relational joins.
- Migrations are handwritten SQL files in `sql/migrations/`, applied at startup when `AUTO_MIGRATE=true`.

### Repository Interface Pattern

Repositories can define interfaces for testability:

```go
type CatalogRepository interface {
    GetCountry(ctx context.Context, code string) (countryRow, error)
    ListCategories(ctx context.Context, brandID int) ([]categoryRow, error)
    // ...
}
```

### Transactions

For multi-step writes (e.g., order creation), use explicit transactions:

```go
tx, err := r.db.BeginTx(ctx, nil)
if err != nil { return err }
defer tx.Rollback()

// ... execute multiple statements on tx ...

return tx.Commit()
```

---

## Error Handling

### Sentinel Errors

Define domain-specific sentinel errors in `service.go`:

```go
var (
    ErrUnsupportedCountry = errors.New("unsupported country")
    ErrStoreNotFound      = errors.New("store not found")
    ErrNotFound           = errors.New("not found")
)
```

### Handler Error Mapping

Handlers map sentinel errors to HTTP status codes:

```go
func (h *Handler) listCategoryItems(c echo.Context) error {
    items, err := h.service.ListCategoryItems(ctx, req)
    if err != nil {
        switch {
        case errors.Is(err, ErrUnsupportedCountry):
            return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "unsupported country"})
        case errors.Is(err, ErrStoreNotFound):
            return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "store not found"})
        default:
            return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to load menu"})
        }
    }
    return c.JSON(http.StatusOK, menu)
}
```

**Rules:**
- Use `errors.Is()` for sentinel error checks, not string comparison.
- Return `echo.NewHTTPError()` with a `map[string]string{"error": "..."}` body for consistency.
- Never expose internal error messages to clients.
- Always log internal errors with `trace_id` and `country_code`.

---

## Localization

### Translation Resolution

The backend resolves translations server-side — the mobile client receives only the selected language:

```go
func localize(values map[string]string, language, fallback string) string {
    // Try: exact match → language prefix → fallback → en-US → en → any value
}
```

**Rules:**
- Translations are stored as `JSON` columns (e.g., `{"en-US": "...", "ms-MY": "..."}`).
- The `localize()` helper tries the requested language, then the prefix, then the country default, then `en-US`.
- API responses must include `language_resolved` so the client knows which language was actually used.

---

## API Conventions

### Endpoint Pattern

```text
GET  /api/v1/<module>/<resource>          # List
GET  /api/v1/<module>/<resource>/:id      # Get by ID
POST /api/v1/<module>/<resource>          # Create
PUT  /api/v1/<module>/<resource>/:id      # Update
```

### Request Headers

All API requests must include:
- `X-Country-Code` — ISO 3166-1 alpha-2 (e.g., `MY`, `TH`)
- `Accept-Language` — BCP 47 (e.g., `en-US`, `ms-MY`)
- `Authorization: Bearer <jwt>` — for authenticated endpoints
- `X-Trace-Id` — optional, auto-generated if missing

### Response Format

```json
{
  "id": 1,
  "name": "Tealive",
  "country_code": "MY",
  "language_resolved": "en-US"
}
```

- Use `snake_case` for all JSON field names.
- Include `language_resolved` on localized responses.
- Use `map[string]string{"error": "message"}` for error responses.

### Query Parameter Helpers

Use the established `intQuery` helper for safe integer parsing:

```go
func intQuery(c echo.Context, key string) (int, error) {
    raw := c.QueryParam(key)
    if raw == "" { return 0, nil }
    return strconv.Atoi(raw)
}
```

---

## Logging & Observability

### Structured Logging

All logs must include contextual identifiers:

```go
log.Printf("trace_id=%s country=%s method=%s uri=%s status=%d latency=%s",
    rc.TraceID, rc.CountryCode, values.Method, values.URI, values.Status, values.Latency)
```

**Rules:**
- Every log line must include `trace_id`.
- Checkout/order logs must also include `order_tracking_id`.
- Use key-value format: `key=value` for structured parsing.
- No checkout or worker error should be logged without `trace_id` and `country_code`.

---

## Testing

### Test Organization

- Tests live alongside source files: `service_test.go` next to `service.go`.
- Focus on **service-level business logic** tests first, not handler tests.
- Use table-driven tests for exhaustive input validation.

### Running Tests

```bash
# All tests
go test ./...

# With coverage
go test -cover ./...

# Specific module
go test ./internal/catalog/...

# Verbose
go test -v ./internal/checkout/...
```

### Test Naming

```go
func TestListCategories_UnsupportedCountry(t *testing.T) { ... }
func TestListCategoryItems_StoreNotFound(t *testing.T) { ... }
func TestListCategoryItems_Success(t *testing.T) { ... }
```

---

## Configuration

### Environment Variables

Configuration is loaded via `platform.Load()`. Key variables:

| Variable              | Description                                | Default               |
| :-------------------- | :----------------------------------------- | :-------------------- |
| `DATABASE_DSN`        | MySQL connection string                    | (required)            |
| `HTTP_ADDR`           | Server listen address                      | `:8080`               |
| `AUTO_MIGRATE`        | Run SQL migrations on startup              | `true`                |
| `MIGRATIONS_DIR`      | Path to migration files                    | `sql/migrations`      |
| `MOCK_GATEWAY_SECRET` | Secret for mock payment callback           | (required for mock)   |
| `PUBLIC_BASE_URL`     | API origin for mobile clients              | `http://localhost:8080`|
| `COUNTRY`             | Country filter for seed command            | (all)                 |
| `CLEAN`               | Clean data before seeding                  | `false`               |

---

## Database Seeding

```bash
# Seed all countries
go run ./cmd/seed

# Seed specific country
COUNTRY=MY go run ./cmd/seed

# Clean and re-seed
CLEAN=true go run ./cmd/seed
```

Seed data is managed via JSON files in `cmd/seed/data/`.

---

## Swagger / API Docs

### Generating Docs

```bash
# Install swag CLI
go install github.com/swaggo/swag/cmd/swag@latest

# Generate from code annotations
~/go/bin/swag init -g main.go --output docs
```

### Adding Swagger Annotations

Add annotations above handler functions:

```go
// @Summary List localized menu categories
// @Tags catalog
// @Param store_id query int false "Store ID"
// @Param brand_id query int false "Brand ID"
// @Success 200 {object} CategoryList
// @Failure 400 {object} map[string]string
// @Router /catalog/categories [get]
func (h *Handler) listCategories(c echo.Context) error { ... }

// @Summary List localized items for a menu category
// @Tags catalog
// @Param category_id path int true "Category ID"
// @Param store_id query int false "Store ID"
// @Param brand_id query int false "Brand ID"
// @Success 200 {object} CategoryItems
// @Failure 400 {object} map[string]string
// @Router /catalog/categories/{category_id}/items [get]
func (h *Handler) listCategoryItems(c echo.Context) error { ... }
```

---

## Common Pitfalls

| Pitfall | Correct Approach |
| :--- | :--- |
| Business logic in handlers | Move to `service.go` — handlers only decode/encode |
| SQL in service layer | Move to `repository.go` — services call repository methods |
| Using GORM or any ORM | Use `database/sql` with raw SQL — see ADR-002 |
| Reading raw headers in handlers | Use `contextx.FromEcho(c)` for typed request context |
| String interpolation in SQL | Use `?` placeholders with parameterized queries |
| Missing trace_id in logs | Always include `rc.TraceID` in structured log output |
| Exposing internal errors to clients | Map to user-friendly messages via `echo.NewHTTPError` |
| Cross-module imports | Coordinate in `cmd/api/main.go`, don't import between domain modules |
| Storing prices as floats | Use integers in smallest currency unit (cents/sen) |
| Hardcoding country defaults | Let contextx middleware handle defaults |

---

## Local Development

### Prerequisites
- Go 1.25+
- Docker & Docker Compose

### Quick Start

```bash
# Start infrastructure
docker compose up -d db redis

# Run API server
go run ./cmd/api

# Health check
curl http://127.0.0.1:8080/health

# Smoke test (menu categories + category items)
curl -H 'X-Country-Code: MY' -H 'Accept-Language: en-US' \
  'http://127.0.0.1:8080/api/v1/catalog/categories?store_id=1'
curl -H 'X-Country-Code: MY' -H 'Accept-Language: en-US' \
  'http://127.0.0.1:8080/api/v1/catalog/categories/1/items?store_id=1'
```

### Useful Smoke Tests

```bash
# Stores
curl -H 'X-Country-Code: MY' 'http://127.0.0.1:8080/api/v1/catalog/stores'

# Home feed
curl -H 'X-Country-Code: MY' 'http://127.0.0.1:8080/api/v1/campaigns/home'

# Voucher wallet
curl -H 'X-Country-Code: MY' 'http://127.0.0.1:8080/api/v1/vouchers/wallet?user_id=demo-user'
```
