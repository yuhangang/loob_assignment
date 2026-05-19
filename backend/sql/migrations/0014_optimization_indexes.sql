SET @schema_name = DATABASE();

-- 1. Index on order_intents (country_id, voucher_code, status) to optimize voucher validation/redemptions subqueries
SET @has_voucher_idx = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'order_intents'
      AND index_name = 'idx_order_intents_voucher'
);
SET @sql = IF(
    @has_voucher_idx = 0,
    'CREATE INDEX idx_order_intents_voucher ON order_intents (country_id, voucher_code, status)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 2. Index on order_intents (status, created_at, tracking_id) to optimize global ClaimQueued scans
SET @has_queue_idx = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'order_intents'
      AND index_name = 'idx_order_intents_queue'
);
SET @sql = IF(
    @has_queue_idx = 0,
    'CREATE INDEX idx_order_intents_queue ON order_intents (status, created_at, tracking_id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 3. Index on order_intents (country_id, user_id, created_at DESC) to optimize order history listing without filesorts
SET @has_history_idx = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = @schema_name
      AND table_name = 'order_intents'
      AND index_name = 'idx_order_intents_user_history'
);
SET @sql = IF(
    @has_history_idx = 0,
    'CREATE INDEX idx_order_intents_user_history ON order_intents (country_id, user_id, created_at DESC)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
