package cart

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
)

// Repository handles all cart_items database access.
type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// GetCart returns all cart items for the given user in the given country,
// enriched with the current product name, image, base price, and availability
// from menu_items and store_menu_item_status.
//
// When overrideStoreID > 0 the availability and pricing joins use that store
// instead of each row's persisted ci.store_id.
func (r *Repository) GetCart(ctx context.Context, userID, countryID string, overrideStoreID int) ([]CartItem, error) {
	// Build the store reference for availability / pricing evaluation.
	// If an override is supplied we use it; otherwise fall back to the row's own store_id.
	storeRef := "ci.store_id"
	args := []any{userID, countryID}
	if overrideStoreID > 0 {
		storeRef = "?"
		// We need 3 placeholders (pricing zone lookup, smis store, smis store).
		// We'll inject them via fmt.Sprintf and prepend to the WHERE args.
	}

	query := fmt.Sprintf(`
		SELECT
			ci.id, ci.user_id, ci.country_id, ci.store_id, ci.menu_item_id,
			ci.quantity, ci.customization_ids,
			COALESCE(mi.name_translations->>'$.en', mi.sku_code, '') AS name,
			COALESCE(mi.image_url_sm, '')                           AS image_url_sm,
			COALESCE(mip.base_price, 0)                             AS base_price,
			(
				mi.is_active = true
				AND mi.deleted_at IS NULL
				AND COALESCE(smis.is_listed, true)    = true
				AND COALESCE(smis.is_available, true) = true
			) AS is_available
		FROM cart_items ci
		LEFT JOIN menu_items mi    ON mi.id = ci.menu_item_id
		LEFT JOIN stores s         ON s.id  = %[1]s
		LEFT JOIN menu_item_pricing mip
			ON  mip.menu_item_id = ci.menu_item_id
			AND mip.zone_id      = COALESCE(s.zone_id, '')
		LEFT JOIN store_menu_item_status smis
			ON  smis.store_id     = %[1]s
			AND smis.menu_item_id = ci.menu_item_id
		WHERE ci.user_id = ? AND ci.country_id = ?
		ORDER BY ci.created_at ASC
	`, storeRef)

	// When using an override we need to supply the store_id twice (stores join + smis join)
	// before the WHERE params.
	if overrideStoreID > 0 {
		args = []any{overrideStoreID, overrideStoreID, userID, countryID}
	}

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []CartItem
	for rows.Next() {
		var item CartItem
		var rawIDs []byte
		if err := rows.Scan(
			&item.ID, &item.UserID, &item.CountryID, &item.StoreID,
			&item.MenuItemID, &item.Quantity, &rawIDs,
			&item.Name, &item.ImageURLSm, &item.BasePrice, &item.IsAvailable,
		); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(rawIDs, &item.CustomizationIDs); err != nil {
			item.CustomizationIDs = []int{}
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	for i := range items {
		evalStoreID := items[i].StoreID
		if overrideStoreID > 0 {
			evalStoreID = overrideStoreID
		}
		options, err := r.getSelectedOptions(ctx, evalStoreID, items[i].CustomizationIDs)
		if err != nil {
			return nil, err
		}
		items[i].Options = options
	}
	return items, nil
}

// UpsertCartItem inserts a new cart item or updates its quantity if an identical
// one already exists (same user + country + store + menu_item + customizations).
func (r *Repository) UpsertCartItem(ctx context.Context, item CartItem) (CartItem, error) {
	customizationJSON, err := json.Marshal(item.CustomizationIDs)
	if err != nil {
		return CartItem{}, err
	}

	// Try to find an existing row with the same key fields.
	// We match on the JSON text representation which works for sorted IDs.
	var existingID int64
	err = r.db.QueryRowContext(ctx, `
		SELECT id FROM cart_items
		WHERE user_id = ? AND country_id = ? AND store_id = ? AND menu_item_id = ?
		  AND JSON_CONTAINS(customization_ids, ?) AND JSON_CONTAINS(?, customization_ids)
		LIMIT 1
	`, item.UserID, item.CountryID, item.StoreID, item.MenuItemID,
		string(customizationJSON), string(customizationJSON),
	).Scan(&existingID)

	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return CartItem{}, err
	}

	if existingID > 0 {
		// Update existing item's quantity.
		_, err = r.db.ExecContext(ctx, `
			UPDATE cart_items SET quantity = ?, updated_at = NOW()
			WHERE id = ?
		`, item.Quantity, existingID)
		if err != nil {
			return CartItem{}, err
		}
		item.ID = existingID
	} else {
		// Insert new item.
		res, err := r.db.ExecContext(ctx, `
			INSERT INTO cart_items (user_id, country_id, store_id, menu_item_id, quantity, customization_ids)
			VALUES (?, ?, ?, ?, ?, CAST(? AS JSON))
		`, item.UserID, item.CountryID, item.StoreID, item.MenuItemID, item.Quantity, string(customizationJSON))
		if err != nil {
			return CartItem{}, err
		}
		id, err := res.LastInsertId()
		if err != nil {
			return CartItem{}, err
		}
		item.ID = id
	}
	return item, nil
}

// UpdateCartItem replaces an existing item and merges with an identical row.
func (r *Repository) UpdateCartItem(ctx context.Context, itemID int64, item CartItem) (CartItem, error) {
	customizationJSON, err := json.Marshal(item.CustomizationIDs)
	if err != nil {
		return CartItem{}, err
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return CartItem{}, err
	}
	defer tx.Rollback()

	var existingID int64
	err = tx.QueryRowContext(ctx, `
		SELECT id
		FROM cart_items
		WHERE id = ? AND user_id = ? AND country_id = ?
	`, itemID, item.UserID, item.CountryID).Scan(&existingID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return CartItem{}, ErrNotFound
		}
		return CartItem{}, err
	}

	var duplicateID int64
	err = tx.QueryRowContext(ctx, `
		SELECT id FROM cart_items
		WHERE id <> ? AND user_id = ? AND country_id = ? AND store_id = ? AND menu_item_id = ?
		  AND JSON_CONTAINS(customization_ids, ?) AND JSON_CONTAINS(?, customization_ids)
		LIMIT 1
	`, itemID, item.UserID, item.CountryID, item.StoreID, item.MenuItemID,
		string(customizationJSON), string(customizationJSON),
	).Scan(&duplicateID)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return CartItem{}, err
	}

	if duplicateID > 0 {
		if _, err := tx.ExecContext(ctx, `
			UPDATE cart_items SET quantity = ?, updated_at = NOW()
			WHERE id = ?
		`, item.Quantity, duplicateID); err != nil {
			return CartItem{}, err
		}
		if _, err := tx.ExecContext(ctx, `
			DELETE FROM cart_items
			WHERE id = ?
		`, itemID); err != nil {
			return CartItem{}, err
		}
		item.ID = duplicateID
	} else {
		if _, err := tx.ExecContext(ctx, `
			UPDATE cart_items
			SET store_id = ?, menu_item_id = ?, quantity = ?, customization_ids = CAST(? AS JSON), updated_at = NOW()
			WHERE id = ? AND user_id = ? AND country_id = ?
		`, item.StoreID, item.MenuItemID, item.Quantity, string(customizationJSON), itemID, item.UserID, item.CountryID); err != nil {
			return CartItem{}, err
		}
		item.ID = itemID
	}

	if err := tx.Commit(); err != nil {
		return CartItem{}, err
	}
	return item, nil
}

