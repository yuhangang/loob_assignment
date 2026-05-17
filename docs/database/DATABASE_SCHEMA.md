# Loob Unified App: Database Schema (MySQL 8.0+)

This document provides the foundational MySQL database schema for the Loob Unified App. It implements the "Fat Storage" and "Country Partitioning" patterns, utilizing JSON columns for translations and strict `country_id` foreign keys for multi-region scalability.

## 1. Core Platform & Geography

The foundational tables that define the multi-tenant nature of the system.

```sql
CREATE TABLE countries (
    id VARCHAR(2) PRIMARY KEY, -- e.g., 'MY', 'TH'
    name VARCHAR(50) NOT NULL,
    currency_code VARCHAR(3) NOT NULL, -- e.g., 'MYR', 'THB'
    currency_multiplier INT DEFAULT 100, -- 100 means stored in cents/sen
    timezone VARCHAR(50) NOT NULL,
    tax_rate DECIMAL(5, 4) DEFAULT 0.0000,
    default_language VARCHAR(10) NOT NULL DEFAULT 'en-US',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE brands (
    id INT AUTO_INCREMENT PRIMARY KEY,
    slug VARCHAR(50) UNIQUE NOT NULL, -- e.g., 'tealive', 'baskbear'
    name VARCHAR(50) NOT NULL,
    theme_config JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE zones (
    id VARCHAR(50) PRIMARY KEY, -- e.g., 'MY_WEST', 'TH_BKK'
    country_id VARCHAR(2) NOT NULL,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (country_id) REFERENCES countries(id)
);

CREATE TABLE stores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    brand_id INT NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    zone_id VARCHAR(50) NOT NULL,
    store_code VARCHAR(20) UNIQUE NOT NULL,
    name_translations JSON NOT NULL,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    address_translations JSON,
    timezone VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    FOREIGN KEY (brand_id) REFERENCES brands(id),
    FOREIGN KEY (country_id) REFERENCES countries(id),
    FOREIGN KEY (zone_id) REFERENCES zones(id)
);

CREATE TABLE feature_flags (
    id INT AUTO_INCREMENT PRIMARY KEY,
    country_id VARCHAR(2) NOT NULL,
    zone_id VARCHAR(50), -- NULL = Applies to whole country
    brand_id INT, -- NULL = Applies to both brands
    feature_key VARCHAR(100) NOT NULL,
    is_enabled BOOLEAN DEFAULT false,
    FOREIGN KEY (country_id) REFERENCES countries(id),
    FOREIGN KEY (zone_id) REFERENCES zones(id),
    FOREIGN KEY (brand_id) REFERENCES brands(id),
    UNIQUE(country_id, zone_id, brand_id, feature_key)
);
```

## 2. Menu Catalog & Pricing

Utilizes the JSON Translation pattern and zone-specific pricing.

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
    category_id INT NULL,
    brand_id INT,
    item_type ENUM('MAIN', 'ADDON') NOT NULL DEFAULT 'MAIN',
    sku_code VARCHAR(50) UNIQUE NOT NULL,
    name_translations JSON NOT NULL,
    desc_translations JSON,
    image_url_sm VARCHAR(255),
    image_url_lg VARCHAR(255),
    dietary_tags JSON, -- e.g., ["halal", "contains_dairy"]
    is_active BOOLEAN DEFAULT true,
    deleted_at TIMESTAMP NULL,
    FOREIGN KEY (category_id) REFERENCES categories(id),
    FOREIGN KEY (brand_id) REFERENCES brands(id)
);

CREATE TABLE menu_item_pricing (
    menu_item_id INT NOT NULL,
    zone_id VARCHAR(50) NOT NULL,
    base_price INT NOT NULL, -- Stored as integer
    tax_inclusive BOOLEAN DEFAULT true,
    PRIMARY KEY (menu_item_id, zone_id),
    FOREIGN KEY (menu_item_id) REFERENCES menu_items(id),
    FOREIGN KEY (zone_id) REFERENCES zones(id)
);

CREATE TABLE customization_groups (
    id INT AUTO_INCREMENT PRIMARY KEY,
    menu_item_id INT NOT NULL,
    group_code VARCHAR(50) NOT NULL, -- stable config key: size, sugar, addons, milk
    name_translations JSON NOT NULL,
    selection_type ENUM('SINGLE_SELECT', 'MULTI_SELECT') NOT NULL,
    min_selections INT DEFAULT 0,
    is_required BOOLEAN DEFAULT false,
    max_selections INT DEFAULT 1,
    display_order INT DEFAULT 0,
    metadata JSON,
    FOREIGN KEY (menu_item_id) REFERENCES menu_items(id),
    UNIQUE(menu_item_id, group_code)
);

CREATE TABLE customization_options (
    id INT AUTO_INCREMENT PRIMARY KEY,
    group_id INT NOT NULL,
    option_code VARCHAR(50) NOT NULL, -- stable config key: sugar_0, oat_milk, pearl
    linked_menu_item_id INT NULL, -- for sellable add-ons like oat milk, pearl, extra shot
    name_translations JSON NOT NULL,
    price_adjustment INT DEFAULT 0,
    is_default BOOLEAN DEFAULT false,
    display_order INT DEFAULT 0,
    metadata JSON,
    FOREIGN KEY (group_id) REFERENCES customization_groups(id),
    FOREIGN KEY (linked_menu_item_id) REFERENCES menu_items(id),
    UNIQUE(group_id, option_code)
);

