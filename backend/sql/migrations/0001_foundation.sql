-- ==========================================
-- 1. GEOGRAPHY & CORE PLATFORM
-- ==========================================

CREATE TABLE IF NOT EXISTS countries (
    id VARCHAR(2) PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    currency_code VARCHAR(3) NOT NULL,
    currency_multiplier INT NOT NULL DEFAULT 100,
    timezone VARCHAR(50) NOT NULL,
    tax_rate DECIMAL(5, 4) NOT NULL DEFAULT 0.0000,
    default_language VARCHAR(10) NOT NULL DEFAULT 'en-US',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS brands (
    id INT AUTO_INCREMENT PRIMARY KEY,
    slug VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(50) NOT NULL,
    theme_config JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS zones (
    id VARCHAR(50) PRIMARY KEY,
    country_id VARCHAR(2) NOT NULL,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_zones_country FOREIGN KEY (country_id) REFERENCES countries(id)
);

CREATE TABLE IF NOT EXISTS stores (
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
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_stores_brand FOREIGN KEY (brand_id) REFERENCES brands(id),
    CONSTRAINT fk_stores_country FOREIGN KEY (country_id) REFERENCES countries(id),
    CONSTRAINT fk_stores_zone FOREIGN KEY (zone_id) REFERENCES zones(id)
);

-- ==========================================
-- 2. MENU CATALOG & PRICING
-- ==========================================

CREATE TABLE IF NOT EXISTS categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    brand_id INT NOT NULL,
    name_translations JSON NOT NULL,
    display_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT fk_categories_brand FOREIGN KEY (brand_id) REFERENCES brands(id)
);

CREATE TABLE IF NOT EXISTS menu_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    sku_code VARCHAR(50) UNIQUE NOT NULL,
    name_translations JSON NOT NULL,
    desc_translations JSON,
    image_url_sm VARCHAR(255),
    image_url_lg VARCHAR(255),
    dietary_tags JSON,
    is_active BOOLEAN NOT NULL DEFAULT true,
    deleted_at TIMESTAMP NULL,
    CONSTRAINT fk_menu_items_category FOREIGN KEY (category_id) REFERENCES categories(id)
);

CREATE TABLE IF NOT EXISTS menu_item_pricing (
    menu_item_id INT NOT NULL,
    zone_id VARCHAR(50) NOT NULL,
    base_price INT NOT NULL,
    tax_inclusive BOOLEAN NOT NULL DEFAULT true,
    PRIMARY KEY (menu_item_id, zone_id),
    CONSTRAINT fk_menu_item_pricing_item FOREIGN KEY (menu_item_id) REFERENCES menu_items(id),
    CONSTRAINT fk_menu_item_pricing_zone FOREIGN KEY (zone_id) REFERENCES zones(id)
);

CREATE TABLE IF NOT EXISTS customization_groups (
    id INT AUTO_INCREMENT PRIMARY KEY,
    menu_item_id INT NOT NULL,
    name_translations JSON NOT NULL,
    selection_type ENUM('SINGLE_SELECT', 'MULTI_SELECT') NOT NULL,
    is_required BOOLEAN NOT NULL DEFAULT false,
    max_selections INT NOT NULL DEFAULT 1,
    display_order INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_customization_groups_item FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
);

CREATE TABLE IF NOT EXISTS customization_options (
    id INT AUTO_INCREMENT PRIMARY KEY,
    group_id INT NOT NULL,
    name_translations JSON NOT NULL,
    price_adjustment INT NOT NULL DEFAULT 0,
    is_default BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT fk_customization_options_group FOREIGN KEY (group_id) REFERENCES customization_groups(id)
);

-- ==========================================
-- 3. USERS, VOUCHERS & LOYALTY
-- ==========================================

CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY,
    email VARCHAR(255) UNIQUE,
    phone_number VARCHAR(32) UNIQUE,
    preferred_language VARCHAR(10) NOT NULL DEFAULT 'en-US',
    registered_country_id VARCHAR(2),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_users_country FOREIGN KEY (registered_country_id) REFERENCES countries(id)
);

CREATE TABLE IF NOT EXISTS vouchers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    zone_id VARCHAR(50),
    brand_id INT,
    voucher_type ENUM('CART_DISCOUNT', 'BRAND_DISCOUNT', 'SHIPPING') NOT NULL,
    discount_type ENUM('PERCENTAGE', 'FIXED_AMOUNT') NOT NULL,
    discount_value INT NOT NULL,
    min_spend INT NOT NULL DEFAULT 0,
    max_discount_cap INT,
    starts_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT fk_vouchers_country FOREIGN KEY (country_id) REFERENCES countries(id),
    CONSTRAINT fk_vouchers_zone FOREIGN KEY (zone_id) REFERENCES zones(id),
    CONSTRAINT fk_vouchers_brand FOREIGN KEY (brand_id) REFERENCES brands(id)
);

CREATE TABLE IF NOT EXISTS user_vouchers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    voucher_id INT NOT NULL,
    status ENUM('AVAILABLE', 'USED', 'EXPIRED') NOT NULL DEFAULT 'AVAILABLE',
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    used_at TIMESTAMP NULL,
    CONSTRAINT fk_user_vouchers_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_user_vouchers_voucher FOREIGN KEY (voucher_id) REFERENCES vouchers(id),
    UNIQUE KEY ux_user_voucher (user_id, voucher_id)
);

