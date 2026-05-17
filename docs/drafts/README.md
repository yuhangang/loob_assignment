# Loob Unified App — Loob Holding Sdn Bhd Assessment

> Candidate: Yuhang Ang | Submission Date: May 2026

## App Overview
The assessment prompt offered a wonderful challenge: *"Reimagine the experience from the ground up."* While the prompt suggested choosing *either* Tealive or Baskbear, I felt the most exciting way to reimagine the Loob digital experience was to envision a unified future: a **"Twin App."**

Rather than building a standard ordering template, I wanted to explore how we could integrate both beloved brands into a single ecosystem while fiercely protecting their unique identities. The architecture shares a single, highly scalable backend engine (Cart, Payments, Loyalty). However, on the frontend, the Flutter app utilizes a dynamic `ThemeData` engine. When a user switches from Tealive to Baskbear, the app fundamentally re-themes itself—shifting from playful purple to urban orange—preserving the unique brand vibe seamlessly.

*(Note: For the scope of this 7-day assessment, deep native integrations like dynamic app icons were architected but bypassed in implementation to focus on the 4 core modules).*

## Tech Stack
| Layer | Technology | Justification |
|---------------|------------|---------------|
| Frontend | Flutter | True cross-platform codebase with excellent support for dynamic, runtime theming (crucial for the Tealive/Baskbear UI switch). |
| State Mgmt | Riverpod & BLoC | Riverpod for DI and simple states (Theme switching). BLoC for complex, event-driven concurrency (Checkout state machine). |
| Backend | Go (Echo v4) | Strong domain boundaries. Supports the profiled modular monolith pattern required for independent API and worker scaling. |
| Database | MySQL | Essential for relational integrity (Orders, Customizations, Vouchers). Uses native JSON columns for localized text. |
| Caching | Redis & Isar | Redis (Backend) for queue rate-limiting and L2 Menu cache. Isar (Frontend) for highly reactive, NoSQL local cart storage. |
| Cloud | AWS | Fargate (ECS) for serverless compute, SQS for queueing, Aurora Serverless for auto-scaling the DB during flash sales. |
| Auth | Firebase | Industry standard for mobile Phone/OTP login. Generous free tier and frictionless Flutter integration via `firebase_auth`. |

## Project Structure
The repository is structured as a monorepo to ensure types and schemas remain in sync:
- `/mobile`: The Flutter application, organized by Feature-Driven Modularity (`core/`, `features/menu`, `features/cart`).
- `/backend`: The Go API and SQS Worker deployment configurations.
- `/database`: Migration scripts and seeder data.

## Design & Architecture Decisions (Q1 to Q6)

**Q1. Why did you design the app this way? Walk us through your design philosophy.**
My design philosophy centers around the concept of a "Three-Tiered Portal" (`[ Discover All ] | [ Tealive ] | [ Baskbear ]`). I wanted to reimagine the app not just as an ordering tool, but as a lifestyle hub. The default "Discover All" tab acts as a neutral zone utilizing a clean, white/gray palette to prevent visual clashing between brands, gently introducing cross-selling combo deals. Tapping a specific brand triggers a "Liquid Transition" animation, deeply immersing the user in that specific brand's colorway and typography, ensuring we don't dilute the unique energy of Tealive or the bold urban feel of Baskbear.

**Q2. How did you approach multi-country UX? What decisions did you make for localisation and regionalisation?**
Southeast Asian languages (Thai, Vietnamese) have varying lengths and vertical tonal marks. I avoided hardcoded container heights, opting for `Flexible` layouts and scrollable views to prevent text clipping. Furthermore, I adopted an **"Accept-Language" Header Strategy**. Instead of downloading a massive, multi-language dictionary to the app, the backend resolves the language dynamically, sending a lean, pre-translated JSON payload.

**Q4. Which state management solution did you choose and why? What trade-offs did you accept?**
I used a hybrid approach. **Cubit** is used for linear UI changes (like toggling the brand theme). **BLoC** is used for complex, asynchronous flows (like the cart and checkout). 
*Trade-off:* While using two solutions increases the learning curve slightly for junior devs, it prevents the massive boilerplate of BLoC being used for trivial UI toggles, resulting in a cleaner, more maintainable codebase.

