# Mobile Architecture: Flutter (Loob Unified App)

This document outlines the architecture for the cross-platform Flutter application. It emphasizes modularity, predictable state management using the BLoC pattern, robust networking, and an optimized local caching strategy.

---

## 1. Core Architecture Pattern: Feature-Driven Modularity

To prevent the codebase from becoming a "Big Ball of Mud" as the app scales across countries and brands, the project uses a **Feature-Driven (Domain-Driven) modular structure**.

```text
lib/
├── core/                   # Highly reusable, domain-agnostic code
│   ├── network/            # Dio client, interceptors, error handling
│   ├── di/                 # Dependency Injection setup (get_it)
│   ├── theme/              # Dynamic theme switching (Tealive/Baskbear)
│   ├── storage/            # Local DB/Cache implementations
│   └── utils/              # Extensions, formatters
├── features/               # Domain-specific modules
│   ├── menu/
│   │   ├── data/           # Repositories, Models, Data Sources (API & Local)
│   │   ├── domain/         # Entities, Use Cases (Business Logic)
│   │   └── presentation/   # UI (Widgets, Pages), State (BLoC/Cubit)
│   ├── cart/
│   ├── checkout/
│   └── campaigns/
└── main.dart
```

### Dependency Injection (DI)
We use `get_it` alongside `injectable` for code generation. This ensures that Repositories, Data Sources, and BLoCs are decoupled. 
*   **Why:** It makes testing vastly easier. We can easily swap out a `ProductionMenuRepository` with a `MockMenuRepository` during unit testing without changing the UI code.

---

## 2. State Management: The BLoC / Cubit Hybrid

We utilize the `flutter_bloc` package, employing a strict rule-based approach to differentiate between `Bloc` and `Cubit`.

### When to use `Cubit` (State Driven by Functions)
Use Cubit for **simple, linear state transformations** where the UI triggers an action and awaits a result.
*   **Examples:** Toggling a dietary filter, switching the active brand theme from Tealive to Baskbear, expanding/collapsing a category list.
*   **Why:** Less boilerplate. The UI directly calls `context.read<ThemeCubit>().switchBrand(Brand.baskbear)`.

### When to use `Bloc` (State Driven by Events)
Use BLoC for **complex, asynchronous, event-driven flows** that require debouncing, complex stream transformations, or handling race conditions.
*   **Examples:**
    *   **Search/Filtering:** Debouncing search input as the user types to prevent spamming the backend.
    *   **Checkout/Payment Flow:** Handling an intricate state machine (Init -> Verifying Voucher -> Polling SQS Queue -> Success/Fail -> Updating Local Cart).
    *   **Cart Syncing:** Handling concurrent add/remove events where order matters.
*   **Why:** The explicit `Event` -> `State` mapping with stream transformers (like `restartable` or `debounceTime`) handles complex concurrency perfectly.

---

## 3. Networking Layer (Dio)

We use `dio` for all HTTP requests due to its powerful interceptor architecture.

### Interceptor Strategy
1.  **Auth Interceptor:** Automatically injects the Firebase Auth JWT token into the `Authorization` header. If a 401 occurs, it automatically attempts a token refresh and retries the original request.
2.  **Context Interceptor:** Automatically injects the `X-Country-Code` and `Accept-Language` headers required by the backend's API design (as defined in `API_AND_DATABASE_DESIGN.md`).
3.  **Logging Interceptor:** Pretty-prints network requests/responses in debug mode for easier troubleshooting.

---

## 4. Local Caching Strategy: SQL vs. NoSQL

The app needs to cache data to remain responsive on slow Southeast Asian networks (3G/Edge) and handle offline scenarios gracefully. 

Here is the analysis and decision for what technology to use for different data types:

### A. Active/Current Orders (Pickup Status) & Complex Relational Data
**Decision: SQL (using `drift`)**
*   **Why:** A user's active order has deep relational ties (Order -> Order Items -> Customizations snapshot). If the app needs to query "Show me all active orders from Tealive sorted by time," SQL is highly efficient. Furthermore, updating a specific nested item (like marking a single line item as "unavailable" based on a push notification) is much safer in an ACID-compliant SQL database. `drift` provides type-safe, reactive streams over SQLite, pairing perfectly with our BLoC state management.
*   **Implementation:** Store the active order state locally. When the app resumes from the background, it instantly shows the SQL-cached order status while silently polling the backend to see if it moved from "Preparing" to "Ready for Pickup".

### B. UI Copywriting, Manifests & Simple Key-Value Settings
**Decision: NoSQL / Key-Value (using `hive` or `shared_preferences`)**
*   **Why:** The backend sends flattened JSON for translations and configuration manifests (e.g., `active_campaigns_MY.json`). We do not need to query inside this JSON; we just need to retrieve it instantly by key. `hive` is incredibly fast for synchronous, in-memory reads of flat JSON/Dart Objects.
*   **Implementation:** 
    *   `hive.box('config').put('translations_th', jsonPayload)`
    *   `hive.box('settings').put('preferred_brand', 'baskbear')`

### C. Images (Banners, Menu Items, Icons)
**Decision: File System Caching (using `cached_network_image`)**
*   **Why:** Never store image blobs or Base64 data in SQLite or Hive. It bloats the database size rapidly, leading to performance degradation and memory crashes.
*   **Implementation:** Use the `cached_network_image` package. It automatically downloads the image from AWS CloudFront (CDN), saves it to the device's native temporary cache directory (which the OS can clean up if storage runs low), and provides instant retrieval for the UI.

