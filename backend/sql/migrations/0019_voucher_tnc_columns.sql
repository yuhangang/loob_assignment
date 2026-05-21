SET @schema_name = DATABASE();

SET @has_voucher_tnc = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'vouchers'
      AND column_name = 'terms_and_conditions_markdown'
);
SET @sql = IF(
    @has_voucher_tnc = 0,
    'ALTER TABLE vouchers
        ADD COLUMN terms_and_conditions_markdown TEXT NULL,
        ADD COLUMN terms_and_conditions_html TEXT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
