# Architecture Decision Log: Evaluating DynamoDB

**Date:** May 15, 2026
**Subject:** Should we introduce DynamoDB to the stack, specifically to handle a large home feed that updates hourly?
**Status:** Decided

---

## The Dilemma
As the application scales, the primary MySQL database (even with Read Replicas and Redis caching) becomes a bottleneck when attempting to serve complex, read-heavy queries on app launch. 

The specific question raised was: **Do we need DynamoDB to serve a large home feed that updates every hour?**

Introducing DynamoDB immediately adds "Polyglot Persistence" overhead (engineers must now maintain code for MySQL, Redis, and DynamoDB). However, relying entirely on MySQL for a complex home feed will cause the database to crash during high-traffic events.

## The Analysis: Two Scenarios

The decision entirely depends on **how personalized** the home feed is.

### Scenario A: The Regional Feed (Not Personalized)
*   **Context:** The feed contains general promotions, top sellers, and brand news that is identical for every user within a specific zone (e.g., `MY_WEST`).
*   **The Problem with Databases here:** Querying any database (SQL or NoSQL) 100,000 times an hour for the exact same payload is a massive waste of compute resources.
*   **The Verdict (No DynamoDB):** 
    *   We use a **Static Generation & CDN Strategy**.
    *   A background cron job calculates the feed once per hour, saves it as a flat JSON file, and pushes it to AWS S3.
    *   AWS CloudFront (CDN) serves this JSON to the Flutter app in ~5ms. The databases see zero traffic from app launches.

### Scenario B: The Highly Personalized Feed
*   **Context:** The feed is algorithmically tailored for *every single user* (e.g., "Recommended for You" based on past orders, loyalty tier progress, and targeted vouchers).
*   **The Problem with MySQL:** Generating this feed dynamically on app launch requires complex `JOIN`s across `users`, `orders`, `loyalty`, and `menu_items`. Doing this synchronously for thousands of users concurrently will cause massive CPU spikes and slow app launch times.
*   **The Verdict (DynamoDB is Required):**
    *   We use DynamoDB as a **Materialized View Layer**.
    *   Background workers (NestJS) crunch the heavy MySQL joins every hour (or upon a trigger like completing an order) and generate a massive, pre-calculated JSON payload specifically for that user.
    *   This JSON is saved into a DynamoDB table (`UserHomeFeeds`) with `user_id` as the Partition Key.
    *   When the Flutter app launches, the API does a simple `GetItem` from DynamoDB, returning the complex feed in single-digit milliseconds without touching MySQL.

---

## Final Decision
We will proceed with **Scenario B**. 

Because the Loob Unified App requires a highly engaging, personalized experience (gamification, targeted vouchers, loyalty integration), the home feed must be tailored per user. 

Therefore, **DynamoDB is formally integrated into the architecture** as the L3 Read Layer specifically to serve these pre-computed Materialized Views, guaranteeing sub-100ms app launch times while protecting the MySQL relational core.