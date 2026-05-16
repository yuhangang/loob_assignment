# Database Schema (MySQL 8.0+)

This document provides the foundational MySQL database schema for the Loob Unified App. It implements the "Fat Storage" and "Country Partitioning" patterns discussed in the architecture documents, utilizing JSON columns for translations and strict `country_id` foreign keys for multi-region scalability.

## 1. Core Platform & Geography

The foundational tables that define the multi-tenant nature of the system.

```sql
CREATE TABLE countries (
    id VARCHAR(2) PRIMARY KEY, -- e.g., 'MY', 'TH'
    name VARCHAR(50) NOT NULL,
    currency_code VARCHAR(3) NOT NULL, -- e.g., 'MYR', 'THB'
    currency_multiplier INT DEFAULT 100, -- 100 means stored in cents/sen
    timezone VARCHAR(50) NOT NULL, -- e.g., 'Asia/Kuala_Lumpur'
    tax_rate DECIMAL(5, 4) DEFAULT 0.0000, -- e.g., 0.0600 for 6% SST
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE brands (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL, -- e.g., 'Tealive', 'Baskbear'
    theme_config JSON, -- Hex codes, typography defaults for the Flutter app
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE zones (
    id VARCHAR(50) PRIMARY KEY, -- e.g., 'MY_WEST', 'MY_EAST', 'MY_EAST_AIRPORT'
    country_id VARCHAR(2) NOT NULL,
    name VARCHAR(100) NOT NULL, -- e.g., 'Peninsular Malaysia', 'Sabah/Sarawak Airport'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (country_id) REFERENCES countries(id)
);

CREATE TABLE stores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    brand_id INT NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    zone_id VARCHAR(50) NOT NULL,
    store_code VARCHAR(20) UNIQUE NOT NULL,
    name_translations JSON NOT NULL, -- e.g., {"en": "Tealive KLCC", "ms": "Tealive KLCC"}
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    address_translations JSON,
    timezone VARCHAR(50) NOT NULL, -- Inherits or overrides country timezone
    is_active BOOLEAN DEFAULT true,
    FOREIGN KEY (brand_id) REFERENCES brands(id),
    FOREIGN KEY (country_id) REFERENCES countries(id),
    FOREIGN KEY (zone_id) REFERENCES zones(id)
);

CREATE TABLE feature_flags (
    id INT AUTO_INCREMENT PRIMARY KEY,
    country_id VARCHAR(2) NOT NULL,
    zone_id VARCHAR(50), -- NULL = Applies to whole country, String = restricts to specific zone
    brand_id INT, -- NULL = Applies to both brands, INT = restricts to specific brand (e.g., Tealive only)
    feature_key VARCHAR(100) NOT NULL, -- e.g., 'BRAND_ACTIVE', 'DELIVERY_ACTIVE'
    is_enabled BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (country_id) REFERENCES countries(id),
    FOREIGN KEY (zone_id) REFERENCES zones(id),
    FOREIGN KEY (brand_id) REFERENCES brands(id),
    UNIQUE(country_id, zone_id, brand_id, feature_key)
);
```

## 2. Expressive Menu Catalog

This section utilizes the JSON Translation pattern. Prices are isolated to a pricing table to allow a single 'Signature Boba' item to be sold in both Malaysia and Thailand at different rates without duplicating the master item data.

```sql
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    brand_id INT NOT NULL,
    name_translations JSON NOT NULL,
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    FOREIGN KEY (brand_id) REFERENCES brands(id)
);

CREATE TABLE menu_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    sku_code VARCHAR(50) UNIQUE NOT NULL,
    name_translations JSON NOT NULL,
    desc_translations JSON,
    image_url_sm VARCHAR(255),
    image_url_lg VARCHAR(255),
    dietary_tags JSON, -- e.g., ["halal", "contains_dairy"]
    is_active BOOLEAN DEFAULT true,
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

-- Zone-Specific Pricing
CREATE TABLE menu_item_pricing (
    menu_item_id INT NOT NULL,
    zone_id VARCHAR(50) NOT NULL,
    base_price INT NOT NULL, -- Stored as integer (smallest currency unit)
    tax_inclusive BOOLEAN DEFAULT true,
    PRIMARY KEY (menu_item_id, zone_id),
    FOREIGN KEY (menu_item_id) REFERENCES menu_items(id),
    FOREIGN KEY (zone_id) REFERENCES zones(id)
);

-- Deep Customization (Sizes, Sugar, Ice, Add-ons)
CREATE TABLE customization_groups (
    id INT AUTO_INCREMENT PRIMARY KEY,
    menu_item_id INT NOT NULL,
    name_translations JSON NOT NULL,
    selection_type ENUM('SINGLE_SELECT', 'MULTI_SELECT') NOT NULL,
    is_required BOOLEAN DEFAULT false,
    max_selections INT DEFAULT 1,
    display_order INT DEFAULT 0,
    FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
);

CREATE TABLE customization_options (
    id INT AUTO_INCREMENT PRIMARY KEY,
    group_id INT NOT NULL,
    name_translations JSON NOT NULL,
    price_adjustment INT DEFAULT 0, -- Stored as integer
    is_default BOOLEAN DEFAULT false,
    FOREIGN KEY (group_id) REFERENCES customization_groups(id)
);
```

