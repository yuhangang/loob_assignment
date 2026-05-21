SET @schema_name = DATABASE();

SET @has_loyalty_accounts_tier = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'loyalty_accounts'
      AND column_name = 'tier'
);
SET @sql = IF(
    @has_loyalty_accounts_tier = 1,
    'ALTER TABLE loyalty_accounts MODIFY COLUMN tier VARCHAR(32) NOT NULL DEFAULT ''MEMBER''',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