CREATE TABLE IF NOT EXISTS loyalty_checkins (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    checkin_date DATE NOT NULL,
    points_awarded INT NOT NULL,
    streak_count INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_loyalty_checkins_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_loyalty_checkins_country FOREIGN KEY (country_id) REFERENCES countries(id),
    UNIQUE KEY ux_user_daily_checkin (user_id, checkin_date)
);

-- ==========================================
-- 4. ORDERING & CHECKOUT
-- ==========================================

CREATE TABLE IF NOT EXISTS order_intents (
    tracking_id VARCHAR(64) PRIMARY KEY,
    trace_id VARCHAR(64) NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    user_id VARCHAR(64) NOT NULL,
    store_id INT NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    fulfillment_type ENUM('DINE_IN', 'TAKEAWAY', 'DELIVERY') NOT NULL,
    status ENUM('PAYMENT_PENDING', 'QUEUED', 'PROCESSING', 'COMPLETED', 'FAILED', 'PAYMENT_FAILED') NOT NULL DEFAULT 'PAYMENT_PENDING',
    subtotal INT NOT NULL,
    tax_amount INT NOT NULL,
    discount_amount INT NOT NULL DEFAULT 0,
    total_amount INT NOT NULL,
    voucher_code VARCHAR(50),
    cart_payload JSON NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_order_intents_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_order_intents_store FOREIGN KEY (store_id) REFERENCES stores(id),
    CONSTRAINT fk_order_intents_country FOREIGN KEY (country_id) REFERENCES countries(id),
    UNIQUE KEY ux_order_intents_idempotency (country_id, user_id, idempotency_key)
);

-- ==========================================
-- 5. PAYMENTS
-- ==========================================

CREATE TABLE IF NOT EXISTS payment_providers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    provider_type ENUM('CARD_PROCESSOR', 'EWALLET', 'BANK_TRANSFER', 'QR_PAYMENT', 'CASH') NOT NULL,
    callback_url VARCHAR(255) NOT NULL,
    is_mock BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    config JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS payment_methods (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL,
    provider_code VARCHAR(50) NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    brand_id INT,
    display_name VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    currency_code VARCHAR(3) NOT NULL,
    min_amount INT NOT NULL DEFAULT 0,
    max_amount INT,
    display_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payment_methods_provider FOREIGN KEY (provider_code) REFERENCES payment_providers(code),
    CONSTRAINT fk_payment_methods_country FOREIGN KEY (country_id) REFERENCES countries(id),
    CONSTRAINT fk_payment_methods_brand FOREIGN KEY (brand_id) REFERENCES brands(id),
    UNIQUE KEY ux_payment_methods_scope (code, provider_code, country_id, brand_id)
);

CREATE TABLE IF NOT EXISTS payment_transactions (
    id VARCHAR(64) PRIMARY KEY,
    order_tracking_id VARCHAR(64) NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    user_id VARCHAR(64) NOT NULL,
    provider VARCHAR(50) NOT NULL,
    payment_method_code VARCHAR(50),
    provider_reference VARCHAR(128),
    status ENUM('PENDING', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'CANCELLED') NOT NULL DEFAULT 'PENDING',
    currency_code VARCHAR(3) NOT NULL,
    amount INT NOT NULL,
    gateway_payload JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_payment_transactions_order FOREIGN KEY (order_tracking_id) REFERENCES order_intents(tracking_id),
    CONSTRAINT fk_payment_transactions_country FOREIGN KEY (country_id) REFERENCES countries(id),
    CONSTRAINT fk_payment_transactions_user FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE KEY ux_payment_transactions_provider_ref (provider, provider_reference),
    UNIQUE KEY ux_payment_transactions_order (order_tracking_id)
);

CREATE TABLE IF NOT EXISTS payment_events (
    id INT AUTO_INCREMENT PRIMARY KEY,
    payment_transaction_id VARCHAR(64) NOT NULL,
    provider VARCHAR(50) NOT NULL,
    gateway_event_id VARCHAR(128) NOT NULL,
    event_type VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL,
    payload JSON NOT NULL,
    received_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payment_events_transaction FOREIGN KEY (payment_transaction_id) REFERENCES payment_transactions(id),
    UNIQUE KEY ux_payment_events_provider_event (provider, gateway_event_id)
);

-- ==========================================
-- 6. CAMPAIGNS
-- ==========================================

CREATE TABLE IF NOT EXISTS campaigns (
    id INT AUTO_INCREMENT PRIMARY KEY,
    country_id VARCHAR(2) NOT NULL,
    brand_id INT,
    campaign_type ENUM('BANNER', 'DAILY_CHECKIN', 'MINI_GAME', 'FLASH_SALE', 'SOCIAL_FEED') NOT NULL,
    title_translations JSON NOT NULL,
    subtitle_translations JSON,
    image_url VARCHAR(255),
    deep_link VARCHAR(255),
    webview_url VARCHAR(255),
    priority INT NOT NULL DEFAULT 0,
    starts_at TIMESTAMP NOT NULL,
    ends_at TIMESTAMP NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_campaigns_country FOREIGN KEY (country_id) REFERENCES countries(id),
    CONSTRAINT fk_campaigns_brand FOREIGN KEY (brand_id) REFERENCES brands(id)
);
