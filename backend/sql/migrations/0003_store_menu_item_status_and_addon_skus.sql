SET @schema_name = DATABASE();

SET @has_menu_item_brand = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'menu_items'
      AND column_name = 'brand_id'
);
SET @sql = IF(
    @has_menu_item_brand = 0,
    'ALTER TABLE menu_items ADD COLUMN brand_id INT NULL AFTER category_id',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE menu_items mi
INNER JOIN categories c ON c.id = mi.category_id
SET mi.brand_id = c.brand_id
WHERE mi.brand_id IS NULL;

SET @has_menu_item_brand_fk = (
    SELECT COUNT(*)
    FROM information_schema.key_column_usage
    WHERE table_schema = @schema_name
      AND table_name = 'menu_items'
      AND constraint_name = 'fk_menu_items_brand'
);
SET @sql = IF(
    @has_menu_item_brand_fk = 0,
    'ALTER TABLE menu_items ADD CONSTRAINT fk_menu_items_brand FOREIGN KEY (brand_id) REFERENCES brands(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_item_type = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'menu_items'
      AND column_name = 'item_type'
);
SET @sql = IF(
    @has_item_type = 0,
    'ALTER TABLE menu_items ADD COLUMN item_type ENUM(''MAIN'', ''ADDON'') NOT NULL DEFAULT ''MAIN'' AFTER brand_id',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @category_is_nullable = (
    SELECT CASE WHEN is_nullable = 'YES' THEN 1 ELSE 0 END
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'menu_items'
      AND column_name = 'category_id'
);
SET @sql = IF(
    @category_is_nullable = 0,
    'ALTER TABLE menu_items MODIFY COLUMN category_id INT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_linked_item = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'customization_options'
      AND column_name = 'linked_menu_item_id'
);
SET @sql = IF(
    @has_linked_item = 0,
    'ALTER TABLE customization_options ADD COLUMN linked_menu_item_id INT NULL AFTER option_code',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_linked_item_fk = (
    SELECT COUNT(*)
    FROM information_schema.key_column_usage
    WHERE table_schema = @schema_name
      AND table_name = 'customization_options'
      AND constraint_name = 'fk_customization_options_linked_item'
);
SET @sql = IF(
    @has_linked_item_fk = 0,
    'ALTER TABLE customization_options ADD CONSTRAINT fk_customization_options_linked_item FOREIGN KEY (linked_menu_item_id) REFERENCES menu_items(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_store_menu_item_status = (
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = @schema_name
      AND table_name = 'store_menu_item_status'
);
SET @sql = IF(
    @has_store_menu_item_status = 0,
    'CREATE TABLE store_menu_item_status (
        store_id INT NOT NULL,
        menu_item_id INT NOT NULL,
        is_listed BOOLEAN NOT NULL DEFAULT true,
        is_available BOOLEAN NOT NULL DEFAULT true,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (store_id, menu_item_id),
        CONSTRAINT fk_store_menu_item_status_store FOREIGN KEY (store_id) REFERENCES stores(id),
        CONSTRAINT fk_store_menu_item_status_item FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
    )',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_item_type_index = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'menu_items'
      AND index_name = 'idx_menu_items_brand_type'
);
SET @sql = IF(
    @has_item_type_index = 0,
    'CREATE INDEX idx_menu_items_brand_type ON menu_items (brand_id, item_type)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
