ALTER TABLE users
    ADD COLUMN display_name VARCHAR(120) NULL AFTER id,
    ADD COLUMN avatar_url VARCHAR(255) NULL AFTER phone_number,
    ADD COLUMN marketing_opt_in BOOLEAN NOT NULL DEFAULT false AFTER preferred_language,
    ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at;

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
