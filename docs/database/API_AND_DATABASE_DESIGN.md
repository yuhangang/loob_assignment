# API & Database Design for Operational Efficiency

When operating across multiple countries and languages, the friction between Business Operations (Content/Pricing), Tech Product (App/API), and Cloud Operations (Infrastructure/Scaling) can destroy velocity. 

To achieve maximum efficiency, the system must adhere to a strict **Separation of Concerns** at the API and Database levels. 

Here is the industry-standard architecture to handle this "Golden Triangle" of efficiency.

---

## 1. Database Design: The "Fat" Storage

The database must be optimized for **Business Operations (Admin CMS)**. The business team needs to see all translations, all prices, and all rules simultaneously to manage them effectively.

### A. The JSON Translation Pattern (MySQL 8.0+)
Instead of creating massive, complex joined tables for every translatable string, modern systems leverage MySQL's native JSON columns for localized text.

**Table: `menu_items`**
| id | category_id | brand_id | base_price | name_translations (JSON) | desc_translations (JSON) |
|---|---|---|---|---|---|
| 101 | 5 | 1 | 890 | `{"en": "Pearl Tea", "ms": "Teh Mutiara", "zh": "珍珠奶茶"}` | `{"en": "...", "ms": "..."}` |

*Why this is efficient:*
*   **Business Ops:** The Admin CMS fetches the raw JSON. The CMS UI renders a tabbed interface (English | Malay | Chinese) for the content writer. They update all languages in one API call.
*   **Tech Product:** No complex SQL `JOIN`s are required when reading or writing translations.

### B. The Country Partitioning Pattern
Every operational entity (Stores, Orders, Vouchers, Campaigns) MUST have a `country_id` as a strict foreign key.

*Why this is efficient:*
*   **Business Ops:** Ensures Country Managers are sandbox-isolated. A Thai manager's CMS dashboard automatically filters `WHERE country_id = 'TH'`, preventing them from accidentally altering Malaysian data.
*   **Cloud Ops:** If a country passes strict data-residency laws, Cloud Ops can easily shard or replicate the database by extracting all rows `WHERE country_id = 'VN'` into a physically separate AWS RDS instance in Vietnam.

---

## 2. API Design: The Contextual Resolution (BFF Pattern)

The backend API acts as a **Backend-For-Frontend (BFF)**. It bridges the gap between the "Fat" database and the "Lean" mobile app. 

### A. Strict Header Contracts
The Flutter app should almost never pass `country` or `language` inside the URL or JSON payload for read requests. It must use HTTP Headers.

**Client Request:**
```http
GET /api/v1/catalog/categories
X-Country-Code: MY
Accept-Language: ms-MY
```

### B. Middleware Resolution
The Go API intercepts these headers via a global middleware.
1.  **Read Database:** Fetches the "Fat" data for `MY`.
2.  **Flatten Language:** Looks at `name_translations`. Since `Accept-Language` is `ms-MY`, it extracts the Malay string and drops the rest.
3.  **Apply Fallbacks:** If the Malay string is empty, it falls back to the default `en-US` string.

**Server Response (Lean):**
```json
{
  "id": 101,
  "name": "Teh Mutiara",
  "price": 890
}
```

*Why this is efficient:*
*   **Tech Product (App):** The Flutter developers write zero logic for language fallback or currency math. They just bind `json['name']` to the Text widget. This drastically reduces mobile app bugs and QA testing time.

---

## 3. Cloud Operations: The Multi-Dimensional Cache

Caching is where multi-country/multi-language systems usually fail (e.g., serving a Thai menu to a Malaysian user). Cloud Ops must define a strict caching taxonomy in **Redis**.

### A. The Cache Key Taxonomy
Redis keys must be deterministic and incorporate both the **Country** and the **Language**.

`Pattern: {domain}:{country_code}:{language_code}:{entity_id}`

*   **Key:** `menu:MY:ms-MY:cat_signature_boba` -> Contains flattened Malay JSON.
*   **Key:** `menu:MY:en-US:cat_signature_boba` -> Contains flattened English JSON.
*   **Key:** `menu:TH:th-TH:cat_signature_boba` -> Contains flattened Thai JSON.

### B. Cache Invalidation (Event-Driven)
When Business Ops updates a price or translation in the CMS:
1.  CMS saves to MySQL.
2.  Go fires an event: `MenuUpdated { country: 'MY', category_id: 'cat_signature_boba' }`.
3.  The Redis worker invalidates **ALL** language variants for that specific country key using wildcard deletion: `DEL menu:MY:*:cat_signature_boba`.

*Why this is efficient:*
*   **Cloud Ops:** Cache hit ratios remain at 99%. During a Flash Sale, the database sees zero traffic for menu reads. 
*   **Business Ops:** They click "Publish" in the CMS, and the changes propagate to mobile apps instantly without cache-staleness tickets being raised to the tech team.

---

## Summary of the "Golden Triangle" Workflow

1.  **Business creates content:** A marketer in Bangkok opens the CMS. The CMS (via their token) knows they are `TH`. They upload a banner and type the Thai and English descriptions. The CMS saves the "Fat" JSON to MySQL.
2.  **Cloud caches it:** The Go backend detects the DB update, generates the flattened Thai payload and the flattened English payload, and stores both in Redis under `menu:TH:th-TH` and `menu:TH:en-US`.
3.  **Tech consumes it:** A tourist from London opens the app in Bangkok. Their phone sends `X-Country-Code: TH` and `Accept-Language: en-US`. The API hits Redis, instantly returning the English menu with Thai prices. The Flutter app simply renders what it receives.
