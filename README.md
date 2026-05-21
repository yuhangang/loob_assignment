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

Target production architecture:

- Route 53 and CloudFront for DNS, CDN, and public entry.
- Application Load Balancer for API ingress.
- ECS Fargate for the Go API and background workers.
- Aurora MySQL for the relational source of truth.
- ElastiCache Redis for cache.
- SQS for background job processing.
- S3 and CloudFront for menu photos, banners, and static media.
- CloudWatch for logs, metrics, and alerting.

### Q12. How would you design for high availability across multiple regions?

Start with multi-AZ deployment in one primary region such as `ap-southeast-5`. ECS tasks, Aurora, Redis, and networking components should run across at least two availability zones.

If regional failover is needed later, add a secondary region and use Route 53 health checks, replicated data, and country-aware routing.

### Q13. How would you scale ordering for a flash sale?

This repo keeps the local runtime simple: payment-first order intents are stored in MySQL. In production, SQS would be added after checkout and payment validation.

The API should validate quickly, create an order intent, and return fast. Workers then process paid order intents at a controlled rate. On AWS, this can be auto-scaled with ECS Fargate by request load for the API and queue depth for workers. If the team prefers Kubernetes, the same pattern can run on EKS with Horizontal Pod Autoscaler and queue-based worker scaling. At higher scale, the ordering path can also be split into a dedicated microservice so checkout, payment callback, and order processing can scale independently, with more optimized data structures such as Redis-backed counters, reservation keys, and compact order-intent payloads for hot paths.

Redis can protect hot campaign quotas and rate limits, but MySQL remains the durable source of truth. Duplicate submissions are controlled with idempotency keys and unique transaction/order identifiers.

### Q14. Where and how would you implement caching?

Caching plan:

- CloudFront for static media and public manifest-style content.
- Redis for localized menu payloads, store-specific variants, campaign counters, and short-lived guards.
- App-side image cache via Flutter and `cached_network_image`.
- Database indexes and read replicas for read-heavy country/catalog queries, with proper cache invalidation handling (Not implemnted in this assignment)

Cache keys must include country and language so users do not receive the wrong catalog, price, or tax context.

### Q15. How would you manage image and media assets at scale?

Store media in S3 and serve it through CloudFront. The backend should keep only asset metadata in MySQL and return asset URLs, not stream large files directly.

For better scalability, uploads can go straight to S3 using presigned URLs, and background jobs can generate smaller variants such as thumbnails or mobile sizes. In this assignment, Go can still serve media for demo simplicity, but production should use S3 plus CloudFront.

The back office should also handle media lifecycle tasks such as replacing old banners, archiving unused assets, and keeping only active media linked to stores or campaigns.

### Q16. How would you monitor this application in production?

Monitoring should cover both system health and checkout health:

- Structured JSON logs with `trace_id`, `country_code`, route, status, latency, and payment or order IDs where safe.
- CloudWatch dashboards for API latency, error rate, checkout failures, payment callback failures, Redis errors, DB connections, and SQS depth.
- Alerts for checkout 5xx spikes, payment callback failures, queue age, DB saturation, and Redis degradation.
- Mobile crash reporting and analytics for checkout drop-off, voucher rejection reasons, and country-specific UX issues. (Firebase Crashlytics + Google Analytics)

### Q17. Describe your CI/CD pipeline.

Target pipeline:

1. Pull request opens.
2. Run formatting/lint checks for Go and Flutter.
3. Run `go test ./...`.
4. Run `flutter analyze` and `flutter test`.
5. Build backend and mobile artifacts with environment-specific config for `dev`, `staging`, or `release`.
6. For `dev`, deploy the backend to the development environment and publish mobile builds to internal testers.
7. For `staging`, deploy the backend to staging, run database migrations in a controlled way, and distribute the mobile app through TestFlight and Google Play internal or closed testing.
8. Run smoke checks against `/health`, catalog, checkout validation, and payment callback sandbox in the target environment.
9. For `release`, build signed production artifacts, push the backend image to ECR, and deploy with rolling or blue/green release.
10. Promote iOS builds from TestFlight to App Store release and Android builds from Google Play testing tracks to production after verification.

This repository currently documents the pipeline and local verification steps. GitHub Actions can be added later if the submission needs runnable CI in GitHub.

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
