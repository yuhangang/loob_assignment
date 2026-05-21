SET @schema_name = DATABASE();

SET @has_stores_operational_status = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'stores'
      AND column_name = 'operational_status'
);
SET @sql = IF(
    @has_stores_operational_status = 0,
    'ALTER TABLE stores ADD COLUMN operational_status ENUM(''OPEN'', ''CLOSED'', ''TEMPORARILY_CLOSED'', ''COMING_SOON'') NOT NULL DEFAULT ''OPEN'' AFTER timezone',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_stores_status_message = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'stores'
      AND column_name = 'status_message'
);
SET @sql = IF(
    @has_stores_status_message = 0,
    'ALTER TABLE stores ADD COLUMN status_message VARCHAR(255) NULL AFTER operational_status',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE stores
SET operational_status = 'OPEN'
WHERE operational_status = '';
