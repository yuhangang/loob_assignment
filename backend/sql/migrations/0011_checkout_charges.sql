CREATE TABLE IF NOT EXISTS checkout_charge_definitions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(64) NOT NULL,
    name VARCHAR(100) NOT NULL,
    country_id VARCHAR(2) NULL,
    zone_id VARCHAR(50) NULL,
    brand_id INT NULL,
    fulfillment_type ENUM('DINE_IN', 'TAKEAWAY', 'DELIVERY') NULL,
    scope ENUM('ITEM', 'ORDER', 'FULFILLMENT') NOT NULL,
    calculation_type ENUM('FIXED_AMOUNT') NOT NULL DEFAULT 'FIXED_AMOUNT',
    amount INT NOT NULL,
    taxable BOOLEAN NOT NULL DEFAULT false,
    tax_inclusive BOOLEAN NOT NULL DEFAULT false,
    waiver_min_subtotal INT NULL,
    waiver_reason VARCHAR(100) NULL,
    display_order INT NOT NULL DEFAULT 0,
    starts_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_checkout_charges_country FOREIGN KEY (country_id) REFERENCES countries(id),
    CONSTRAINT fk_checkout_charges_zone FOREIGN KEY (zone_id) REFERENCES zones(id),
    CONSTRAINT fk_checkout_charges_brand FOREIGN KEY (brand_id) REFERENCES brands(id),
    INDEX idx_checkout_charges_scope (country_id, zone_id, brand_id, fulfillment_type, code, is_active)
);

SET @schema_name = DATABASE();

SET @has_order_charges_payload = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'order_intents'
      AND column_name = 'charges_payload'
);
SET @sql = IF(
    @has_order_charges_payload = 0,
    'ALTER TABLE order_intents ADD COLUMN charges_payload JSON NULL AFTER subtotal',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

INSERT INTO checkout_charge_definitions (
    code, name, country_id, zone_id, brand_id, fulfillment_type, scope,
    calculation_type, amount, taxable, tax_inclusive, display_order
)
SELECT 'PACKAGING_FEE', 'Packaging fee', NULL, NULL, NULL, NULL, 'ORDER',
       'FIXED_AMOUNT', 100, true, false, 10
WHERE NOT EXISTS (
    SELECT 1
    FROM checkout_charge_definitions
    WHERE code = 'PACKAGING_FEE'
      AND country_id IS NULL
      AND zone_id IS NULL
      AND brand_id IS NULL
      AND fulfillment_type IS NULL
);
