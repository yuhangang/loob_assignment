package catalog

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
)

type CatalogRepository interface {
	GetCountry(ctx context.Context, countryID string) (Country, error)
	ResolveStoreContext(ctx context.Context, countryID string, storeID int) (StoreContext, error)
	ListCategories(ctx context.Context, brandID int) ([]CategoryRow, error)
	ListProducts(ctx context.Context, zoneID string, brandID int) ([]ProductRow, error)
	ListCustomizationGroups(ctx context.Context, menuItemIDs []int) ([]GroupRow, error)
	ListCustomizationOptions(ctx context.Context, groupIDs []int) ([]OptionRow, error)
	ListBrands(ctx context.Context) ([]BrandRow, error)
	ListStores(ctx context.Context, countryID string) ([]StoreRow, error)
}

type mysqlRepository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) CatalogRepository {
	return &mysqlRepository{db: db}
}


type Country struct {
	ID              string
	CurrencyCode    string
	TaxRate         float64
	DefaultLanguage string
}

type StoreContext struct {
	StoreID int
	ZoneID  string
	BrandID int
}

type CategoryRow struct {
	ID               int
	BrandSlug        string
	NameTranslations map[string]string
	DisplayOrder     int
}

type ProductRow struct {
	ID               int
	CategoryID       int
	SKUCode          string
	NameTranslations map[string]string
	DescTranslations map[string]string
	ImageURLSmall    string
	ImageURLLarge    string
	DietaryTags      []string
	BasePrice        int
	TaxInclusive     bool
}

type GroupRow struct {
	ID               int
	MenuItemID       int
	NameTranslations map[string]string
	SelectionType    string
	IsRequired       bool
	MaxSelections    int
	DisplayOrder     int
}

type OptionRow struct {
	ID               int
	GroupID          int
	NameTranslations map[string]string
	PriceAdjustment  int
	IsDefault        bool
}

type BrandRow struct {
	ID          int
	Slug        string
	Name        string
	ThemeConfig map[string]string
}

type StoreRow struct {
	ID                  int
	BrandID             int
	CountryID           string
	ZoneID              string
	StoreCode           string
	NameTranslations    map[string]string
	Latitude            float64
	Longitude           float64
	AddressTranslations map[string]string
	IsActive            bool
}

func (r *mysqlRepository) GetCountry(ctx context.Context, countryID string) (Country, error) {
	var country Country
	err := r.db.QueryRowContext(ctx, `
		SELECT id, currency_code, tax_rate, default_language
		FROM countries
		WHERE id = ? AND is_active = true
	`, countryID).Scan(&country.ID, &country.CurrencyCode, &country.TaxRate, &country.DefaultLanguage)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Country{}, ErrNotFound
		}
		return Country{}, err
	}
	return country, nil
}

func (r *mysqlRepository) ResolveStoreContext(ctx context.Context, countryID string, storeID int) (StoreContext, error) {
	if storeID > 0 {
		var store StoreContext
		err := r.db.QueryRowContext(ctx, `
			SELECT id, zone_id, brand_id
			FROM stores
			WHERE id = ? AND country_id = ? AND is_active = true
		`, storeID, countryID).Scan(&store.StoreID, &store.ZoneID, &store.BrandID)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return StoreContext{}, ErrNotFound
			}
			return StoreContext{}, err
		}
		return store, nil
	}

	var store StoreContext
	err := r.db.QueryRowContext(ctx, `
		SELECT s.id, s.zone_id, s.brand_id
		FROM stores s
		WHERE s.country_id = ? AND s.is_active = true
		ORDER BY s.id
		LIMIT 1
	`, countryID).Scan(&store.StoreID, &store.ZoneID, &store.BrandID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return StoreContext{}, ErrNotFound
		}
		return StoreContext{}, err
	}
	return store, nil
}

func (r *mysqlRepository) ListCategories(ctx context.Context, brandID int) ([]CategoryRow, error) {
	query := `
		SELECT c.id, b.slug, c.name_translations, c.display_order
		FROM categories c
		INNER JOIN brands b ON b.id = c.brand_id
		WHERE c.is_active = true
	`
	args := []any{}
	if brandID > 0 {
		query += " AND c.brand_id = ?"
		args = append(args, brandID)
	}
	query += " ORDER BY c.display_order, c.id"

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var categories []CategoryRow
	for rows.Next() {
		var category CategoryRow
		var nameJSON []byte
		if err := rows.Scan(&category.ID, &category.BrandSlug, &nameJSON, &category.DisplayOrder); err != nil {
			return nil, err
		}
		category.NameTranslations = decodeStringMap(nameJSON)
		categories = append(categories, category)
	}
	return categories, rows.Err()
}