**Q5. How did you structure your Flutter project? Describe your folder structure and layer separation.**
I used a Feature-Driven architecture. Inside `lib/features/menu/`, you will find `data/` (Repositories/API), `domain/` (Business Logic), and `presentation/` (UI/BLoC). This strict separation ensures the UI knows nothing about Dio or Isar. I utilized `get_it` and `injectable` for robust Dependency Injection.

**Q6. How does your app handle offline scenarios or slow connectivity, which is common in Southeast Asia?**
I implemented **Drift** (a robust, reactive SQL database for Flutter) for caching the Cart and Active Orders. If a user is on a slow 3G network, the app instantly loads the cached cart and relational order state from Drift, keeping the UI responsive while silently polling and syncing with the backend in the background.

## Database Design (Q7 to Q10)

**Q7. Walk us through your core schema. How do you model a menu item with country-specific pricing, an order with its line items, and a voucher with redemption rules?**
- **Menu/Pricing:** `menu_items` holds the SKU and localized `name_translations` (JSON). Pricing is abstracted to `menu_item_pricing` linked via `zone_id` (e.g., MY_EAST), allowing the same SKU to have different prices in East vs. West Malaysia.
- **Orders:** `orders` links to `users` and `stores`. Crucially, `order_items` stores a `customizations_snapshot` (JSON) to ensure historical receipts aren't corrupted if operations change an add-on price tomorrow.
- **Vouchers:** The `vouchers` table uses nullable foreign keys (`brand_id` and `zone_id`). If `brand_id` is NULL, it's a cross-brand master voucher. If `zone_id` is MY_EAST, it's a regional promo.

**Q8. How does your schema handle multi-country data?**
Through strict **Row-Level Partitioning**. Every transactional table (`stores`, `orders`, `vouchers`) has a mandatory `country_id` column. This logically separates data. If legal constraints eventually require physical isolation (e.g., for Indonesia), DevOps can simply export `WHERE country_id='ID'` to a new regional database without changing the schema.

**Q9. What indexing strategy did you apply?**
Indexes are applied to foreign keys (`country_id`, `store_id`) and high-frequency lookup columns (`sku_code`, `voucher.code`).

**Q10. How would you handle MySQL schema migrations safely in a live system with no downtime?**
By decoupling schema deployment from code deployment. We use tools like Flyway. We add the new column (allowing NULLs) in Step 1. We deploy the new Go code that writes to the new column in Step 2. We backfill old data in Step 3. Finally, we apply constraints (NOT NULL) in Step 4.

## AWS Architecture (Q11 to Q19)

**Q11. Describe your overall AWS architecture.**
Traffic hits an Application Load Balancer (ALB) and routes to a Go Modular Monolith hosted on AWS ECS Fargate (Private Subnet). The API communicates with ElastiCache (Redis) and Aurora MySQL v2. 

**Q13. How would you scale the ordering service to handle a flash sale (10x normal load in under 5 minutes)?**
We utilize an **Asynchronous Queue Architecture**. The API intercepts the checkout, checks Redis for inventory (using atomic `DECR` to prevent row locks), and pushes an `OrderIntent` to an **AWS SQS FIFO Queue** in <50ms. A separate auto-scaling pool of Go "Worker Profiles" consumes the queue at a throttled rate, executing bulk SQL inserts. The database never crashes because it is shielded by SQS.

**Q14. Where and how would you implement caching?**
- **L1 (In-Memory):** Tax rules and feature flags in Go.
- **L2 (Redis):** Flattened, localized JSON Menu payloads.
- **L3 (DynamoDB):** Materialized Views for highly personalized, complex user home feeds to guarantee sub-100ms app launches without heavy SQL joins.

**Q15. How would you manage image and media assets at scale across multiple countries?**
The CMS uploads heavy assets (banners, app icons) to AWS S3. These are served globally via AWS CloudFront (CDN), ensuring users in Thailand and Malaysia experience low-latency image loads without hitting the backend API.
