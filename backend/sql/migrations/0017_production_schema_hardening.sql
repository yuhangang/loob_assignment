SET @schema_name = DATABASE();

SET @has_voucher_redemption_count = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'vouchers'
      AND column_name = 'redemption_count'
);
SET @sql = IF(
    @has_voucher_redemption_count = 0,
    'ALTER TABLE vouchers ADD COLUMN redemption_count INT NOT NULL DEFAULT 0 AFTER max_redemptions_per_user',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS voucher_user_redemption_counters (
    voucher_id INT NOT NULL,
    user_id VARCHAR(64) NOT NULL,
    redemption_count INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (voucher_id, user_id),
    CONSTRAINT fk_voucher_user_redemption_counter_voucher FOREIGN KEY (voucher_id) REFERENCES vouchers(id),
    CONSTRAINT fk_voucher_user_redemption_counter_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS loyalty_tier_configs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    country_id VARCHAR(2) NOT NULL,
    brand_id INT NULL,
    tier_code VARCHAR(32) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    min_lifetime_points INT NOT NULL,
    benefits JSON NULL,
    display_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_loyalty_tier_configs_country FOREIGN KEY (country_id) REFERENCES countries(id),
    CONSTRAINT fk_loyalty_tier_configs_brand FOREIGN KEY (brand_id) REFERENCES brands(id),
    UNIQUE KEY ux_loyalty_tier_configs_scope (country_id, brand_id, tier_code),
    INDEX idx_loyalty_tier_configs_threshold (country_id, brand_id, is_active, min_lifetime_points)
);

CREATE TABLE IF NOT EXISTS order_intent_items (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_tracking_id VARCHAR(64) NOT NULL,
    line_number INT NOT NULL,
    menu_item_id INT NOT NULL,
    sku_code VARCHAR(50) NOT NULL,
    item_name_snapshot JSON NOT NULL,
    quantity INT NOT NULL,
    unit_price INT NOT NULL,
    subtotal INT NOT NULL,
    tax_inclusive BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_order_intent_items_order FOREIGN KEY (order_tracking_id) REFERENCES order_intents(tracking_id),
    CONSTRAINT fk_order_intent_items_menu_item FOREIGN KEY (menu_item_id) REFERENCES menu_items(id),
    UNIQUE KEY ux_order_intent_items_line (order_tracking_id, line_number),
    INDEX idx_order_intent_items_menu_created (menu_item_id, created_at)
);

CREATE TABLE IF NOT EXISTS order_intent_item_options (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_intent_item_id BIGINT UNSIGNED NOT NULL,
    customization_option_id INT NOT NULL,
    option_code VARCHAR(50) NOT NULL,
    option_name_snapshot JSON NOT NULL,
    price_adjustment INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_order_intent_item_options_item FOREIGN KEY (order_intent_item_id) REFERENCES order_intent_items(id),
    CONSTRAINT fk_order_intent_item_options_option FOREIGN KEY (customization_option_id) REFERENCES customization_options(id),
    INDEX idx_order_intent_item_options_option (customization_option_id)
);

SET @has_order_active_status = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'order_intents'
      AND column_name = 'active_queue_status'
);
SET @sql = IF(
    @has_order_active_status = 0,
    'ALTER TABLE order_intents ADD COLUMN active_queue_status VARCHAR(32) GENERATED ALWAYS AS (IF(status IN (''PAYMENT_PENDING'', ''QUEUED'', ''PROCESSING'', ''READY_TO_COLLECT''), status, NULL)) STORED AFTER status',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_order_active_queue_idx = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'order_intents'
      AND index_name = 'idx_order_intents_active_queue'
);
SET @sql = IF(
    @has_order_active_queue_idx = 0,
    'CREATE INDEX idx_order_intents_active_queue ON order_intents (active_queue_status, created_at, tracking_id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS campaign_targeting_rules (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    campaign_id INT NOT NULL,
    rule_type ENUM('LOYALTY_TIER', 'NEW_USER', 'USER_SEGMENT', 'STORE', 'ZONE') NOT NULL,
    operator ENUM('IN', 'NOT_IN', 'EQUALS', 'RANGE') NOT NULL DEFAULT 'IN',
    rule_values JSON NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_campaign_targeting_rules_campaign FOREIGN KEY (campaign_id) REFERENCES campaigns(id),
    INDEX idx_campaign_targeting_rules_campaign (campaign_id, rule_type)
);