## 3. Users, Orders & Vouchers

The transactional core. Orders and Vouchers are strictly partitioned by `country_id`.

```sql
CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY, -- String, mapped directly from Firebase Auth UID
    email VARCHAR(255) UNIQUE,
    phone_number VARCHAR(20) UNIQUE,
    preferred_language VARCHAR(5) DEFAULT 'en-US',
    registered_country_id VARCHAR(2), -- Country selected during onboarding
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (registered_country_id) REFERENCES countries(id)
);

CREATE TABLE vouchers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    country_id VARCHAR(2) NOT NULL, -- Vouchers are strictly regional
    zone_id VARCHAR(50), -- NULL = Applies to all zones in the country, otherwise restricted to a specific zone
    brand_id INT, -- NULL = Loob Master Voucher (applies to both Tealive/Baskbear)
    voucher_type ENUM('CART_DISCOUNT', 'BRAND_DISCOUNT', 'SHIPPING') NOT NULL,
    discount_type ENUM('PERCENTAGE', 'FIXED_AMOUNT') NOT NULL,
    discount_value INT NOT NULL, -- Percentage (e.g., 15) or Amount in cents (e.g., 500)
    min_spend INT DEFAULT 0,
    max_discount_cap INT, -- Crucial for percentage vouchers
    starts_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true,
    FOREIGN KEY (country_id) REFERENCES countries(id),
    FOREIGN KEY (zone_id) REFERENCES zones(id),
    FOREIGN KEY (brand_id) REFERENCES brands(id)
);

CREATE TABLE orders (
    id VARCHAR(36) PRIMARY KEY, -- UUID
    user_id VARCHAR(36) NOT NULL,
    store_id INT NOT NULL,
    country_id VARCHAR(2) NOT NULL, -- Partition Key
    status ENUM('PENDING', 'PAYMENT_CONFIRMED', 'PREPARING', 'READY', 'COMPLETED', 'CANCELLED') NOT NULL,
    fulfillment_type ENUM('DINE_IN', 'TAKEAWAY', 'DELIVERY') NOT NULL,
    subtotal INT NOT NULL,
    tax_amount INT NOT NULL,
    discount_amount INT DEFAULT 0,
    total_amount INT NOT NULL,
    applied_voucher_ids JSON, -- Array of applied voucher IDs
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (store_id) REFERENCES stores(id),
    FOREIGN KEY (country_id) REFERENCES countries(id)
);

CREATE TABLE order_items (
    id VARCHAR(36) PRIMARY KEY, -- UUID
    order_id VARCHAR(36) NOT NULL,
    menu_item_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price INT NOT NULL, -- Price at the time of purchase
    customizations_snapshot JSON NOT NULL, -- Snapshot of selected sugar, ice, add-ons
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
);
```

## Key Schema Design Decisions

1.  **JSON Translations:** `name_translations` and `desc_translations` allow the Business Ops team to manage all localizations without needing secondary translation tables. The NestJS API flattens this before sending it to the client.
2.  **`country_id` Partitioning:** Notice how `stores`, `menu_item_pricing`, `vouchers`, and `orders` all have a hard requirement on `country_id`. This allows Cloud Ops to filter data strictly by region, ensuring cross-country contamination does not happen in the CMS or at the database level.
3.  **Flexible Voucher Targeting:** The `vouchers` table uses nullable foreign keys for both `brand_id` and `zone_id`. 
    * If `brand_id` is NULL, it's a "Loob Master Voucher" (applies to both Tealive/Baskbear). 
    * If `zone_id` is NULL, the voucher applies to the whole country. If set to `MY_EAST`, it creates a hyper-targeted regional promotion (e.g., "Free Delivery in East Malaysia").
4.  **Immutable Order Snapshots:** The `order_items` table stores `customizations_snapshot` as JSON. This ensures that if the operations team changes the price of an add-on (e.g., Pearls increase from RM1.50 to RM2.00) tomorrow, historical receipts generated from the `orders` table are not corrupted.
5.  **Integer Currency:** All monetary columns (`base_price`, `discount_value`, `subtotal`) are typed as `INT`. The `countries.currency_multiplier` acts as the divisor (e.g., 100 for MYR cents, 1 for JPY).