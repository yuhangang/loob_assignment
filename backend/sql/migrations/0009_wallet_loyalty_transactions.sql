CREATE TABLE IF NOT EXISTS wallet_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    transaction_type ENUM('TOPUP', 'SPEND', 'REFUND', 'ADJUSTMENT') NOT NULL,
    amount INT NOT NULL,
    balance_after INT NOT NULL,
    currency_code VARCHAR(3) NOT NULL,
    reference_type VARCHAR(32),
    reference_id VARCHAR(64),
    description VARCHAR(255),
    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_wallet_transactions_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_wallet_transactions_country FOREIGN KEY (country_id) REFERENCES countries(id),
    KEY idx_wallet_transactions_user_country_created (user_id, country_id, created_at),
    UNIQUE KEY ux_wallet_transactions_reference (user_id, country_id, transaction_type, reference_type, reference_id)
);

CREATE TABLE IF NOT EXISTS loyalty_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    country_id VARCHAR(2) NOT NULL,
    transaction_type ENUM('EARN', 'REDEEM', 'EXPIRE', 'ADJUSTMENT') NOT NULL,
    points_delta INT NOT NULL,
    balance_after INT NOT NULL,
    reference_type VARCHAR(32),
    reference_id VARCHAR(64),
    description VARCHAR(255),
    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_loyalty_transactions_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_loyalty_transactions_country FOREIGN KEY (country_id) REFERENCES countries(id),
    KEY idx_loyalty_transactions_user_country_created (user_id, country_id, created_at),
    UNIQUE KEY ux_loyalty_transactions_reference (user_id, country_id, transaction_type, reference_type, reference_id)
);
