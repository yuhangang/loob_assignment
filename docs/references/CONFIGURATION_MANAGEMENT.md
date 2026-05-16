# Configuration & Content Management Strategy

## Overview
Efficiently managing a multi-country, multi-brand application requires decoupling content and configuration from the core application code. To empower business and marketing teams without creating engineering bottlenecks, this system categorizes assets, copy, and settings based on their expected update frequencies.

## 1. Low Frequency (App Store / OTA Updates)
*Updates that require compiling a new version of the app or pushing large structural changes.*

*   **Core UI Layouts & Logic:** The structural foundation of the app, navigation flows, and core SDK integrations.
*   **Default Assets:** Fallback placeholder images, base fonts, and default brand icons packaged within the app bundle to ensure a functioning offline state.
*   **Base Translations:** A fallback locale file (e.g., `en_US.json`) shipped with the app to prevent empty UI elements before the initial backend handshake.
*   **Management:** Handled by the **Engineering team** via standard CI/CD pipelines (GitHub Actions) and App Store/Play Store releases. Over-The-Air (OTA) updates (e.g., via tools like Shorebird) can be used for critical, urgent bug fixes without waiting for App Store review.

## 2. Medium Frequency (CMS / Backend Admin Portal)
*Updates that affect business rules, regional settings, and operational data. These are fetched by the app on startup or when the user changes context (e.g., switches countries).*

*   **Feature Flags:** Toggling modules per country (e.g., enabling "Delivery Partner Integration" in Malaysia but disabling it temporarily in Vietnam).
*   **Taxation & Currency Rules:** Adjusting VAT/SST rates or currency multipliers.
*   **Store Information:** Updating store hours, new locations, and temporary closures.
*   **Standard Localised Copywriting:** UI text that changes occasionally (e.g., updating the phrasing of a checkout button, error messages, or dietary tag labels).
    *   **Workflow:** Managed via a headless Translation Management System (TMS) like Lokalise or directly within the **Loob Admin Portal**. The backend aggregates these into a cached JSON payload (`/api/v1/translations?lang=th_TH`) fetched on app launch.
*   **Menu Catalog Structure:** Category hierarchies, permanent menu items, and standard pricing.
*   **Management:** Handled by **Country Managers and Operations Teams** via the React Admin Portal. Data is persisted in MySQL RDS and heavily cached in Redis. 

## 3. High Frequency (Dynamic Content / CDN)
*Updates driven by marketing campaigns, daily promotions, and high-engagement events. These require instant, zero-friction propagation without app restarts.*

*   **Banners & Campaign Assets:** Promotional graphics, slider images, and flash sale announcements.
*   **Dynamic App Icons & Splash Screens:** Specialized assets tied to short-term events (e.g., dynamically swapping the app icon for a 3-day festive Baskbear campaign).
*   **Gamification Content:** Daily check-in rewards configurations, active mini-game URLs (WebViews).
*   **Management Strategy (The "Asset Manifest" Approach):**
    1.  **Marketing Team Workflow:** The marketing team uploads images and defines campaign rules (targeting, start/end times) in the Admin CMS.
    2.  **CDN Distribution:** The CMS pushes heavy assets (images, animations) directly to an **AWS S3 bucket**, which is served globally via **AWS CloudFront (CDN)**. This ensures low-latency access across all Southeast Asian regions without hitting the core API.
    3.  **Manifest Generation:** The CMS generates a lightweight JSON manifest (e.g., `active_campaigns_MY.json`) containing the CDN URLs, deep links, and validity timestamps, stored in Redis for instant retrieval.
    4.  **Client Fetching:** The Flutter app polls this lightweight manifest (or receives a silent FCM push notification to invalidate its local cache). It then asynchronously downloads the new images from CloudFront, ensuring the UI updates seamlessly while remaining responsive.

## Summary Matrix

| Asset/Config Type | Update Frequency | Storage/Delivery Mechanism | Managed By |
| :--- | :--- | :--- | :--- |
| Core Logic, Fallback Assets | Low (Monthly) | App Bundle / App Stores | Engineering |
| Feature Flags, Tax, Store Hours | Medium (Weekly/Daily) | MySQL -> Redis -> NestJS API | Ops / Country Managers |
| UI Copywriting (Translations) | Medium (Weekly) | TMS API / Admin Portal | Content / Product Team |
| Banners, Dynamic Icons | High (Hourly/Daily) | S3 -> CloudFront (CDN) | Marketing Teams |
| Flash Sales, Real-time Inventory| Very High (Seconds/Mins) | Redis / WebSockets | Automated / Ops |