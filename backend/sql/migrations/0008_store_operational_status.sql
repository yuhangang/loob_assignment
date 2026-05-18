ALTER TABLE stores
    ADD COLUMN operational_status ENUM('OPEN', 'CLOSED', 'TEMPORARILY_CLOSED', 'COMING_SOON') NOT NULL DEFAULT 'OPEN' AFTER timezone,
    ADD COLUMN status_message VARCHAR(255) NULL AFTER operational_status;

UPDATE stores
SET operational_status = 'OPEN'
WHERE operational_status = '';
