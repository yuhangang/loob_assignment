SET @schema_name = DATABASE();

SET @has_users_display_name = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'users'
      AND column_name = 'display_name'
);
SET @sql = IF(
    @has_users_display_name = 0,
    'ALTER TABLE users ADD COLUMN display_name VARCHAR(120) NULL AFTER id',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_users_avatar_url = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'users'
      AND column_name = 'avatar_url'
);
SET @sql = IF(
    @has_users_avatar_url = 0,
    'ALTER TABLE users ADD COLUMN avatar_url VARCHAR(255) NULL AFTER phone_number',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_users_marketing_opt_in = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'users'
      AND column_name = 'marketing_opt_in'
);
SET @sql = IF(
    @has_users_marketing_opt_in = 0,
    'ALTER TABLE users ADD COLUMN marketing_opt_in BOOLEAN NOT NULL DEFAULT false AFTER preferred_language',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_users_updated_at = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = @schema_name
      AND table_name = 'users'
      AND column_name = 'updated_at'
);
SET @sql = IF(
    @has_users_updated_at = 0,
    'ALTER TABLE users ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS wallet_accounts (
    user_id VARCHAR(64) NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    balance INT NOT NULL DEFAULT 0,
    currency_code VARCHAR(3) NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, country_id),
    CONSTRAINT fk_wallet_accounts_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_wallet_accounts_country FOREIGN KEY (country_id) REFERENCES countries(id)
);

CREATE TABLE IF NOT EXISTS loyalty_accounts (
    user_id VARCHAR(64) NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    points INT NOT NULL DEFAULT 0,
    lifetime_points INT NOT NULL DEFAULT 0,
    tier ENUM('MEMBER', 'SILVER', 'GOLD') NOT NULL DEFAULT 'MEMBER',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, country_id),
    CONSTRAINT fk_loyalty_accounts_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_loyalty_accounts_country FOREIGN KEY (country_id) REFERENCES countries(id)
);