func (r *mysqlRepository) ListProducts(ctx context.Context, zoneID string, brandID int) ([]ProductRow, error) {
	query := `
		SELECT mi.id, mi.category_id, mi.sku_code, mi.name_translations, mi.desc_translations,
		       COALESCE(mi.image_url_sm, ''), COALESCE(mi.image_url_lg, ''), COALESCE(mi.dietary_tags, JSON_ARRAY()),
		       mip.base_price, mip.tax_inclusive
		FROM menu_items mi
		INNER JOIN categories c ON c.id = mi.category_id
		INNER JOIN menu_item_pricing mip ON mip.menu_item_id = mi.id AND mip.zone_id = ?
		WHERE mi.is_active = true AND mi.deleted_at IS NULL AND c.is_active = true
	`
	args := []any{zoneID}
	if brandID > 0 {
		query += " AND c.brand_id = ?"
		args = append(args, brandID)
	}
	query += " ORDER BY c.display_order, mi.id"

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var products []ProductRow
	for rows.Next() {
		var product ProductRow
		var nameJSON, descJSON, tagsJSON []byte
		if err := rows.Scan(&product.ID, &product.CategoryID, &product.SKUCode, &nameJSON, &descJSON, &product.ImageURLSmall, &product.ImageURLLarge, &tagsJSON, &product.BasePrice, &product.TaxInclusive); err != nil {
			return nil, err
		}
		product.NameTranslations = decodeStringMap(nameJSON)
		product.DescTranslations = decodeStringMap(descJSON)
		product.DietaryTags = decodeStringSlice(tagsJSON)
		products = append(products, product)
	}
	return products, rows.Err()
}

func (r *mysqlRepository) ListCustomizationGroups(ctx context.Context, menuItemIDs []int) ([]GroupRow, error) {
	if len(menuItemIDs) == 0 {
		return nil, nil
	}

	query, args := inQuery(`
		SELECT id, menu_item_id, name_translations, selection_type, is_required, max_selections, display_order
		FROM customization_groups
		WHERE menu_item_id IN (%s)
		ORDER BY menu_item_id, display_order, id
	`, menuItemIDs)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var groups []GroupRow
	for rows.Next() {
		var group GroupRow
		var nameJSON []byte
		if err := rows.Scan(&group.ID, &group.MenuItemID, &nameJSON, &group.SelectionType, &group.IsRequired, &group.MaxSelections, &group.DisplayOrder); err != nil {
			return nil, err
		}
		group.NameTranslations = decodeStringMap(nameJSON)
		groups = append(groups, group)
	}
	return groups, rows.Err()
}

func (r *mysqlRepository) ListCustomizationOptions(ctx context.Context, groupIDs []int) ([]OptionRow, error) {
	if len(groupIDs) == 0 {
		return nil, nil
	}

	query, args := inQuery(`
		SELECT id, group_id, name_translations, price_adjustment, is_default
		FROM customization_options
		WHERE group_id IN (%s)
		ORDER BY group_id, id
	`, groupIDs)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var options []OptionRow
	for rows.Next() {
		var option OptionRow
		var nameJSON []byte
		if err := rows.Scan(&option.ID, &option.GroupID, &nameJSON, &option.PriceAdjustment, &option.IsDefault); err != nil {
			return nil, err
		}
		option.NameTranslations = decodeStringMap(nameJSON)
		options = append(options, option)
	}
	return options, rows.Err()
}

func (r *mysqlRepository) ListBrands(ctx context.Context) ([]BrandRow, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, slug, name, theme_config
		FROM brands
		ORDER BY id
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var brands []BrandRow
	for rows.Next() {
		var b BrandRow
		var themeJSON []byte
		if err := rows.Scan(&b.ID, &b.Slug, &b.Name, &themeJSON); err != nil {
			return nil, err
		}
		b.ThemeConfig = decodeStringMap(themeJSON)
		brands = append(brands, b)
	}
	return brands, rows.Err()
}

func (r *mysqlRepository) ListStores(ctx context.Context, countryID string) ([]StoreRow, error) {
	query := `
		SELECT id, brand_id, country_id, zone_id, store_code, name_translations, latitude, longitude, address_translations, is_active
		FROM stores
	`
	args := []any{}
	if countryID != "" {
		query += " WHERE country_id = ?"
		args = append(args, countryID)
	}
	query += " ORDER BY id"

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var stores []StoreRow
	for rows.Next() {
		var s StoreRow
		var nameJSON, addrJSON []byte
		if err := rows.Scan(&s.ID, &s.BrandID, &s.CountryID, &s.ZoneID, &s.StoreCode, &nameJSON, &s.Latitude, &s.Longitude, &addrJSON, &s.IsActive); err != nil {
			return nil, err
		}
		s.NameTranslations = decodeStringMap(nameJSON)
		s.AddressTranslations = decodeStringMap(addrJSON)
		stores = append(stores, s)
	}
	return stores, rows.Err()
}

var ErrNotFound = errors.New("not found")

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

func decodeStringSlice(raw []byte) []string {
	if len(raw) == 0 {
		return []string{}
	}
	var out []string
	if err := json.Unmarshal(raw, &out); err != nil {
		return []string{}
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
	return fmt.Sprintf(format, join(placeholders, ",")), args
}

func join(values []string, sep string) string {
	out := ""
	for i, value := range values {
		if i > 0 {
			out += sep
		}
		out += value
	}
	return out
}
