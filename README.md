# Loob Unified App Redesign — Full Stack Assessment

> Candidate: Yuhang Ang | Submission Date: May 2026

## App Overview

This repository contains a full-stack redesign proposal and implementation for a Loob consumer ordering app. Instead of choosing only Tealive or Baskbear, the implementation models a unified Loob app that can serve both brands from one backend while preserving brand-specific presentation in the Flutter client.

The product focuses on the four required assessment modules:

- Menu browsing with categories, country pricing, localization, dietary tags, customization, and outlet availability.
- Ordering with persisted cart, checkout, payment-first order intent creation, order status, and order history.
- Vouchers with listing, validation, stacking policy, redemption limits, expiry, country rules, and checkout enforcement.
- Multi-country behavior through country selection, language/currency resolution, tax rules, timezone data, and JSON-based regional configuration.

AWS infrastructure is documented as architecture Q&A only. No live AWS resources are required to run this assessment locally.

## Tech Stack

| Layer            | Technology                              | Justification                                                                                                                                                        |
| ---------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Frontend         | Flutter                                 | Cross-platform Android/iOS client with a mobile-first UI and brand-aware theming.                                                                                    |
| State Management | BLoC + Cubit                            | BLoC is used for event-driven flows such as cart, checkout, auth, menu, and orders. Cubit is used for simpler state such as theme, language, and page-level loading. |
| Backend          | Go + Echo                               | A small, fast modular monolith with explicit package boundaries and straightforward local execution.                                                                 |
| Database         | MySQL 8                                 | The source of truth for catalog, pricing, cart, order intents, vouchers, payments, wallet, loyalty, and multi-country data.                                          |
| Cache            | Redis                                   | Used by the backend for catalog caching and future hot-path controls. The system can fall back to MySQL for normal catalog reads if Redis is unavailable.            |
| Auth             | Firebase Auth contract, local mock mode | Firebase ID tokens are the production contract. `AUTH_MODE=mock` exists for local assessment runs without Firebase credentials.                                      |
| API Style        | REST                                    | Simple mobile-facing endpoints with country, language, and auth context carried in headers.                                                                          |
| Cloud Design     | AWS                                     | ECS Fargate, ALB, Aurora MySQL, ElastiCache Redis, SQS FIFO, S3, CloudFront, CloudWatch, and WAF are used in the target architecture design.                         |

## Project Structure

```text
.
├── backend/                 # Go Echo API, worker entrypoint, migrations, seed data, Swagger/Postman files
├── mobile/                  # Flutter app
├── docs/                    # Architecture, database, product, decision, and reference documents
├── admin/                   # Admin panel shell, if included in the submitted branch
├── countries_config.json    # Country-level runtime configuration seed
└── .env.example             # Local backend environment example
```

## Local Setup

### Backend

Prerequisites:

- Go 1.25+
- Docker and Docker Compose
- MySQL and Redis through the provided compose file

Run locally:

```bash
cp .env.example .env
cd backend
docker compose up -d db redis
go run ./cmd/api
```

The backend applies SQL migrations from `backend/sql/migrations` on startup by default. Set `AUTO_MIGRATE=false` to disable automatic migration.

Seed data:

```bash
cd backend
go run ./cmd/seed
COUNTRY=MY go run ./cmd/seed
COUNTRY=TH go run ./cmd/seed
```

Backend tests:

```bash
cd backend
go test ./...
```

Useful local API checks:

```bash
curl -sS http://127.0.0.1:8080/health
curl -sS -H 'X-Country-Code: MY' -H 'Accept-Language: en-US' 'http://127.0.0.1:8080/api/v1/catalog/categories?store_id=1'
curl -sS -H 'X-Country-Code: MY' 'http://127.0.0.1:8080/api/v1/catalog/stores'
```

### Mobile

Prerequisites:

- Flutter stable SDK
- Android Studio or Xcode simulator tooling

Mobile environment files live under `mobile/env/`:

- `mobile/env/.env.example`: template values.

Create a local mobile env file from the template if needed:

```bash
cd mobile
cp env/.env.example env/.env.dev
```

When running on the iOS simulator, Android emulator, or a physical device, set `BASE_URL` to an address the device can reach. For example, `localhost` works for some simulator cases, Android emulator often needs `http://10.0.2.2:8080`, and physical devices usually need the machine LAN IP such as `http://192.168.0.115:8080`.

Run locally:

```bash
cd mobile
flutter pub get
flutter run --dart-define-from-file=env/.env.dev
```

Use the default `lib/main.dart` entrypoint when passing env values. The convenience entrypoints `lib/main_dev.dart` and `lib/main_staging.dart` use built-in defaults and are useful when you do not need overrides.

Mobile verification:

```bash
cd mobile
flutter test
flutter analyze
```

## Implemented API Surface

The main backend routes are registered under `backend/cmd/api/routes.go`.

- `GET /health`
- `GET /api/v1/catalog/categories`
- `GET /api/v1/catalog/categories/:category_id/items`
- `GET /api/v1/catalog/items/:item_id`
- `GET /api/v1/catalog/brands`
- `GET /api/v1/catalog/stores`
- `GET /api/v1/campaigns/home`
- `GET /api/v1/vouchers/wallet`
- `POST /api/v1/vouchers/validate`
- `GET /api/v1/cart`
- `PUT /api/v1/cart/items`
- `PATCH /api/v1/cart/items/:item_id`
- `DELETE /api/v1/cart/items/:item_id`
- `DELETE /api/v1/cart`
- `POST /api/v1/orders/checkout`
- `GET /api/v1/orders`
- `GET /api/v1/orders/:tracking_id/status`
- `POST /api/v1/orders/:tracking_id/collect`
- `GET /api/v1/payments/providers`
- `GET /api/v1/payments/methods`
- `POST /api/v1/payments/mock-gateway/callback`
- `GET /api/v1/users/profile`
- `PATCH /api/v1/users/profile`
- `GET /api/v1/users/wallet/history`
- `POST /api/v1/users/wallet/topups`
- `GET /api/v1/users/loyalty/history`
- `GET /api/v1/app/config`
- `GET /api/v1/app/feed`

## Design & Architecture Decisions

### Q1. Why did you design the app this way?

The app is designed to multi-country and multi-brands Loob storefront rather than a single-brand clone. Tealive and Baskbear can potentially sharing same API endpoints and reuse some of the flutter/dart.

### Q2. How did you approach multi-country UX?

The mobile app treats country and language as first-class context. The API client sends `X-Country-Code` and `Accept-Language`, and the backend returns already-localized, country-priced payloads. This keeps the app lean and avoids shipping large translation dictionaries or pricing matrices to the client.

The schema stores country currency, timezone, tax rate, default language, zones, stores, and country-scoped rules. The UI uses flexible layouts and constrained widths so longer Southeast Asian text has room to wrap without breaking core screens.

### Q3. What additional features did you build beyond the four required modules?

Additional implemented or modeled features include:

- Mock payment gateway callback to prove transaction lifecycle and order-state changes.
- Wallet balance, wallet top-up, wallet history, loyalty points, and loyalty history.
- Campaign/home feed endpoints for promotions and app content.
- Store operational status so temporarily closed outlets can be shown and blocked at checkout.
- Checkout charge definitions, currently used for packaging fee.
- Order-again and cart shortcut behavior in the mobile app.

### Q4. Which state management solution did you choose and why?

We went with the **BLoC / Cubit Hybrid Pattern** (using `flutter_bloc`). While something like Provider or Riverpod is fine for small demo apps, a multi-brand (Tealive + Baskbear), multi-country ordering app has a lot of moving parts that need absolute predictability.

Here is why this combo fits so well:

