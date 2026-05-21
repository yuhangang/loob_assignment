-- Migration to add icon_url to categories table
SET @schema_name = DATABASE();

SET @has_categories_icon_url = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'categories'
      AND column_name = 'icon_url'
);
SET @sql = IF(
    @has_categories_icon_url = 0,
    'ALTER TABLE categories ADD COLUMN icon_url VARCHAR(255) NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
