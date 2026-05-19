SET @schema_name = DATABASE();

-- 2. Index on categories to optimize displays and display orders
SET @has_cat_idx = (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = @schema_name AND table_name = 'categories' AND index_name = 'idx_categories_brand_display'
);
SET @sql = IF(@has_cat_idx = 0, 'CREATE INDEX idx_categories_brand_display ON categories (is_active, brand_id, display_order)', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 3. Indexes on menu_items to optimize catalog lists, item details, and availability status joins
SET @has_mi_idx = (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = @schema_name AND table_name = 'menu_items' AND index_name = 'idx_menu_items_catalog_list'
);
SET @sql = IF(@has_mi_idx = 0, 'CREATE INDEX idx_menu_items_catalog_list ON menu_items (is_active, deleted_at, item_type, brand_id, category_id)', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 4. Index on menu_item_pricing to optimize zone pricing lookups
SET @has_pricing_idx = (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = @schema_name AND table_name = 'menu_item_pricing' AND index_name = 'idx_mip_zone_item'
);
SET @sql = IF(@has_pricing_idx = 0, 'CREATE INDEX idx_mip_zone_item ON menu_item_pricing (zone_id, menu_item_id)', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 6. Index on customization_groups to optimize product detail customizer lookups
SET @has_groups_idx = (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = @schema_name AND table_name = 'customization_groups' AND index_name = 'idx_cg_item_display'
);
SET @sql = IF(@has_groups_idx = 0, 'CREATE INDEX idx_cg_item_display ON customization_groups (menu_item_id, display_order)', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 7. Index on customization_options to optimize option items displays
SET @has_options_idx = (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = @schema_name AND table_name = 'customization_options' AND index_name = 'idx_co_group_display'
);
SET @sql = IF(@has_options_idx = 0, 'CREATE INDEX idx_co_group_display ON customization_options (group_id, display_order)', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
