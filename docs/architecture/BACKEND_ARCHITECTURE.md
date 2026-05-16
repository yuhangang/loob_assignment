# Backend Architecture: Scale, Stability & Observability

This document outlines the detailed backend architecture for the Loob Unified App, built on **Go (Node.js/TypeScript)**. It is designed to handle high-velocity operations across Southeast Asia, with a specific focus on surviving extreme traffic spikes (e.g., "RM 1 Boba Flash Sales").

---

## 1. Core Architectural Pattern: Modular Monolith

While full microservices introduce massive operational overhead for early-stage deployments, a traditional monolith becomes a bottleneck. We utilize a **Modular Monolith** pattern within Go. 

The application runs as a single deployable unit but is strictly isolated by Domain-Driven Design (DDD) bounded contexts.

### Bounded Contexts (Go Modules)
*   **`@loob/catalog`:** Handles Menus, Categories, Customizations, and Pricing. Heavily cached. Read-heavy.
*   **`@loob/checkout`:** Handles Cart validation, Voucher verification, and Tax calculations. Compute-heavy.
*   **`@loob/ordering`:** Handles Order ingestion, SQS queuing, and Store fulfillment routing. Write-heavy.
*   **`@loob/campaigns`:** Handles Banners, Splash screens, and Gamification parameters.
*   **`@loob/ops-admin`:** Dedicated module for CMS interactions (RBAC, CRUD operations on the catalog).

### Deployment Profiles (Scaling without Microservices)
While the codebase is a single repository, we achieve **independent scaling** using Deployment Profiles. We do not need to split the codebase into separate microservices (which introduces distributed transaction complexity) to scale the ordering bottleneck.
*   **API Profile:** Instances deployed to handle incoming HTTP requests (`@loob/catalog`, `@loob/checkout`). These scale based on CPU/HTTP traffic.
*   **Worker Profile:** Instances deployed with HTTP disabled, running only the `@loob/ordering` module to consume the SQS queue. These scale automatically based on **SQS Queue Depth**. During a flash sale, AWS Auto-Scaling might spin up 50 Worker instances to process transactions and status updates, while the API instances remain at a stable 5 instances.

---

## 2. Surviving Spike Traffic (Flash Sales)

Flash sales generate sudden, 10x–50x spikes in traffic (the "Thundering Herd" problem). If orders write directly to the database, table locks will occur, transactions will time out, and the database will crash.

### The Asynchronous Queue Architecture

1.  **Ingestion & Validation (Fast Fail):**
    *   User hits "Checkout".
    *   The Go API intercepts the request.
    *   It checks **Redis** for active vouchers and inventory levels (e.g., "Are pearls sold out?").
    *   *If invalid:* Returns HTTP 400 instantly.
2.  **Order Intent Creation:**
    *   If valid, the API generates an `OrderIntent` JSON payload.
    *   The API pushes this payload directly to an **AWS SQS (Simple Queue Service) FIFO Queue**.
    *   The API responds to the Flutter App with HTTP 202 (Accepted) and an `order_tracking_id`.
    *   *Time taken:* < 50ms. The database has not been touched.
3.  **Background Workers (Throttled DB Writes):**
    *   A separate pool of Go Worker instances (running only the `@loob/ordering` worker context) consumes the SQS queue.
    *   They pull batches of 10 messages.
    *   They perform the actual heavy MySQL `INSERT` operations (creating the Order, Order Items, deducting DB inventory).
    *   Because the workers process at a controlled rate (e.g., 500 orders/sec max), the RDS MySQL instance never gets overwhelmed, no matter how many users hit "Checkout" simultaneously.
4.  **Client Polling / WebSockets:**
    *   The Flutter app sees "Processing Order...". It uses Server-Sent Events (SSE) or short-polling against Redis to check the status of `order_tracking_id`. Once the worker updates Redis with "SUCCESS", the app moves to the Receipt screen.

### Mitigating Database Write Bottlenecks

Even with SQS controlling the rate of incoming orders, the primary MySQL database is the ultimate physical bottleneck for write operations. We implement several strategies to protect it:

1.  **CQRS (Command Query Responsibility Segregation) & Read Replicas:**
    *   The Primary RDS MySQL instance handles **only writes** (Orders, Vouchers).
    *   We spin up AWS Aurora Auto-Scaling Read Replicas. All read operations (CMS fetching data, background analytics) are routed strictly to the replicas. This offloads up to 80% of CPU strain from the Primary instance.