1. **BLoC for the tricky stuff (Cart & Checkout):**
   F&B apps are highly transactional. In our codebase, the `CartBloc` handles complex, optimistic UI mutations (adding, updating, and removing items instantly in the UI) while seamlessly synchronizing changes with the backend in the background. It also manages background polling timers to keep cart item availability in sync with real-time store inventory. Coordinating these asynchronous actions with simple state solutions is highly prone to race conditions.

2. **Cubit for the simple stuff (Themes & Preferences):**
   We didn't want to drown in boilerplate. For straightforward, function-driven actions like switching brand themes (Tealive $\leftrightarrow$ Baskbear), toggling languages, or loading a user profile, we use **Cubit**. It gives us the same reactive UI updates but with way less code.

3. **Smooth Twin-App Theming:**
   Since the app dynamically updates colors, logos, and menus when switching brands, we need the UI to react instantly. The `ThemeCubit` handles this seamlessly across all pages without requiring a full app reload.

4. **Bulletproof Testing:**
   Orders and money are involved, so state transitions must be correct. Because BLoCs and Cubits live entirely separate from the Flutter widget tree, we can use `bloc_test` to verify exact state sequences (e.g. `[Loading, Success]`) in simple unit tests, long before we even build a UI.

**The Trade-off:** Yes, there's more boilerplate than a basic setup, but it is completely worth it for a cross-border production app that needs to be robust, easy to debug, and highly testable.

### Q5. How did you structure your Flutter project?

The mobile app is feature-driven:

```text
mobile/lib/
├── core/                    # config, auth, networking, DI, localization, theme, shared widgets
├── features/
│   ├── cart/
│   ├── campaigns/
│   ├── home/
│   ├── menu/
│   ├── orders/
│   ├── settings/
│   └── vouchers/
└── app.dart
```

Each larger feature separates data models/datasources/repositories from presentation widgets and BLoC/Cubit state. The backend follows a matching modular-monolith shape under `backend/internal/*`, with separate packages for catalog, cart, checkout, payments, vouchers, users, campaigns, ordering, context, database, and API errors.

### Q6. How does the app handle offline scenarios or slow connectivity?

The implemented app handles slow or unreliable connectivity through explicit loading, retry, and error states, local preference storage, token refresh handling, and server-backed cart/order recovery. Cart and order APIs are designed so the server remains the source of truth after reconnect.

Full offline checkout is intentionally not supported. Payment, voucher redemption, outlet availability, tax, and inventory-sensitive rules must be confirmed by the backend. The architecture includes Drift as the local persistence direction for richer offline cart/active-order recovery, but the submission should treat that as a next improvement rather than claim fully offline ordering.

## Database Design

### Q7. Walk us through the core schema.

The database schema is documented in [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md), and migrations live in `backend/sql/migrations`.

Core modeling:

- `countries`, `zones`, and `stores` define country, currency, timezone, tax, regional pricing zones, and outlet state.
- `brands`, `categories`, `menu_items`, `menu_item_pricing`, `customization_groups`, and `customization_options` model catalog browsing and item customization.
- `store_menu_item_status` separates whether an item is listed from whether it is currently available at a store.
- `cart_items` stores user cart lines with selected customization IDs.
- `order_intents`, `order_intent_items`, and `order_intent_item_options` store checkout snapshots and queryable order history lines.
- `vouchers`, `user_vouchers`, `order_intent_vouchers`, and `voucher_user_redemption_counters` model stacking policy, redemption rules, ownership, and limits.
- `payment_transactions` and `payment_events` model mock payment lifecycle.
- `wallet_accounts`, `wallet_transactions`, `loyalty_accounts`, and `loyalty_transactions` model user value and history.

Menu items use JSON translation maps for localized names/descriptions. Prices use integer minor units. Country-specific pricing is resolved through zone pricing, not client-side currency conversion.

### Q8. How does the schema handle multi-country data?

Multi-country data is modeled explicitly instead of inferred from locale strings. Most operational tables carry `country_id` or join through country-scoped parents. Countries define currency, timezone, tax rate, default language, and active state. Zones allow regional pricing differences inside a country.

