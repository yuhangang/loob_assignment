SET @schema_name = DATABASE();

SET @has_payment_order_fk = (
    SELECT COUNT(*)
    FROM information_schema.table_constraints
    WHERE constraint_schema = @schema_name
      AND table_name = 'payment_transactions'
      AND constraint_name = 'fk_payment_transactions_order'
      AND constraint_type = 'FOREIGN KEY'
);
SET @sql = IF(
    @has_payment_order_fk = 1,
    'ALTER TABLE payment_transactions DROP FOREIGN KEY fk_payment_transactions_order',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @payment_order_nullable = (
    SELECT IS_NULLABLE
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'payment_transactions'
      AND column_name = 'order_tracking_id'
);
SET @sql = IF(
    @payment_order_nullable = 'NO',
    'ALTER TABLE payment_transactions MODIFY COLUMN order_tracking_id VARCHAR(64) NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_payment_order_fk = (
    SELECT COUNT(*)
    FROM information_schema.table_constraints
    WHERE constraint_schema = @schema_name
      AND table_name = 'payment_transactions'
      AND constraint_name = 'fk_payment_transactions_order'
      AND constraint_type = 'FOREIGN KEY'
);
SET @sql = IF(
    @has_payment_order_fk = 0,
    'ALTER TABLE payment_transactions ADD CONSTRAINT fk_payment_transactions_order FOREIGN KEY (order_tracking_id) REFERENCES order_intents(tracking_id) ON DELETE SET NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
