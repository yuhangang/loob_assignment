SET @schema_name = DATABASE();

SET @has_voucher_stacking_group = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'vouchers'
      AND column_name = 'stacking_group'
);
SET @sql = IF(
    @has_voucher_stacking_group = 0,
    'ALTER TABLE vouchers
        ADD COLUMN stacking_group VARCHAR(32) NOT NULL DEFAULT ''CART_DISCOUNT'' AFTER allow_promo_items,
        ADD COLUMN stacking_priority INT NOT NULL DEFAULT 100 AFTER stacking_group,
        ADD COLUMN exclusive BOOLEAN NOT NULL DEFAULT false AFTER stacking_priority,
        ADD COLUMN combinable_with_groups JSON NULL AFTER exclusive',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE vouchers
SET stacking_group = voucher_type
WHERE stacking_group = 'CART_DISCOUNT'
  AND voucher_type IS NOT NULL;

CREATE TABLE IF NOT EXISTS order_intent_vouchers (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_tracking_id VARCHAR(64) NOT NULL,
    voucher_id INT NOT NULL,
    voucher_code VARCHAR(50) NOT NULL,
    stacking_group VARCHAR(32) NOT NULL,
    stacking_priority INT NOT NULL DEFAULT 100,
    eligible_subtotal INT NOT NULL DEFAULT 0,
    discount_amount INT NOT NULL DEFAULT 0,
    applied_order INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY ux_order_intent_voucher (order_tracking_id, voucher_id),
    INDEX idx_order_intent_vouchers_voucher (voucher_id, order_tracking_id),
    CONSTRAINT fk_order_intent_vouchers_order FOREIGN KEY (order_tracking_id) REFERENCES order_intents(tracking_id),
    CONSTRAINT fk_order_intent_vouchers_voucher FOREIGN KEY (voucher_id) REFERENCES vouchers(id)
);

INSERT IGNORE INTO order_intent_vouchers (
    order_tracking_id, voucher_id, voucher_code, stacking_group, stacking_priority,
    eligible_subtotal, discount_amount, applied_order
)
SELECT oi.tracking_id, v.id, v.code, COALESCE(v.stacking_group, v.voucher_type), COALESCE(v.stacking_priority, 100),
       oi.subtotal, oi.discount_amount, 1
FROM order_intents oi
INNER JOIN vouchers v ON v.country_id = oi.country_id AND v.code = oi.voucher_code
WHERE oi.voucher_code IS NOT NULL
  AND oi.voucher_code <> '';