This allows Malaysia and Thailand to share one codebase while still enforcing different prices, languages, stores, taxes, vouchers, campaigns, feature flags, and payment methods.

Multi-country data is modeled explicitly instead of inferred from locale strings. Most operational tables carry `country_id` or join through country-scoped parents. Countries define currency, timezone, tax rate, default language, and active state. Zones allow regional pricing differences inside a country.

Today this is a logical partitioning model: Malaysia, Thailand, and future countries can share one API and database while still enforcing different prices, languages, stores, taxes, vouchers, campaigns, feature flags, and payment methods.

The same schema also leaves room for future physical separation. If scale, latency, compliance, or operational risk requires it, countries can be moved into regional database clusters or country-specific shards because the data already has clear country boundaries. At the infrastructure layer, DNS or edge routing can send `my.example.com`, `th.example.com`, or country-aware mobile API traffic to the nearest regional stack. Route 53, CloudFront, ALB, and health checks would handle traffic steering, while the app contract remains the same: every request still carries country context through headers such as `X-Country-Code`.

So the assignment implementation uses one shared MySQL schema, but it avoids designing the data in a way that would block future country-level sharding or DNS-based regional separation.

### Q9. What indexing strategy did you apply?

Indexes are focused on the mobile hot paths and transactional safety:

- Country, brand, category, and store indexes for catalog reads.
- Store item availability indexes for outlet-specific menu filtering.
- User and country indexes for cart, voucher wallet, orders, wallet history, and loyalty history.
- Tracking ID, idempotency, payment transaction, and gateway event indexes for checkout/payment recovery.
- Voucher code and redemption counter indexes for validation.

### Q10. How would you handle MySQL migrations safely with no downtime?

The production approach is expand-and-contract:

1. Add backward-compatible nullable columns or new tables.
2. Deploy code that writes both old and new shapes where necessary.
3. Backfill in batches with small transactions.
4. Move reads to the new shape after verification.
5. Add constraints or remove old columns only after old code is no longer running.

For this repository, migrations are handwritten SQL under `backend/sql/migrations` and applied in sorted order by the backend migration runner. Existing-database changes are additive migration files so initialized environments can upgrade without rebuilding from scratch.

## AWS Architecture Q&A

### Q11. Describe the overall AWS architecture.

The target AWS architecture uses:

- Route 53 and CloudFront for public entry and CDN. (current using backend as mocked CDN)
- Application Load Balancer for API ingress.
- ECS Fargate for the Go API profile and worker profile.
- Aurora MySQL for the relational source of truth.
- ElastiCache Redis for menu cache, hot campaign controls, and transient state.
- SQS FIFO for flash-sale order buffering and worker backpressure.
- S3 and CloudFront for menu photos, banners, and static media.
- CloudWatch/X-Ray or Datadog for logs, metrics, traces, and alerting.
- WAF in front of ALB/CloudFront for common abuse protection.
- DynamoDB could be used for serving dynamic home feed content, such as personalized banners, featured products, outlet modules, and campaign sections. The core transactional data would remain in SQL, while DynamoDB stores precomputed feed items keyed by user, demongraphic, region, or store for low-latency mobile reads.

### Q12. How would you design for high availability across multiple regions?

For the first production step, I would run multi-AZ inside `ap-southeast-1` because it is a practical hub for Malaysia, Thailand, and Singapore. ECS tasks, Aurora, Redis, and NAT gateways should run across at least two availability zones.

For stronger regional availability, the platform can move to active-active or active-passive regional deployments. Country-level data boundaries make this easier: a country can be routed to a regional stack when latency, compliance, or disaster recovery requirements justify it. Aurora Global Database, per-region Redis, S3 replication, Route 53 health checks, and country-aware traffic routing would be used for this stage.

### Q13. How would you scale ordering for a flash sale?

The local assessment runtime uses payment-first order intents in MySQL so it can run without AWS credentials. The production flash-sale design adds SQS FIFO after checkout/payment validation.

