CREATE TABLE IF NOT EXISTS cart_item_customization_options (
    cart_item_id BIGINT UNSIGNED NOT NULL,
    customization_option_id INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (cart_item_id, customization_option_id),
    CONSTRAINT fk_cart_item_customization_options_cart_item
        FOREIGN KEY (cart_item_id) REFERENCES cart_items(id) ON DELETE CASCADE,
    CONSTRAINT fk_cart_item_customization_options_option
        FOREIGN KEY (customization_option_id) REFERENCES customization_options(id)
);

INSERT IGNORE INTO cart_item_customization_options (cart_item_id, customization_option_id)
SELECT ci.id, jt.option_id
FROM cart_items ci
JOIN JSON_TABLE(
    ci.customization_ids,
    '$[*]' COLUMNS (option_id INT PATH '$')
) AS jt
JOIN customization_options co ON co.id = jt.option_id;
