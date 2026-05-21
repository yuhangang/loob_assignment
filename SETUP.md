# Loob Unified App — Local Setup Guide

This guide provides a comprehensive, step-by-step walkthrough to set up the entire full-stack project locally. The repository is split into two primary components: the **Go (Echo) Backend** and the **Flutter Mobile App**.

---

## 🛠️ System Prerequisites

Ensure you have the following installed on your machine before starting the setup:

| Dependency                  | Minimum Version / Requirement                     | Purpose                                                   |
| :-------------------------- | :------------------------------------------------ | :-------------------------------------------------------- |
| **Go**                      | `1.25+`                                           | Running and testing the backend API and worker processes. |
| **Flutter SDK**             | `Stable Channel`                                  | Building and running the cross-platform mobile client.    |
| **Docker & Docker Compose** | Latest                                            | Orchestrating MySQL 8 and Redis instances locally.        |
| **Mobile Tooling**          | `Xcode` (macOS/iOS) or `Android Studio` (Android) | Simulator/emulator and build tools.                       |

---

## 📁 Repository Overview

```text
.
├── backend/                 # Go Echo API, worker entrypoint, migrations, seed data, and Swagger configs
├── mobile/                  # Flutter mobile application
├── database/                # Local database-related configs/tools
├── docs/                    # Architecture documents, ADRs, and product guides
├── countries_config.json    # Country-level runtime configuration seed
├── .env.example             # Template for backend environment variables
└── SETUP.md                 # This setup guide
```

---

## 🚀 Step 1: Backend Setup

The backend serves as a profiled modular monolith, providing localized catalogs, cart calculations, voucher logic, and order state management.

### 1. Configure Backend Environment

From the root directory, clone the example environment file:

```bash
cp .env.example .env
```

> [!NOTE]
> The default values in `.env.example` are preconfigured to work out-of-the-box with the local Docker containers. If you change ports or database credentials, update `.env` accordingly.

### 2. Start Local Infrastructure

Navigate to the `backend` directory and spin up the database (MySQL 8) and cache (Redis) containers:

```bash
cd backend
docker compose up -d db redis
```

### 3. Install Dependencies

Ensure all Go modules are downloaded and tidy:

```bash
go mod tidy
```

### 4. Database Migrations & Seeding

By default, the backend automatically runs SQL migrations from `backend/sql/migrations` when it starts up.

To seed the database with realistic regional categories, menu items, prices, and stores, run the seeding tool:

```bash
# Seed all supported countries (MY and TH)
go run ./cmd/seed

# (Optional) Seed only Malaysia
COUNTRY=MY go run ./cmd/seed

# (Optional) Seed only Thailand
COUNTRY=TH go run ./cmd/seed

# (Optional) Wipe existing data before seeding
CLEAN=true go run ./cmd/seed
```

### 5. Run the Go API Server

Start the REST API server:

```bash
go run ./cmd/api
```

The server will start listening on `:8080` (or the port defined in your `.env`).

---

## 📱 Step 2: Mobile Setup

The Flutter application supports both _Tealive_ and _Baskbear_ brands dynamically via a robust state-managed "Twin App" theme engine.

### 1. Configure Mobile Environment

Navigate to the `mobile` directory and clone the mobile template configuration:

```bash
cd mobile
cp env/.env.example env/.env.dev
```

### 2. Configure Device API Networking

Open your newly created `mobile/env/.env.dev` and locate the `BASE_URL` property:

```env
BASE_URL=http://192.168.0.115:8080
```

> [!IMPORTANT]
> When running the mobile client, the base URL must point to an address reachable by your simulator, emulator, or physical device:
>
> - **iOS Simulator:** `http://localhost:8080` or machine LAN IP.
> - **Android Emulator:** `http://10.0.2.2:8080` (redirects to host machine's localhost).
> - **Physical Device:** Your computer's local LAN IP (e.g., `http://192.168.1.115:8080`). Both the computer and the device must be connected to the same Wi-Fi network.

### 3. Fetch Packages

The app uses `get_it` for dependency injection and `shared_preferences` / `drift` for persistence. All dependencies are registered manually in `lib/core/di/injection.dart`, so no code generation step is required. Simply fetch the packages:

```bash
flutter pub get
```

### 4. Run the Mobile App

Start the app on your connected device or simulator/emulator using the development environment configuration:

```bash
flutter run --dart-define-from-file=env/.env.dev
```

---

## 🧪 Step 3: Verification & Diagnostics

Use the following commands and checks to verify that everything is running correctly.

### 1. Backend Smoke Tests

Open a new terminal window and run some simple `curl` commands to query the backend API:

```bash
# Health Check (Should return {"status":"healthy"})
curl -sS http://127.0.0.1:8080/health

# Catalog Categories for Malaysia Store 1
curl -sS -H 'X-Country-Code: MY' -H 'Accept-Language: en-US' 'http://127.0.0.1:8080/api/v1/catalog/categories?store_id=1'

# Active Stores in Malaysia
curl -sS -H 'X-Country-Code: MY' 'http://127.0.0.1:8080/api/v1/catalog/stores'
```

### 2. Mock Payment Gateway Verification

To simulate a payment gateway callback and move a payment-pending order intent to a ready-for-collection status:

```bash
curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -H 'X-Mock-Gateway-Secret: change-me-local-only' \
  -d '{"transaction_id":"PAY-MY-EXAMPLE","gateway_reference":"mock-ref-1","gateway_event_id":"evt-1","status":"success"}' \
  http://127.0.0.1:8080/api/v1/payments/mock-gateway/callback
```

### 3. Test Suites

Make sure all unit, integration, and UI tests pass successfully:

#### Run Go Backend Tests

```bash
cd backend
go test ./...
```

#### Run Go Test Coverage

```bash
cd backend
go test -cover ./...
```

#### Run Flutter Mobile Tests & Analysis

```bash
cd mobile
flutter test
flutter analyze
```

---

## 📖 API Documentation & Postman

This project automatically generates POSTMAN documentation by using Agentic A
