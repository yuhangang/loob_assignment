SET @schema_name = DATABASE();

DROP TABLE IF EXISTS feature_flags;

SET @cart_user_id_len = (
    SELECT CHARACTER_MAXIMUM_LENGTH
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'cart_items'
      AND column_name = 'user_id'
);
SET @sql = IF(
    @cart_user_id_len IS NOT NULL AND @cart_user_id_len <> 64,
    'ALTER TABLE cart_items MODIFY COLUMN user_id VARCHAR(64) NOT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @cart_country_type = (
    SELECT DATA_TYPE
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'cart_items'
      AND column_name = 'country_id'
);
SET @sql = IF(
    @cart_country_type IS NOT NULL AND @cart_country_type <> 'varchar',
    'ALTER TABLE cart_items MODIFY COLUMN country_id VARCHAR(2) NOT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_cart_store_index = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'cart_items'
      AND index_name = 'idx_cart_store'
);
SET @sql = IF(
    @has_cart_store_index = 0,
    'CREATE INDEX idx_cart_store ON cart_items (store_id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_cart_menu_item_index = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'cart_items'
      AND index_name = 'idx_cart_menu_item'
);
SET @sql = IF(
    @has_cart_menu_item_index = 0,
    'CREATE INDEX idx_cart_menu_item ON cart_items (menu_item_id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_cart_user_fk = (
    SELECT COUNT(*)
    FROM information_schema.table_constraints
    WHERE constraint_schema = @schema_name
      AND table_name = 'cart_items'
      AND constraint_name = 'fk_cart_items_user'
);
SET @sql = IF(
    @has_cart_user_fk = 0,
    'ALTER TABLE cart_items ADD CONSTRAINT fk_cart_items_user FOREIGN KEY (user_id) REFERENCES users(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_cart_country_fk = (
    SELECT COUNT(*)
    FROM information_schema.table_constraints
    WHERE constraint_schema = @schema_name
      AND table_name = 'cart_items'
      AND constraint_name = 'fk_cart_items_country'
);
SET @sql = IF(
    @has_cart_country_fk = 0,
    'ALTER TABLE cart_items ADD CONSTRAINT fk_cart_items_country FOREIGN KEY (country_id) REFERENCES countries(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_cart_store_fk = (
    SELECT COUNT(*)
    FROM information_schema.table_constraints
    WHERE constraint_schema = @schema_name
      AND table_name = 'cart_items'
      AND constraint_name = 'fk_cart_items_store'
);
SET @sql = IF(
    @has_cart_store_fk = 0,
    'ALTER TABLE cart_items ADD CONSTRAINT fk_cart_items_store FOREIGN KEY (store_id) REFERENCES stores(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_cart_menu_item_fk = (
    SELECT COUNT(*)
    FROM information_schema.table_constraints
    WHERE constraint_schema = @schema_name
      AND table_name = 'cart_items'
      AND constraint_name = 'fk_cart_items_menu_item'
);
SET @sql = IF(
    @has_cart_menu_item_fk = 0,
    'ALTER TABLE cart_items ADD CONSTRAINT fk_cart_items_menu_item FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

ALTER TABLE stores
    MODIFY COLUMN operational_status ENUM('OPEN', 'CLOSED', 'TEMPORARILY_CLOSED', 'COMING_SOON') NOT NULL DEFAULT 'OPEN';

ALTER TABLE loyalty_accounts
    MODIFY COLUMN tier ENUM('MEMBER', 'SILVER', 'GOLD') NOT NULL DEFAULT 'MEMBER';

SET @has_campaigns_updated_at = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'campaigns'
      AND column_name = 'updated_at'
);
SET @sql = IF(
    @has_campaigns_updated_at = 0,
    'ALTER TABLE campaigns ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_order_user_status_index = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'order_intents'
      AND index_name = 'idx_order_intents_user_status_created'
);
SET @sql = IF(
    @has_order_user_status_index = 0,
    'CREATE INDEX idx_order_intents_user_status_created ON order_intents (country_id, user_id, status, created_at)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_charge_active_code = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'checkout_charge_definitions'
      AND column_name = 'active_code'
);
SET @sql = IF(
    @has_charge_active_code = 0,
    'ALTER TABLE checkout_charge_definitions
        ADD COLUMN active_code VARCHAR(64) GENERATED ALWAYS AS (IF(is_active, code, NULL)) STORED,
        ADD COLUMN active_country_id VARCHAR(2) GENERATED ALWAYS AS (IF(is_active, COALESCE(country_id, ''*''), NULL)) STORED,
        ADD COLUMN active_zone_id VARCHAR(50) GENERATED ALWAYS AS (IF(is_active, COALESCE(zone_id, ''*''), NULL)) STORED,
        ADD COLUMN active_brand_id INT GENERATED ALWAYS AS (IF(is_active, COALESCE(brand_id, 0), NULL)) STORED,
        ADD COLUMN active_fulfillment_type VARCHAR(16) GENERATED ALWAYS AS (IF(is_active, COALESCE(fulfillment_type, ''*''), NULL)) STORED',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_charge_active_unique = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'checkout_charge_definitions'
      AND index_name = 'ux_checkout_charge_active_scope'
);
SET @sql = IF(
    @has_charge_active_unique = 0,
    'CREATE UNIQUE INDEX ux_checkout_charge_active_scope
        ON checkout_charge_definitions (active_country_id, active_zone_id, active_brand_id, active_fulfillment_type, active_code)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
