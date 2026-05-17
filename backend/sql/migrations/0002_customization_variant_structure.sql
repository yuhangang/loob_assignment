SET @schema_name = DATABASE();

SET @has_group_code = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'customization_groups'
      AND column_name = 'group_code'
);
SET @sql = IF(
    @has_group_code = 0,
    'ALTER TABLE customization_groups ADD COLUMN group_code VARCHAR(50) NOT NULL DEFAULT '''' AFTER menu_item_id',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_min_selections = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'customization_groups'
      AND column_name = 'min_selections'
);
SET @sql = IF(
    @has_min_selections = 0,
    'ALTER TABLE customization_groups ADD COLUMN min_selections INT NOT NULL DEFAULT 0 AFTER selection_type',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_group_metadata = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'customization_groups'
      AND column_name = 'metadata'
);
SET @sql = IF(
    @has_group_metadata = 0,
    'ALTER TABLE customization_groups ADD COLUMN metadata JSON NULL AFTER display_order',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_option_code = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'customization_options'
      AND column_name = 'option_code'
);
SET @sql = IF(
    @has_option_code = 0,
    'ALTER TABLE customization_options ADD COLUMN option_code VARCHAR(50) NOT NULL DEFAULT '''' AFTER group_id',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_option_display_order = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'customization_options'
      AND column_name = 'display_order'
);
SET @sql = IF(
    @has_option_display_order = 0,
    'ALTER TABLE customization_options ADD COLUMN display_order INT NOT NULL DEFAULT 0 AFTER is_default',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_option_metadata = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'customization_options'
      AND column_name = 'metadata'
);
SET @sql = IF(
    @has_option_metadata = 0,
    'ALTER TABLE customization_options ADD COLUMN metadata JSON NULL AFTER display_order',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE customization_groups
SET group_code = CONCAT('group_', id)
WHERE group_code = '';

UPDATE customization_groups
SET min_selections = CASE
    WHEN is_required = true THEN 1
    ELSE 0
END
WHERE min_selections = 0;

UPDATE customization_options
SET option_code = CONCAT('option_', id)
WHERE option_code = '';

UPDATE customization_options
SET display_order = id
WHERE display_order = 0;

SET @has_group_code_index = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'customization_groups'
      AND index_name = 'ux_customization_group_code'
);
SET @sql = IF(
    @has_group_code_index = 0,
    'ALTER TABLE customization_groups ADD UNIQUE KEY ux_customization_group_code (menu_item_id, group_code)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_option_code_index = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'customization_options'
      AND index_name = 'ux_customization_option_code'
);
SET @sql = IF(
    @has_option_code_index = 0,
    'ALTER TABLE customization_options ADD UNIQUE KEY ux_customization_option_code (group_id, option_code)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
