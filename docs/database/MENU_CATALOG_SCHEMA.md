# Expressive Menu Catalog Schema

## Overview
To handle the high variability of Southeast Asian markets, the product catalog cannot be a rigid, flat table. It must be an **expressive, hierarchical declaration**. 

### Enterprise Language Resolution (The `Accept-Language` Pattern)
Major enterprise apps (like Grab, Foodpanda, or Uber) **do not** return all available languages in a single JSON payload. Doing so increases the payload size by 300-400%, which degrades performance on slow mobile networks and drains device battery parsing the JSON.

Instead, they use **Server-Side Resolution**:
1. The Flutter App sends a request with an HTTP Header: `Accept-Language: ms-MY` (or `zh-CN`, `th-TH`).
2. The NestJS backend reads this header, resolves the correct translation from the database/Redis, and returns a **flattened JSON** containing *only* that specific language. If the requested language isn't available, the backend automatically falls back to `en-US` before sending the response.

By using this flattened, expressive schema, the Business and Operations teams can configure products tailored to cultural and policy contexts without bloating the mobile client.

## The Flattened Schema Declaration (Resolved for `Accept-Language: ms-MY`)

```json
{
  "catalog_version": "v2.4.1",
  "brand": "tealive",
  "country_code": "MY",
  "currency": "MYR",
  "tax_inclusive": true,
  "language_resolved": "ms-MY", // Tells the client which language was actually resolved
  "categories": [
    {
      "id": "cat_signature_boba",
      "display_order": 1,
      "name": "Boba Signatur", // Flattened from a translations object by the backend
      "products": [
        {
          "id": "prod_pearl_milk_tea",
          "is_available": true,
          "availability_rules": {
            "excluded_outlets": ["store_klia2_express"]
          },
          "name": "Teh Susu Mutiara Signatur",
          "description": "Teh susu klasik kami dibru sempurna dengan mutiara ubi kayu yang kenyal.",
          "media": {
            "image_url_sm": "https://cdn.loob.com/images/pmt_sm.jpg",
            "image_url_lg": "https://cdn.loob.com/images/pmt_lg.jpg"
          },
          "base_price": 890, 
          "dietary_tags": ["halal", "contains_dairy", "caffeine"],
          "customization_groups": [
            {
              "id": "group_size",
              "type": "SINGLE_SELECT",
              "required": true,
              "name": "Pilih Saiz",
              "options": [
                { "id": "opt_size_r", "name": "Biasa", "price_adjustment": 0, "is_default": true },
                { "id": "opt_size_l", "name": "Besar", "price_adjustment": 150, "is_default": false }
              ]
            },
            {
              "id": "group_sugar",
              "type": "SINGLE_SELECT",
              "required": true,
              "name": "Tahap Gula",
              "options": [
                { "id": "opt_sugar_0", "name": "Tiada Gula (0%)", "price_adjustment": 0 },
                { "id": "opt_sugar_50", "name": "Separuh Gula (50%)", "price_adjustment": 0 },
                { "id": "opt_sugar_100", "name": "Gula Biasa (100%)", "price_adjustment": 0, "is_default": true }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

## How It Solves the Assessment Constraints

### 1. Cultural & Policy Context (Dietary Tags)
*   **The Problem:** Different countries have different sensitivities. Halal certification is paramount in Malaysia and Indonesia, while vegan/dairy-free options might be highlighted more in other markets.
*   **The Solution:** The `dietary_tags` array allows the Flutter UI to dynamically render specific icons (e.g., a green Halal logo, a leaf for Vegan) next to the product name. If a country introduces a new allergen warning policy, Ops can add `contains_soy` to the tags without a code release.

### 2. Multi-Language Names & Descriptions (Resolved Server-Side)
*   **The Problem:** Southeast Asia is polyglot, but mobile bandwidth is limited.
*   **The Solution:** The backend resolves the language based on the `Accept-Language` header. The Flutter app receives a lean, pre-translated payload. This saves bandwidth and battery, as the client doesn't need to parse massive translation dictionaries.

### 3. Country-Specific Pricing & Currency
*   **The Problem:** RM 8.90 in Malaysia vs. THB 75 in Thailand. 
*   **The Solution:** The root of the payload defines `currency`. The prices (`base_price`, `price_adjustment`) are always returned as **integers** (smallest currency unit, like cents). The backend resolves regional pricing *before* generating this JSON, so the client does no currency math.

### 4. Deep Customisation (Size, Add-ons, Ice/Sugar)
*   **The Problem:** A cup of coffee or boba is highly configurable.
*   **The Solution:** The `customization_groups` array is a declarative UI builder. `type: "SINGLE_SELECT"` tells Flutter to render Radio Buttons, while `price_adjustment` handles upsells easily.

### 5. Availability Toggles Per Outlet
*   **The Problem:** A specific kiosk doesn't have a blender, so it can't sell Frappes.
*   **The Solution:** The `availability_rules.excluded_outlets` array allows fine-grained control. When the user selects a store, the Flutter app filters out any products where the current `store_id` is in the `excluded_outlets` list.