CREATE TABLE store_menu_item_status (
    store_id INT NOT NULL,
    menu_item_id INT NOT NULL,
    is_listed BOOLEAN DEFAULT true,
    is_available BOOLEAN DEFAULT true,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (store_id, menu_item_id),
    FOREIGN KEY (store_id) REFERENCES stores(id),
    FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
);
```

## 3. Users, CRM & Loyalty

Vouchers and Loyalty records are strictly partitioned by `country_id`.

```sql
CREATE TABLE users (
    id VARCHAR(64) PRIMARY KEY, -- Firebase Auth UID
    email VARCHAR(255) UNIQUE,
    phone_number VARCHAR(32) UNIQUE,
    preferred_language VARCHAR(10) DEFAULT 'en-US',
    registered_country_id VARCHAR(2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (registered_country_id) REFERENCES countries(id)
);

CREATE TABLE vouchers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    zone_id VARCHAR(50),
    brand_id INT,
    voucher_type ENUM('CART_DISCOUNT', 'BRAND_DISCOUNT', 'SHIPPING') NOT NULL,
    discount_type ENUM('PERCENTAGE', 'FIXED_AMOUNT') NOT NULL,
    discount_value INT NOT NULL,
    min_spend INT DEFAULT 0,
    max_discount_cap INT,
    starts_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true,
    FOREIGN KEY (country_id) REFERENCES countries(id),
    FOREIGN KEY (zone_id) REFERENCES zones(id),
    FOREIGN KEY (brand_id) REFERENCES brands(id)
);

CREATE TABLE user_vouchers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    voucher_id INT NOT NULL,
    status ENUM('AVAILABLE', 'USED', 'EXPIRED') NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    used_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (voucher_id) REFERENCES vouchers(id),
    UNIQUE(user_id, voucher_id)
);

CREATE TABLE loyalty_checkins (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    checkin_date DATE NOT NULL,
    points_awarded INT NOT NULL,
    streak_count INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (country_id) REFERENCES countries(id),
    UNIQUE(user_id, checkin_date)
);
```

## 4. Ordering & Checkout

The transactional core uses `order_intents` for high-concurrency SQS-based fulfillment.

```sql
CREATE TABLE order_intents (
    tracking_id VARCHAR(64) PRIMARY KEY, -- UUID
    trace_id VARCHAR(64) NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    user_id VARCHAR(64) NOT NULL,
    store_id INT NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    fulfillment_type ENUM('DINE_IN', 'TAKEAWAY', 'DELIVERY') NOT NULL,
    status ENUM('PAYMENT_PENDING', 'QUEUED', 'PROCESSING', 'COMPLETED', 'FAILED', 'PAYMENT_FAILED') NOT NULL,
    subtotal INT NOT NULL,
    tax_amount INT NOT NULL,
    discount_amount INT DEFAULT 0,
    total_amount INT NOT NULL,
    voucher_code VARCHAR(50),
    cart_payload JSON NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (store_id) REFERENCES stores(id),
    FOREIGN KEY (country_id) REFERENCES countries(id),
    UNIQUE(country_id, user_id, idempotency_key)
);
```

## 5. Payments

Multi-provider payment support with scoped methods.

```sql
CREATE TABLE payment_providers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    provider_type ENUM('CARD_PROCESSOR', 'EWALLET', 'BANK_TRANSFER', 'QR_PAYMENT', 'CASH') NOT NULL,
    callback_url VARCHAR(255) NOT NULL,
    is_mock BOOLEAN DEFAULT true,
    is_active BOOLEAN DEFAULT true,
    config JSON
);

CREATE TABLE payment_methods (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL,
    provider_code VARCHAR(50) NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    brand_id INT,
    display_name VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    currency_code VARCHAR(3) NOT NULL,
    min_amount INT DEFAULT 0,
    max_amount INT,
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    metadata JSON,
    FOREIGN KEY (provider_code) REFERENCES payment_providers(code),
    FOREIGN KEY (country_id) REFERENCES countries(id),
    FOREIGN KEY (brand_id) REFERENCES brands(id),
    UNIQUE(code, provider_code, country_id, brand_id)
);

CREATE TABLE payment_transactions (
    id VARCHAR(64) PRIMARY KEY,
    order_tracking_id VARCHAR(64) NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    user_id VARCHAR(64) NOT NULL,
    provider VARCHAR(50) NOT NULL,
    payment_method_code VARCHAR(50),
    provider_reference VARCHAR(128),
    status ENUM('PENDING', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'CANCELLED') NOT NULL,
    currency_code VARCHAR(3) NOT NULL,
    amount INT NOT NULL,
    gateway_payload JSON,
    FOREIGN KEY (order_tracking_id) REFERENCES order_intents(tracking_id),
    FOREIGN KEY (country_id) REFERENCES countries(id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE(provider, provider_reference)
);
```

## 6. Campaigns

Banner management and mini-games.

```sql
CREATE TABLE campaigns (
    id INT AUTO_INCREMENT PRIMARY KEY,
    country_id VARCHAR(2) NOT NULL,
    brand_id INT,
    campaign_type ENUM('BANNER', 'DAILY_CHECKIN', 'MINI_GAME', 'FLASH_SALE', 'SOCIAL_FEED') NOT NULL,
    title_translations JSON NOT NULL,
    subtitle_translations JSON,
    image_url VARCHAR(255),
    deep_link VARCHAR(255),
    webview_url VARCHAR(255),
    priority INT DEFAULT 0,
    starts_at TIMESTAMP NOT NULL,
    ends_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true,
    metadata JSON,
    FOREIGN KEY (country_id) REFERENCES countries(id),
    FOREIGN KEY (brand_id) REFERENCES brands(id)
);
```

## Key Schema Design Decisions

1.  **JSON Translations:** Allows managing localizations without secondary tables.
2.  **`country_id` Partitioning:** Ensures cross-country data isolation.
3.  **Order Intents:** Decouples the checkout process from fulfillment for better scalability.
4.  **Integer Currency:** All monetary columns are typed as `INT` to avoid floating-point errors.
