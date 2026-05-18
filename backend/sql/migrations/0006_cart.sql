-- Cart items table for server-side cart persistence.
-- Each row represents one customized line-item in a user's active cart.
-- Uniqueness is enforced at the application layer (upsert by matching all fields).

CREATE TABLE IF NOT EXISTS cart_items (
    id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id            VARCHAR(64)     NOT NULL,
    country_id         VARCHAR(2)      NOT NULL,
    store_id           INT             NOT NULL,
    menu_item_id       INT             NOT NULL,
    quantity           INT             NOT NULL DEFAULT 1,
    customization_ids  JSON            NOT NULL,
    created_at         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_cart_user (user_id, country_id),
    INDEX idx_cart_store (store_id),
    INDEX idx_cart_menu_item (menu_item_id),
    CONSTRAINT fk_cart_items_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_cart_items_country FOREIGN KEY (country_id) REFERENCES countries(id),
    CONSTRAINT fk_cart_items_store FOREIGN KEY (store_id) REFERENCES stores(id),
    CONSTRAINT fk_cart_items_menu_item FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