At larger production scale, the ordering transaction path could become a separate API service. In this assignment it remains inside the backend modular monolith for simpler local review, but the boundary is already clear: checkout validates the cart and payment intent, payments own provider callbacks, ordering owns order state, and workers handle queue-backed fulfillment. Splitting it later would isolate the highest-spike transactional workload from catalog, campaign, and profile APIs while keeping MySQL as the durable source of truth.

The API should do fast validation, reserve quota/idempotency safely, create or enqueue an order intent, and return quickly. Workers then process paid order intents at a controlled rate. Auto-scaling is based on ALB request count for API containers and SQS queue depth or message age for worker containers.

Redis can protect hot campaign quotas and rate limits, but MySQL remains the durable source of truth. Duplicate submissions are controlled with idempotency keys and unique transaction/order identifiers.

### Q14. Where and how would you implement caching?

Caching layers:

- CloudFront for static media and public manifest-style content.
- Redis for localized menu payloads, store-context menu variants, hot campaign counters, and short-lived guards.
- App-side image cache through Flutter image caching and `cached_network_image`.
- Database indexes and read replicas for read-heavy country/catalog queries.

Cache keys must include country and language to avoid serving Thai content, Malaysian prices, or wrong tax behavior to the wrong user.

### Q15. How would you manage image and media assets at scale?

Menu photos, banners, campaign images, and app content assets should be uploaded to S3 and served through CloudFront. The backend stores asset URLs or paths in MySQL and returns the correct asset references in country/language-aware payloads.

Large media should not be served through the Go API. The API should only resolve which asset applies; CloudFront should handle delivery, caching, compression, and regional edge performance.

### Q16. How would you monitor this application in production?

Monitoring should cover technical and business health:

- Structured JSON logs from Go with `trace_id`, `country_code`, route, status, latency, user/order identifiers where safe, and payment/order tracking IDs.
- CloudWatch or Datadog dashboards for API latency, error rate, checkout failures, payment callback failures, Redis errors, DB connections, SQS depth, and SQS message age.
- Distributed traces through AWS X-Ray or Datadog APM.
- Alerts for checkout 5xx spikes, payment callback failures, queue age, database connection saturation, and Redis degradation.
- Mobile crash reporting and analytics for checkout drop-off, voucher rejection reasons, and country-specific UX issues.

### Q17. Describe your CI/CD pipeline.

The target CI/CD pipeline:

1. Pull request opens.
2. Run formatting/lint checks for Go and Flutter.
3. Run `go test ./...`.
4. Run `flutter analyze` and `flutter test`.
5. Build backend Docker image.
6. Build Android/iOS artifacts for release branches.
7. Push backend image to ECR.
8. Run database migrations as a controlled job using expand-and-contract migration rules.
9. Deploy ECS with rolling or blue/green release.
10. Run smoke checks against `/health`, catalog, checkout validation, and payment callback sandbox.
11. Promote mobile builds through internal testing, TestFlight, and Play Console tracks.

This repository currently documents the pipeline and provides local verification commands. Adding executable GitHub Actions workflow files is the next packaging step if the submission requires CI to run inside GitHub.

## Known Limitations & Improvements

- Live AWS infrastructure is not provisioned; AWS is answered as design Q&A.
- Real payment provider integration is replaced by a mock gateway callback.
- Full offline checkout is not supported because payment, voucher, and availability rules must be server-confirmed.
- The admin panel is not the main assessment runtime; the mobile and backend flows are the priority.
- Push notifications, dynamic app icons, and deep links are architecture candidates but not core implemented flows.
- CI/CD is documented, but executable GitHub Actions workflow files should be added before a polished public submission.

## Verification

Current local gates:

```bash
cd backend && go test ./...
cd mobile && flutter test
cd mobile && flutter analyze
```

At the time this README was prepared, backend tests and Flutter tests passed locally. `flutter analyze` should be kept clean before final submission.
