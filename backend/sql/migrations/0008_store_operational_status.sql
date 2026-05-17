ALTER TABLE stores
    ADD COLUMN operational_status VARCHAR(32) NOT NULL DEFAULT 'OPEN' AFTER timezone,
    ADD COLUMN status_message VARCHAR(255) NULL AFTER operational_status;

UPDATE stores
SET operational_status = 'OPEN'
WHERE operational_status = '';