### Summary of Caching Stack
| Data Type | Technology Choice | Package | Justification |
| :--- | :--- | :--- | :--- |
| **Relational Data** (Orders, Cart) | **SQL** | `sqflite` | Requires complex querying, sorting, and structural integrity. |
| **Flat JSON** (Copywriting, Config) | **NoSQL** | `hive` | Requires blazing fast, synchronous key-value retrieval. |
| **Media** (Images, Banners) | **File System** | `cached_network_image` | Prevents DB bloat; allows OS-level cache management. |

---

## 5. Mobile Security & Pen-Test Readiness

To ensure the application passes rigorous enterprise penetration testing while remaining maintainable, we implement a pragmatic, multi-layered security strategy. We avoid over-complicating the frontend with custom cryptographic engines, relying instead on proven native integrations.

### A. Environment Integrity (Root & Jailbreak Detection)
Penetration testers will immediately attempt to run the app on compromised devices to hook into memory and read variables.
*   **Implementation:** We utilize the `freerasp` package (or `root_jailbreak_sniffer`) to execute checks during app initialization.
*   **Action:** If a compromised environment is detected (e.g., Magisk on Android, Cydia on iOS), the app displays a fatal "Security Violation" screen and actively prevents login or checkout flows.

### B. Network Security (Man-in-the-Middle Prevention)
Pen-testers will use tools like Charles Proxy or Burp Suite to intercept traffic. Standard HTTPS is not enough if the attacker installs a custom root certificate on the device.
*   **Implementation:** **SSL Certificate Pinning**.
*   **How:** Instead of hardcoding public keys in Dart (which can be decompiled), we use the `dio_ssl_pinning` interceptor or native network security configs (`network_security_config.xml` on Android, `NSAppTransportSecurity` on iOS) to pin the backend API's certificate.
*   **Fallback:** If the certificate does not match the pinned hash, Dio immediately aborts the connection at the TLS layer.

### C. Secure Storage (Token & PII Protection)
Never store JWTs, OAuth tokens, or Personally Identifiable Information (PII) in Hive or SharedPreferences, as these are stored in plain text.
*   **Implementation:** `flutter_secure_storage`.
*   **How:** This package wraps `Keystore` on Android and `Keychain` on iOS. All session tokens are encrypted natively by the OS hardware layer. Even if the device is stolen and the filesystem extracted, the tokens remain mathematically secure.

### D. Anti-Bot & VPN Abuse Mitigation
During flash sales, automated scalper bots and users spoofing locations via VPNs pose a massive risk to campaign integrity.
*   **Implementation (Bot Detection):** We implement **reCAPTCHA Enterprise** (or AWS WAF Captcha via a hidden webview/SDK) explicitly on high-risk endpoints like `/checkout` and `/auth/register`. We do *not* penalize normal browsing, but high-velocity automated checkouts are challenged or silently dropped.
*   **Implementation (VPN/Proxy Detection):** We do not rely on the Flutter client to detect VPNs, as this is easily spoofed by advanced attackers. Instead, we handle this **Server-Side**. 
    *   The Go API inspects the incoming IP against AWS WAF's managed "Anonymous IP List" (which flags known VPNs, Tor nodes, and hosting providers).
    *   If a user attempts to redeem a "Malaysia-only" flash sale voucher from an IP registered to DigitalOcean Singapore, the backend rejects it with a `403 Forbidden` rather than relying on the client's GPS.

---

## 6. UI/UX, Layout & Device Support Strategy

To ensure a consistent, accessible, and high-quality user experience across devices while managing development scope, the app adheres to the following strict layout and integration constraints:

### A. Mobile-First Responsive Design
*   **Mobile Optimized:** The UI is designed mobile-first. For phones, the UI will be highly concise, focusing on immediate calls to action (e.g., "Add to Cart", "Checkout") and essential product information to prevent screen clutter.
*   **Tablet Scaling (Constraint):** To manage scope, we will not build bespoke, multi-column layouts specifically for tablets. The constraint is simply that the mobile layout must "not break." It will use `Center` and `ConstrainedBox` (e.g., `maxWidth: 600`) wrappers so that on a tablet or desktop, the app maintains its concise mobile form factor in the center of the screen rather than stretching grotesquely or crashing.

### B. Device Orientation
*   **Portrait Only:** The application is strictly locked to **Portrait Mode**. Landscape mode is disabled at the native level (`SystemChrome.setPreferredOrientations`) to simplify layout math and ensure the gamified "Twin App" transitions look flawless.

### C. Typography & Accessibility
*   **Consistent Spacing:** The design system implements rigid spatial tokens (e.g., 8px, 16px, 24px) for padding and margins that scale predictably.
*   **Font Scaling (Accessibility):** The layout is architected to safely handle OS-level font scaling. Text containers avoid fixed heights. We use `Flexible`, `Expanded`, and `IntrinsicHeight` extensively so that if a user increases their device's text size for accessibility, the UI gracefully wraps or scrolls rather than clipping the text.

### D. Native Integrations Scope (Assessment Constraint)
For the scope of this implementation, deep native device integrations are handled pragmatically to save time:
*   **Fully Implemented:** `firebase_auth` (Phone/OTP Login) is a core requirement and will be fully wired up.
*   **Mockups / Interfaces Only:** Advanced native features such as Dynamic App Icons, Deep Linking, Push Notifications, and Analytics. We will architect the code (e.g., creating a `NotificationService` interface), but the actual native iOS/Android plumbing will be mocked out to focus engineering effort on the core four assessment modules.
