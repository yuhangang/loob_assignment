SET @schema_name = DATABASE();

SET @has_voucher_status = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'vouchers'
      AND column_name = 'voided_at'
);
SET @sql = IF(
    @has_voucher_status = 0,
    'ALTER TABLE vouchers
        ADD COLUMN voided_at TIMESTAMP NULL AFTER expires_at,
        ADD COLUMN max_redemptions INT NULL AFTER max_discount_cap,
        ADD COLUMN max_redemptions_per_user INT NULL AFTER max_redemptions,
        ADD COLUMN allow_promo_items BOOLEAN NOT NULL DEFAULT true AFTER max_redemptions_per_user,
        ADD COLUMN applicable_store_ids JSON NULL AFTER allow_promo_items,
        ADD COLUMN applicable_category_ids JSON NULL AFTER applicable_store_ids,
        ADD COLUMN applicable_item_ids JSON NULL AFTER applicable_category_ids,
        ADD COLUMN applicable_payment_methods JSON NULL AFTER applicable_item_ids',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_menu_item_promo = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'menu_items'
      AND column_name = 'is_promo'
);
SET @sql = IF(
    @has_menu_item_promo = 0,
    'ALTER TABLE menu_items ADD COLUMN is_promo BOOLEAN NOT NULL DEFAULT false AFTER item_type',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_voucher_scope_index = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'vouchers'
      AND index_name = 'idx_vouchers_country_code_active'
);
SET @sql = IF(
    @has_voucher_scope_index = 0,
    'CREATE INDEX idx_vouchers_country_code_active ON vouchers (country_id, code, is_active, starts_at, expires_at)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