// RemoveCartItem deletes a single cart item by its ID, scoped to user + country.
func (r *Repository) RemoveCartItem(ctx context.Context, itemID int64, userID, countryID string) error {
	res, err := r.db.ExecContext(ctx, `
		DELETE FROM cart_items
		WHERE id = ? AND user_id = ? AND country_id = ?
	`, itemID, userID, countryID)
	if err != nil {
		return err
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

// ClearCart removes all cart items for the given user in the given country.
func (r *Repository) ClearCart(ctx context.Context, userID, countryID string) error {
	_, err := r.db.ExecContext(ctx, `
		DELETE FROM cart_items
		WHERE user_id = ? AND country_id = ?
	`, userID, countryID)
	return err
}

func (r *Repository) getSelectedOptions(ctx context.Context, storeID int, optionIDs []int) ([]CartItemOption, error) {
	if len(optionIDs) == 0 {
		return []CartItemOption{}, nil
	}

	query, args := inQuery(`
		SELECT co.id, co.group_id, co.option_code, co.name_translations,
		       co.price_adjustment + COALESCE(mip.base_price, 0) AS effective_price_adjustment,
		       CASE
		           WHEN co.linked_menu_item_id IS NULL THEN true
		           WHEN linked.id IS NULL THEN false
		           ELSE COALESCE(smis.is_listed, true) AND COALESCE(smis.is_available, true)
		       END AS is_available
		FROM customization_options co
		LEFT JOIN stores s ON s.id = ?
		LEFT JOIN menu_items linked ON linked.id = co.linked_menu_item_id
		     AND linked.is_active = true
		     AND linked.deleted_at IS NULL
		     AND linked.item_type = 'ADDON'
		LEFT JOIN menu_item_pricing mip ON mip.menu_item_id = co.linked_menu_item_id AND mip.zone_id = s.zone_id
		LEFT JOIN store_menu_item_status smis ON smis.store_id = ? AND smis.menu_item_id = co.linked_menu_item_id
		WHERE co.id IN (%s)
		ORDER BY co.group_id, co.display_order, co.id
	`, optionIDs)
	args = append([]any{storeID, storeID}, args...)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	options := make([]CartItemOption, 0, len(optionIDs))
	for rows.Next() {
		var option CartItemOption
		var nameJSON []byte
		if err := rows.Scan(&option.ID, &option.GroupID, &option.Code, &nameJSON, &option.PriceAdjustment, &option.IsAvailable); err != nil {
			return nil, err
		}
		option.Name = localizedName(nameJSON)
		options = append(options, option)
	}
	return options, rows.Err()
}

func localizedName(raw []byte) string {
	names := decodeStringMap(raw)
	for _, key := range []string{"en-US", "en", "ms-MY", "th-TH"} {
		if value := strings.TrimSpace(names[key]); value != "" {
			return value
		}
	}
	for _, value := range names {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func decodeStringMap(raw []byte) map[string]string {
	if len(raw) == 0 {
		return map[string]string{}
	}
	var out map[string]string
	if err := json.Unmarshal(raw, &out); err != nil {
		return map[string]string{}
	}
	return out
}

func inQuery(format string, ids []int) (string, []any) {
	placeholders := make([]string, len(ids))
	args := make([]any, len(ids))
	for i, id := range ids {
		placeholders[i] = "?"
		args[i] = id
	}
	return fmt.Sprintf(format, strings.Join(placeholders, ",")), args
}