2.  **Write Batching (Bulk Inserts):**
    *   When the Worker pulls 10 `OrderIntent` messages from SQS, it does not execute 10 separate `INSERT INTO orders` statements.
    *   It maps the 10 intents into a single Bulk Insert SQL command (`INSERT INTO orders (...) VALUES (...), (...), (...)`). This drastically reduces transaction overhead and network round trips to the database.
3.  **Redis Atomic Decrements (Write-Behind Inventory):**
    *   For extremely hot items (e.g., 500 limited "Free Tealive" vouchers), checking the database on every order causes row locks. 
    *   Instead, we load the inventory count into Redis (`SET inventory:free_voucher 500`).
    *   The API performs an atomic `DECR` in Redis. If it drops below 0, it fails the checkout. The worker later performs the actual SQL update asynchronously. This protects the DB from thousands of concurrent update locks on a single row.

---

## 3. Efficiency & Caching Strategy

To achieve sub-100ms response times for the Catalog module, the backend relies on an aggressive caching tier.

### Multi-Tiered Read Architecture
1.  **L1 Cache (In-Memory / LruCache):** The Go pods maintain an in-memory cache for static configurations (e.g., Country Tax Rules, Active Feature Flags) that update rarely. TTL: 5 minutes.
2.  **L2 Cache (Redis ElastiCache):** The "Fat" translated JSON menu is resolved and cached here based on the `Country:Language` taxonomy. All Flutter app menu fetches hit Redis directly.
3.  **L3 Materialized Views (DynamoDB):** Used exclusively for highly personalized, complex data reads (e.g., the User Home Feed). Background workers compute these heavy JSON payloads and store them in DynamoDB. The API fetches them instantly by `user_id` to guarantee sub-100ms app launch times without executing expensive `JOIN` queries.
4.  **Database (MySQL RDS):** Serves as the ultimate source of truth. Only hit directly by the Admin CMS or when a cache miss occurs.

---

## 4. Stability & Resilience

### Circuit Breakers
External integrations (Payment Gateways, SMS Providers, 3rd Party Delivery APIs) are wrapped in Circuit Breakers (using libraries like `opossum`).
*   *Scenario:* The Thai Prompt-Pay gateway goes down.
*   *Action:* After 5 consecutive timeouts, the Circuit Breaker "opens". The Go app stops sending requests to the gateway, immediately returning a "Payment Gateway Unavailable" error to the user, preventing the entire backend thread pool from stalling while waiting for the dead gateway.

### Connection Pooling & Backpressure
*   Database connections use `pg` or `mysql2` connection pools strictly limited per pod to prevent connection exhaustion on RDS.
*   Rate limiting (via Redis) is applied per user and per IP to prevent bot scraping or DDoS attacks from degrading the experience for legitimate users.

---

## 5. Observability (The "Three Pillars")

To ensure the Cloud Ops team can instantly identify issues across countries, the backend integrates with an APM tool (e.g., Datadog, New Relic, or AWS X-Ray/CloudWatch).

### 1. Tracing (Where did it break?)
*   Every incoming request receives an `X-Trace-Id`.
*   This ID is passed through every layer (API -> Redis -> SQS -> Worker -> DB).
*   If a Thai user's order fails in the background worker 2 minutes after checkout, Ops can search the `Trace-Id` and see the exact millisecond the failure occurred and at which step.

### 2. Metrics (Is the system healthy?)
Go exposes a `/metrics` endpoint (Prometheus format) scraped by CloudWatch/Datadog. Key alerts:
*   **Business Metrics:** "Voucher redemption rate in MY dropped 80%." (Flags a logic bug, even if servers are healthy).
*   **Queue Depth:** "SQS Queue depth > 10,000." (Triggers AWS Auto-Scaling to spin up more Worker Pods).
*   **Cache Hit Ratio:** "Menu endpoint hitting DB > 5% of the time." (Flags a cache invalidation bug).

### 3. Structured Logging (Why did it break?)
*   `console.log` is banned.
*   The backend uses a structured logger (like `pino` or `winston`) outputting strict JSON.
*   Every log includes mandatory contextual metadata injected by middleware:
    ```json
    {
      "level": "error",
      "message": "Payment Gateway Timeout",
      "context": "CheckoutService",
      "country_code": "TH",
      "brand": "baskbear",
      "user_id": "uuid-1234",
      "trace_id": "abc-987"
    }
    ```
*   *Benefit:* During a crisis, Ops can filter logs globally: `level=error AND country_code=TH AND brand=baskbear` to instantly isolate the noise.ly isolate the noise.