package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/rand"
	"os"
	"path/filepath"
	"strings"

	"github.com/loob/backend/internal/database"
)

const seedPricesTaxInclusive = true

func seedPriceStep(countryID string) int {
	switch strings.ToUpper(strings.TrimSpace(countryID)) {
	case "TH":
		return 100
	default:
		return 10
	}
}

func chooseSeedDisplayPrice(countryID string, minPrice int, maxPrice int) int {
	if maxPrice < minPrice {
		minPrice, maxPrice = maxPrice, minPrice
	}
	step := seedPriceStep(countryID)
	if step <= 1 {
		if maxPrice == minPrice {
			return minPrice
		}
		return minPrice + rand.Intn(maxPrice-minPrice+1)
	}

	alignedMin := ((minPrice + step - 1) / step) * step
	alignedMax := (maxPrice / step) * step
	if alignedMin > alignedMax {
		return minPrice
	}
	if alignedMin == alignedMax {
		return alignedMin
	}

	steps := ((alignedMax - alignedMin) / step) + 1
	return alignedMin + rand.Intn(steps)*step
}

type BaseData struct {
	Countries []CountryData `json:"countries"`
	Brands    []BrandData   `json:"brands"`
}

type CountryData struct {
	ID              string  `json:"id"`
	Name            string  `json:"name"`
	CurrencyCode    string  `json:"currency_code"`
	Timezone        string  `json:"timezone"`
	TaxRate         float64 `json:"tax_rate"`
	DefaultLanguage string  `json:"default_language"`
}

type BrandData struct {
	ID           int    `json:"id"`
	Slug         string `json:"slug"`
	Name         string `json:"name"`
	PrimaryColor string `json:"primary_color"`
	AccentColor  string `json:"accent_color"`
}

type RegionalData struct {
	Zones             []ZoneData            `json:"zones"`
	Stores            []StoreData           `json:"stores"`
	Categories        []CategoryData        `json:"categories"`
	Items             []ItemData            `json:"items"`
	StoreItemStatuses []StoreItemStatusData `json:"store_item_statuses"`
	Vouchers          []VoucherData         `json:"vouchers"`
}

type VoucherData struct {
	Code                     string          `json:"code"`
	BrandID                  *int            `json:"brand_id"`
	VoucherType              string          `json:"voucher_type"`
	DiscountType             string          `json:"discount_type"`
	DiscountValue            int             `json:"discount_value"`
	MinSpend                 int             `json:"min_spend"`
	MaxDiscountCap           *int            `json:"max_discount_cap"`
	VoidedAt                 *string         `json:"voided_at"`
	RedemptionCount          *int            `json:"redemption_count"`
	MaxRedemptions           *int            `json:"max_redemptions"`
	MaxRedemptionsPerUser    *int            `json:"max_redemptions_per_user"`
	AllowPromoItems          bool            `json:"allow_promo_items"`
	StackingGroup            string          `json:"stacking_group"`
	StackingPriority         int             `json:"stacking_priority"`
	Exclusive                bool            `json:"exclusive"`
	CombinableWithGroups     json.RawMessage `json:"combinable_with_groups"`
	ApplicableStoreIDs       json.RawMessage `json:"applicable_store_ids"`
	ApplicableCategoryIDs    json.RawMessage `json:"applicable_category_ids"`
	ApplicableItemIDs        json.RawMessage `json:"applicable_item_ids"`
	ApplicablePaymentMethods json.RawMessage `json:"applicable_payment_methods"`
	TermsAndConditionsMarkdown *string       `json:"terms_and_conditions_markdown"`
	TermsAndConditionsHTML     *string       `json:"terms_and_conditions_html"`
}

type ZoneData struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type StoreData struct {
	Code              string `json:"code"`
	Name              string `json:"name"`
	BID               int    `json:"bid"`
	ZID               string `json:"zid"`
	OperationalStatus string `json:"operational_status"`
	StatusMessage     string `json:"status_message"`
}

type CategoryData struct {
	ID      int               `json:"id"`
	BID     int               `json:"bid"`
	Name    map[string]string `json:"name"`
	IconURL string            `json:"icon_url"`
}

type ItemData struct {
	ID                  int                      `json:"id"`
	BID                 int                      `json:"bid"`
	CID                 *int                     `json:"cid"`
	ItemType            string                   `json:"item_type"`
	SKU                 string                   `json:"sku"`
	Name                map[string]string        `json:"name"`
	Description         map[string]string        `json:"description"`
	ImageURLSmall       string                   `json:"image_url_sm"`
	ImageURLLarge       string                   `json:"image_url_lg"`
	DietaryTags         []string                 `json:"dietary_tags"`
	IsPromo             bool                     `json:"is_promo"`
	PriceMin            int                      `json:"price_min"`
	PriceMax            int                      `json:"price_max"`
	CustomizationGroups []CustomizationGroupData `json:"customization_groups"`
}

type CustomizationGroupData struct {
	Code          string                    `json:"code"`
	Name          map[string]string         `json:"name"`
	SelectionType string                    `json:"selection_type"`
	MinSelections int                       `json:"min_selections"`
	MaxSelections int                       `json:"max_selections"`
	DisplayOrder  int                       `json:"display_order"`
	Metadata      map[string]any            `json:"metadata"`
	Options       []CustomizationOptionData `json:"options"`
}

type CustomizationOptionData struct {
	Code            string            `json:"code"`
	LinkedSKU       string            `json:"linked_sku"`
	Name            map[string]string `json:"name"`
	PriceAdjustment int               `json:"price_adjustment"`
	IsDefault       bool              `json:"is_default"`
	DisplayOrder    int               `json:"display_order"`
	Metadata        map[string]any    `json:"metadata"`
}

type StoreItemStatusData struct {
	StoreCode   string `json:"store_code"`
	SKU         string `json:"sku"`
	IsListed    bool   `json:"is_listed"`
	IsAvailable bool   `json:"is_available"`
}

type UserSeedData struct {
	User            UserData                 `json:"user"`
	Wallets         []UserWalletData         `json:"wallets"`
	LoyaltyAccounts []UserLoyaltyAccountData `json:"loyalty_accounts"`
	UserVouchers    []UserVoucherLinkData    `json:"user_vouchers"`
	Transactions    []UserTransactionData    `json:"transaction_history"`
}

type UserData struct {
	ID                  string `json:"id"`
	DisplayName         string `json:"display_name"`
	Email               string `json:"email"`
	PhoneNumber         string `json:"phone_number"`
	AvatarURL           string `json:"avatar_url"`
	PreferredLanguage   string `json:"preferred_language"`
	RegisteredCountryID string `json:"registered_country_id"`
	MarketingOptIn      bool   `json:"marketing_opt_in"`
}

type UserWalletData struct {
	CountryID    string `json:"country_id"`
	Balance      int    `json:"balance"`
	CurrencyCode string `json:"currency_code"`
}

type UserLoyaltyAccountData struct {
	CountryID      string `json:"country_id"`
	Points         int    `json:"points"`
	LifetimePoints int    `json:"lifetime_points"`
	Tier           string `json:"tier"`
}

type UserVoucherLinkData struct {
	Code      string `json:"code"`
	CountryID string `json:"country_id"`
	Status    string `json:"status"`
}

type UserTransactionData struct {
	TrackingID      string          `json:"tracking_id"`
	TraceID         string          `json:"trace_id"`
	IdempotencyKey  string          `json:"idempotency_key"`
	StoreCode       string          `json:"store_code"`
	CountryID       string          `json:"country_id"`
	FulfillmentType string          `json:"fulfillment_type"`
	Status          string          `json:"status"`
	Subtotal        int             `json:"subtotal"`
	ChargesPayload  json.RawMessage `json:"charges_payload"`
	TaxAmount       int             `json:"tax_amount"`
	DiscountAmount  int             `json:"discount_amount"`
	TotalAmount     int             `json:"total_amount"`
	VoucherCode     *string         `json:"voucher_code"`
	CartPayload     json.RawMessage `json:"cart_payload"`
	Payment         *PaymentData    `json:"payment"`
	CreatedAt       string          `json:"created_at"`
}

type PaymentData struct {
	ID           string `json:"id"`
	Provider     string `json:"provider"`
	MethodCode   string `json:"method_code"`
	Status       string `json:"status"`
	CurrencyCode string `json:"currency_code"`
	Amount       int    `json:"amount"`
}

func main() {
	database.InitDB()
	database.InitRedis()
	db := database.DB

	country := strings.ToUpper(os.Getenv("COUNTRY"))

	if os.Getenv("CLEAN") == "true" {
		cleanDB(db, country)
	}

	seed(db, country)
	invalidateSeedCaches(country)
	log.Printf("Seeding for %s completed successfully!", getCountryLabel(country))
}

func getCountryLabel(c string) string {
	if c == "" {
		return "ALL countries"
	}
	return c
}

func invalidateSeedCaches(country string) {
	if database.RedisClientInstance == nil {
		return
	}

	ctx := context.Background()
	patterns := []string{"catalog:*", "lock:catalog:*"}
	for _, pattern := range patterns {
		if err := database.RedisClientInstance.DelPattern(ctx, pattern); err != nil {
			log.Printf("Failed to invalidate Redis pattern %s after seed: %v", pattern, err)
		}
	}
}

func cleanDB(db *sql.DB, country string) {
	log.Printf("Cleaning database (Target: %s)...", getCountryLabel(country))
	_, _ = db.Exec("SET FOREIGN_KEY_CHECKS = 0")
	if country == "" {
		tables := []string{
			"loyalty_transactions", "wallet_transactions", "payment_events", "payment_transactions", "order_intent_item_options", "order_intent_items", "order_intent_vouchers", "order_intents", "voucher_user_redemption_counters", "wallet_accounts", "loyalty_accounts", "loyalty_checkins", "user_vouchers", "vouchers", "store_menu_item_status", "customization_options", "customization_groups",
			"menu_item_pricing", "menu_items", "categories", "stores", "zones",
			"brands", "users", "countries", "campaigns", "payment_methods", "payment_providers",
		}
		for _, table := range tables {
			_, _ = db.Exec(fmt.Sprintf("TRUNCATE TABLE %s", table))
		}
	} else {
		_, _ = db.Exec("DELETE FROM loyalty_transactions WHERE country_id = ?", country)
		_, _ = db.Exec("DELETE FROM wallet_transactions WHERE country_id = ?", country)
		_, _ = db.Exec("DELETE FROM payment_events WHERE payment_transaction_id IN (SELECT id FROM payment_transactions WHERE country_id = ?)", country)
		_, _ = db.Exec("DELETE FROM payment_transactions WHERE country_id = ?", country)
		_, _ = db.Exec("DELETE oio FROM order_intent_item_options oio INNER JOIN order_intent_items oii ON oii.id = oio.order_intent_item_id INNER JOIN order_intents oi ON oi.tracking_id = oii.order_tracking_id WHERE oi.country_id = ?", country)
		_, _ = db.Exec("DELETE oii FROM order_intent_items oii INNER JOIN order_intents oi ON oi.tracking_id = oii.order_tracking_id WHERE oi.country_id = ?", country)
		_, _ = db.Exec("DELETE oiv FROM order_intent_vouchers oiv INNER JOIN order_intents oi ON oi.tracking_id = oiv.order_tracking_id WHERE oi.country_id = ?", country)
		_, _ = db.Exec("DELETE FROM order_intents WHERE country_id = ?", country)
		_, _ = db.Exec("DELETE vurc FROM voucher_user_redemption_counters vurc INNER JOIN vouchers v ON v.id = vurc.voucher_id WHERE v.country_id = ?", country)
		_, _ = db.Exec("DELETE FROM user_vouchers WHERE voucher_id IN (SELECT id FROM vouchers WHERE country_id = ?)", country)
		_, _ = db.Exec("DELETE FROM vouchers WHERE country_id = ?", country)
		_, _ = db.Exec("DELETE FROM wallet_accounts WHERE country_id = ?", country)
		_, _ = db.Exec("DELETE FROM loyalty_accounts WHERE country_id = ?", country)
		_, _ = db.Exec("DELETE smis FROM store_menu_item_status smis INNER JOIN stores s ON s.id = smis.store_id WHERE s.country_id = ?", country)
		_, _ = db.Exec("DELETE FROM menu_item_pricing WHERE zone_id IN (SELECT id FROM zones WHERE country_id = ?)", country)
		_, _ = db.Exec("DELETE FROM stores WHERE country_id = ?", country)
		_, _ = db.Exec("DELETE FROM zones WHERE country_id = ?", country)
		_, _ = db.Exec("DELETE FROM campaigns WHERE country_id = ?", country)
		_, _ = db.Exec("DELETE FROM payment_methods WHERE country_id = ?", country)
	}
	_, _ = db.Exec("SET FOREIGN_KEY_CHECKS = 1")
}

func loadJSON(filename string, target interface{}) error {
	path := filepath.Join("cmd", "seed", "data", filename)
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, target)
}

func seed(db *sql.DB, country string) {
	var base BaseData
	if err := loadJSON("base.json", &base); err != nil {
		log.Fatalf("Failed to load base.json: %v", err)
	}

	seedBase(db, base)

	if country == "" || country == "MY" {
		var my RegionalData
		if err := loadJSON("my.json", &my); err != nil {
			log.Fatalf("Failed to load my.json: %v", err)
		}
		seedRegional(db, "MY", my)
		seedCampaigns(db, "MY")
	}
	if country == "" || country == "TH" {
		var th RegionalData
		if err := loadJSON("th.json", &th); err != nil {
			log.Fatalf("Failed to load th.json: %v", err)
		}
		seedRegional(db, "TH", th)
		seedCampaigns(db, "TH")
	}

	seedUserData(db, country)
}

func seedBase(db *sql.DB, data BaseData) {
	ctx := context.Background()
	log.Println("Seeding base data...")

	for _, c := range data.Countries {
		_, _ = db.ExecContext(ctx, `
			INSERT INTO countries (id, name, currency_code, timezone, tax_rate, default_language, is_active)
			VALUES (?, ?, ?, ?, ?, ?, true)
			ON DUPLICATE KEY UPDATE is_active = true
		`, c.ID, c.Name, c.CurrencyCode, c.Timezone, c.TaxRate, c.DefaultLanguage)
	}

	for _, b := range data.Brands {
		theme, _ := json.Marshal(map[string]string{"primary": b.PrimaryColor, "accent": b.AccentColor})
		_, _ = db.ExecContext(ctx, `
			INSERT IGNORE INTO brands (id, slug, name, theme_config)
			VALUES (?, ?, ?, ?)
		`, b.ID, b.Slug, b.Name, theme)
	}

	_, _ = db.ExecContext(ctx, `
		INSERT INTO payment_providers
			(code, display_name, provider_type, callback_url, is_mock, is_active, config)
		VALUES
			('mock_gateway', 'Mock Gateway', 'EWALLET', '/api/v1/payments/mock-gateway/callback', true, true, JSON_OBJECT('mode', 'local'))
		ON DUPLICATE KEY UPDATE
			display_name = VALUES(display_name),
			callback_url = VALUES(callback_url),
			is_mock = true,
			is_active = true
	`)

	for _, c := range data.Countries {
		_, _ = db.ExecContext(ctx, `
			DELETE FROM payment_methods
			WHERE provider_code = 'mock_gateway' AND country_id = ? AND brand_id IS NULL
		`, c.ID)

		methods := []struct {
			code        string
			name        string
			description string
			order       int
		}{
			{code: "EWALLET", name: "Mock E-Wallet", description: "Instant local approval for development checkout.", order: 1},
			{code: "FPX", name: "Mock Online Banking", description: "Simulated bank transfer for development checkout.", order: 2},
		}
		for _, method := range methods {
			_, _ = db.ExecContext(ctx, `
				INSERT INTO payment_methods
					(code, provider_code, country_id, brand_id, display_name, description, currency_code, min_amount, max_amount, display_order, is_active, metadata)
				VALUES
					(?, 'mock_gateway', ?, NULL, ?, ?, ?, 1, NULL, ?, true, JSON_OBJECT('mock', true))
				ON DUPLICATE KEY UPDATE
					display_name = VALUES(display_name),
					description = VALUES(description),
					currency_code = VALUES(currency_code),
					is_active = true,
					metadata = VALUES(metadata)
			`, method.code, c.ID, method.name, method.description, c.CurrencyCode, method.order)
		}
	}

	_, _ = db.ExecContext(ctx, `
		INSERT INTO checkout_charge_definitions (
			code, name, country_id, zone_id, brand_id, fulfillment_type, scope,
			calculation_type, amount, taxable, tax_inclusive, display_order
		)
		VALUES (
			'PACKAGING_FEE', 'Packaging fee', NULL, NULL, NULL, NULL, 'ORDER',
			'FIXED_AMOUNT', 100, true, ?, 10
		)
		ON DUPLICATE KEY UPDATE
			name = VALUES(name),
			amount = VALUES(amount),
			taxable = VALUES(taxable),
			tax_inclusive = VALUES(tax_inclusive),
			display_order = VALUES(display_order),
			is_active = true
	`, seedPricesTaxInclusive)
}

func seedRegional(db *sql.DB, cid string, data RegionalData) {
	ctx := context.Background()
	log.Printf("Seeding %s specific data...", cid)

	storeIDs := map[string]int{}
	itemIDsBySKU := map[string]int{}

	for _, z := range data.Zones {
		_, _ = db.ExecContext(ctx, "INSERT IGNORE INTO zones (id, country_id, name) VALUES (?, ?, ?)", z.ID, cid, z.Name)
	}

	for i, s := range data.Stores {
		code := s.Code
		if code == "" {
			code = fmt.Sprintf("%s-%03d", cid, i+1)
		}
		names, _ := json.Marshal(map[string]string{"en-US": s.Name}) // Simplified for example
		tz := "Asia/Kuala_Lumpur"
		if cid == "TH" {
			tz = "Asia/Bangkok"
		}
		status := strings.ToUpper(strings.TrimSpace(s.OperationalStatus))
		if status == "" {
			status = "OPEN"
		}
		var statusMessage any
		if strings.TrimSpace(s.StatusMessage) != "" {
			statusMessage = s.StatusMessage
		}
		res, err := db.ExecContext(ctx, `
			INSERT INTO stores (brand_id, country_id, zone_id, store_code, name_translations, latitude, longitude, timezone, operational_status, status_message)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
			ON DUPLICATE KEY UPDATE
				brand_id = VALUES(brand_id),
				zone_id = VALUES(zone_id),
				name_translations = VALUES(name_translations),
				timezone = VALUES(timezone),
				operational_status = VALUES(operational_status),
				status_message = VALUES(status_message),
				is_active = true,
				id = LAST_INSERT_ID(id)
		`, s.BID, cid, s.ZID, code, names, 3.1+rand.Float64(), 101.6+rand.Float64(), tz, status, statusMessage)
		if err != nil || res == nil {
			continue
		}
		storeID, _ := res.LastInsertId()
		if storeID > 0 {
			storeIDs[code] = int(storeID)
		}
	}

	for _, c := range data.Categories {
		names, _ := json.Marshal(c.Name)
		_, _ = db.ExecContext(ctx, `
			INSERT INTO categories (id, brand_id, name_translations, display_order, icon_url)
			VALUES (?, ?, ?, ?, ?)
			ON DUPLICATE KEY UPDATE
				name_translations = VALUES(name_translations),
				display_order = VALUES(display_order),
				icon_url = VALUES(icon_url)
		`, c.ID, c.BID, names, c.ID, c.IconURL)
	}

	for _, it := range data.Items {
		names, _ := json.Marshal(it.Name)
		desc, _ := json.Marshal(it.Description)
		tags, _ := json.Marshal(it.DietaryTags)
		itemType := strings.ToUpper(strings.TrimSpace(it.ItemType))
		if itemType == "" {
			itemType = "MAIN"
		}
		itemIDsBySKU[it.SKU] = it.ID
		_, _ = db.ExecContext(ctx, `
			INSERT INTO menu_items (id, category_id, brand_id, item_type, sku_code, name_translations, desc_translations, image_url_sm, image_url_lg, dietary_tags, is_promo)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
			ON DUPLICATE KEY UPDATE
				category_id = VALUES(category_id),
				brand_id = VALUES(brand_id),
				item_type = VALUES(item_type),
				name_translations = VALUES(name_translations),
				desc_translations = VALUES(desc_translations),
				image_url_sm = VALUES(image_url_sm),
				image_url_lg = VALUES(image_url_lg),
				dietary_tags = VALUES(dietary_tags),
				is_promo = VALUES(is_promo),
				deleted_at = NULL,
				is_active = true
		`, it.ID, it.CID, it.BID, itemType, it.SKU, names, desc, it.ImageURLSmall, it.ImageURLLarge, tags, it.IsPromo)

		for _, z := range data.Zones {
			price := chooseSeedDisplayPrice(cid, it.PriceMin, it.PriceMax)
			_, _ = db.ExecContext(ctx, `
				INSERT INTO menu_item_pricing (menu_item_id, zone_id, base_price, tax_inclusive)
				VALUES (?, ?, ?, ?)
				ON DUPLICATE KEY UPDATE
					base_price = VALUES(base_price),
					tax_inclusive = VALUES(tax_inclusive)
			`, it.ID, z.ID, price, seedPricesTaxInclusive)
		}
	}

	for _, it := range data.Items {
		if len(it.CustomizationGroups) > 0 {
			seedCustomizationGroups(db, it.ID, it.CustomizationGroups, itemIDsBySKU)
		}
	}

	seedStoreItemStatuses(db, data.StoreItemStatuses, storeIDs, itemIDsBySKU)
	seedRegionalVouchers(db, cid, data.Vouchers)
}

func seedCustomizationGroups(db *sql.DB, itemID int, groups []CustomizationGroupData, itemIDsBySKU map[string]int) {
	ctx := context.Background()
	for _, group := range groups {
		nameJSON, _ := json.Marshal(group.Name)
		metadataJSON, _ := json.Marshal(group.Metadata)
		isRequired := group.MinSelections > 0
		res, err := db.ExecContext(ctx, `
			INSERT INTO customization_groups (
				menu_item_id, group_code, name_translations, selection_type,
				min_selections, is_required, max_selections, display_order, metadata
			)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
			ON DUPLICATE KEY UPDATE
				name_translations = VALUES(name_translations),
				selection_type = VALUES(selection_type),
				min_selections = VALUES(min_selections),
				is_required = VALUES(is_required),
				max_selections = VALUES(max_selections),
				display_order = VALUES(display_order),
				metadata = VALUES(metadata),
				id = LAST_INSERT_ID(id)
		`, itemID, group.Code, nameJSON, group.SelectionType, group.MinSelections, isRequired, group.MaxSelections, group.DisplayOrder, metadataJSON)
		if err != nil || res == nil {
			continue
		}
		groupID, _ := res.LastInsertId()
		if groupID == 0 {
			continue
		}

		for _, option := range group.Options {
			optionNames, _ := json.Marshal(option.Name)
			optionMetadata, _ := json.Marshal(option.Metadata)
			var linkedMenuItemID any
			if option.LinkedSKU != "" {
				if id, ok := itemIDsBySKU[option.LinkedSKU]; ok {
					linkedMenuItemID = id
				}
			}
			_, _ = db.ExecContext(ctx, `
				INSERT INTO customization_options (
					group_id, option_code, linked_menu_item_id, name_translations, price_adjustment,
					is_default, display_order, metadata
				)
				VALUES (?, ?, ?, ?, ?, ?, ?, ?)
				ON DUPLICATE KEY UPDATE
					linked_menu_item_id = VALUES(linked_menu_item_id),
					name_translations = VALUES(name_translations),
					price_adjustment = VALUES(price_adjustment),
					is_default = VALUES(is_default),
					display_order = VALUES(display_order),
					metadata = VALUES(metadata)
			`, groupID, option.Code, linkedMenuItemID, optionNames, option.PriceAdjustment, option.IsDefault, option.DisplayOrder, optionMetadata)
		}
	}
}

func seedStoreItemStatuses(db *sql.DB, statuses []StoreItemStatusData, storeIDs map[string]int, itemIDsBySKU map[string]int) {
	ctx := context.Background()
	for _, status := range statuses {
		storeID, ok := storeIDs[status.StoreCode]
		if !ok {
			continue
		}
		menuItemID, ok := itemIDsBySKU[status.SKU]
		if !ok {
			continue
		}
		_, _ = db.ExecContext(ctx, `
			INSERT INTO store_menu_item_status (store_id, menu_item_id, is_listed, is_available)
			VALUES (?, ?, ?, ?)
			ON DUPLICATE KEY UPDATE
				is_listed = VALUES(is_listed),
				is_available = VALUES(is_available)
		`, storeID, menuItemID, status.IsListed, status.IsAvailable)
	}
}

func seedCampaigns(db *sql.DB, countryCode string) {
	ctx := context.Background()
	log.Printf("Seeding %s campaign/banner data...", countryCode)

	var campaigns []struct {
		brandID      *int
		campaignType string
		title        map[string]string
		subtitle     map[string]string
		imageURL     string
		deepLink     string
		priority     int
	}

	switch countryCode {
	case "MY":
		tealiveBrand := 1
		baskbearBrand := 2
		campaigns = []struct {
			brandID      *int
			campaignType string
			title        map[string]string
			subtitle     map[string]string
			imageURL     string
			deepLink     string
			priority     int
		}{
			{
				brandID:      &tealiveBrand,
				campaignType: "BANNER",
				title:        map[string]string{"en-US": "Tealive Flash Sale!", "ms-MY": "Jualan Kilat Tealive!"},
				subtitle:     map[string]string{"en-US": "50% off all signature drinks today", "ms-MY": "Diskaun 50% untuk semua minuman utama hari ini"},
				imageURL:     "/cdn/promo_tealive.png",
				deepLink:     "loob://promo/2",
				priority:     10,
			},
			{
				brandID:      &baskbearBrand,
				campaignType: "BANNER",
				title:        map[string]string{"en-US": "Baskbear Morning Combo", "ms-MY": "Kombo Pagi Baskbear"},
				subtitle:     map[string]string{"en-US": "Toast + Coffee from RM 6.90", "ms-MY": "Roti Bakar + Kopi daripada RM 6.90"},
				imageURL:     "/cdn/promo_baskbear.png",
				deepLink:     "loob://promo/3",
				priority:     5,
			},
		}
	case "TH":
		tealiveBrand := 1
		baskbearBrand := 2
		campaigns = []struct {
			brandID      *int
			campaignType string
			title        map[string]string
			subtitle     map[string]string
			imageURL     string
			deepLink     string
			priority     int
		}{
			{
				brandID:      &tealiveBrand,
				campaignType: "BANNER",
				title:        map[string]string{"en-US": "Tealive Thailand Promo", "th-TH": "โปรโมชั่นพิเศษ Tealive"},
				subtitle:     map[string]string{"en-US": "Get your favorite boba tea now!", "th-TH": "ซื้อชานมไข่มุกแก้วโปรดของคุณตอนนี้"},
				imageURL:     "/cdn/promo_tealive.png",
				deepLink:     "loob://promo/2",
				priority:     10,
			},
			{
				brandID:      &baskbearBrand,
				campaignType: "BANNER",
				title:        map[string]string{"en-US": "Baskbear Coffee Special", "th-TH": "กาแฟพิเศษ Baskbear"},
				subtitle:     map[string]string{"en-US": "Premium coffee to start your day", "th-TH": "กาแฟพรีเมียมสำหรับเริ่มต้นวันใหม่"},
				imageURL:     "/cdn/promo_baskbear.png",
				deepLink:     "loob://promo/3",
				priority:     5,
			},
		}
	}

	for _, c := range campaigns {
		titleJSON, _ := json.Marshal(c.title)
		subtitleJSON, _ := json.Marshal(c.subtitle)
		metadataJSON, _ := json.Marshal(map[string]any{})

		_, err := db.ExecContext(ctx, `
			INSERT INTO campaigns (
				country_id, brand_id, campaign_type, title_translations, subtitle_translations,
				image_url, deep_link, priority, starts_at, ends_at, is_active, metadata
			) VALUES (?, ?, ?, ?, ?, ?, ?, ?, '2026-01-01 00:00:00', '2030-01-01 00:00:00', true, ?)
		`, countryCode, c.brandID, c.campaignType, titleJSON, subtitleJSON, c.imageURL, c.deepLink, c.priority, metadataJSON)
		if err != nil {
			log.Printf("Failed to seed campaign %v: %v", c.title, err)
		}
	}
}

func seedUserData(db *sql.DB, targetCountry string) {
	var data UserSeedData
	if err := loadJSON("user.json", &data); err != nil {
		log.Fatalf("Failed to load user.json: %v", err)
	}

	ctx := context.Background()
	log.Printf("Seeding user %s and related multi-country details...", data.User.ID)

	// 1. Seed user profile
	_, err := db.ExecContext(ctx, `
		INSERT INTO users (id, display_name, email, phone_number, avatar_url, preferred_language, registered_country_id, marketing_opt_in)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE
			display_name = VALUES(display_name),
			email = VALUES(email),
			phone_number = VALUES(phone_number),
			avatar_url = VALUES(avatar_url),
			preferred_language = VALUES(preferred_language),
			registered_country_id = VALUES(registered_country_id),
			marketing_opt_in = VALUES(marketing_opt_in)
	`, data.User.ID, data.User.DisplayName, data.User.Email, data.User.PhoneNumber, data.User.AvatarURL, data.User.PreferredLanguage, data.User.RegisteredCountryID, data.User.MarketingOptIn)
	if err != nil {
		log.Fatalf("Failed to seed user profile: %v", err)
	}

	// 2. Seed wallet accounts
	walletRunningBalance := map[string]int{}
	for _, w := range data.Wallets {
		if targetCountry != "" && w.CountryID != targetCountry {
			continue
		}
		_, err = db.ExecContext(ctx, `
			INSERT INTO wallet_accounts (user_id, country_id, balance, currency_code)
			VALUES (?, ?, ?, ?)
			ON DUPLICATE KEY UPDATE
				balance = VALUES(balance),
				currency_code = VALUES(currency_code)
		`, data.User.ID, w.CountryID, w.Balance, w.CurrencyCode)
		if err != nil {
			log.Printf("Failed to seed wallet account for country %s: %v", w.CountryID, err)
		}
	}

	// 3. Seed loyalty accounts
	for _, l := range data.LoyaltyAccounts {
		if targetCountry != "" && l.CountryID != targetCountry {
			continue
		}
		_, err = db.ExecContext(ctx, `
			INSERT INTO loyalty_accounts (user_id, country_id, points, lifetime_points, tier)
			VALUES (?, ?, ?, ?, ?)
			ON DUPLICATE KEY UPDATE
				points = VALUES(points),
				lifetime_points = VALUES(lifetime_points),
				tier = VALUES(tier)
		`, data.User.ID, l.CountryID, l.Points, l.LifetimePoints, l.Tier)
		if err != nil {
			log.Printf("Failed to seed loyalty account for country %s: %v", l.CountryID, err)
		}
	}

	// 4. Link user_vouchers
	for _, uv := range data.UserVouchers {
		if targetCountry != "" && uv.CountryID != targetCountry {
			continue
		}

		var voucherID int
		err := db.QueryRowContext(ctx, "SELECT id FROM vouchers WHERE code = ? AND country_id = ?", uv.Code, uv.CountryID).Scan(&voucherID)
		if err != nil {
			log.Printf("Voucher %s in %s not found when linking to user: %v", uv.Code, uv.CountryID, err)
			continue
		}

		_, err = db.ExecContext(ctx, `
			INSERT INTO user_vouchers (user_id, voucher_id, status)
			VALUES (?, ?, ?)
			ON DUPLICATE KEY UPDATE status = VALUES(status)
		`, data.User.ID, voucherID, uv.Status)
		if err != nil {
			log.Printf("Failed to link voucher %s to user: %v", uv.Code, err)
		}
	}

	// 5. Seed transaction history (orders)
	capturedWalletSpendByCountry := map[string]int{}
	capturedLoyaltyEarnByCountry := map[string]int{}
	for _, t := range data.Transactions {
		if targetCountry != "" && t.CountryID != targetCountry {
			continue
		}
		if t.Payment != nil && t.Payment.MethodCode == "EWALLET" && t.Payment.Status == "CAPTURED" {
			capturedWalletSpendByCountry[t.CountryID] += t.Payment.Amount
		}
		if t.Payment != nil && t.Payment.Status == "CAPTURED" {
			points := t.Payment.Amount / 100
			if points <= 0 && t.Payment.Amount > 0 {
				points = 1
			}
			capturedLoyaltyEarnByCountry[t.CountryID] += points
		}
	}
	for _, w := range data.Wallets {
		if targetCountry != "" && w.CountryID != targetCountry {
			continue
		}
		initialBalance := w.Balance + capturedWalletSpendByCountry[w.CountryID]
		walletRunningBalance[w.CountryID] = initialBalance
		_, _ = db.ExecContext(ctx, `
			INSERT IGNORE INTO wallet_transactions (
				user_id, country_id, transaction_type, amount, balance_after, currency_code, reference_type, reference_id, description
			)
			VALUES (?, ?, 'TOPUP', ?, ?, ?, 'SEED', CONCAT(?, '-initial-wallet'), 'Initial demo wallet balance')
		`, data.User.ID, w.CountryID, initialBalance, initialBalance, w.CurrencyCode, w.CountryID)
	}
	loyaltyRunningBalance := map[string]int{}
	for _, l := range data.LoyaltyAccounts {
		if targetCountry != "" && l.CountryID != targetCountry {
			continue
		}
		openingPoints := l.Points - capturedLoyaltyEarnByCountry[l.CountryID]
		if openingPoints < 0 {
			openingPoints = 0
		}
		loyaltyRunningBalance[l.CountryID] = openingPoints
		if openingPoints > 0 {
			_, _ = db.ExecContext(ctx, `
				INSERT IGNORE INTO loyalty_transactions (
					user_id, country_id, transaction_type, points_delta, balance_after, reference_type, reference_id, description
				)
				VALUES (?, ?, 'ADJUSTMENT', ?, ?, 'SEED', CONCAT(?, '-initial-points'), 'Initial demo loyalty points')
			`, data.User.ID, l.CountryID, openingPoints, openingPoints, l.CountryID)
		}
	}

	for _, t := range data.Transactions {
		if targetCountry != "" && t.CountryID != targetCountry {
			continue
		}

		// Find store ID from store code
		var storeID int
		err := db.QueryRowContext(ctx, "SELECT id FROM stores WHERE store_code = ?", t.StoreCode).Scan(&storeID)
		if err != nil {
			log.Printf("Failed to find store ID for store_code %s: %v", t.StoreCode, err)
			continue
		}

		chargesPayload := string(t.ChargesPayload)
		if chargesPayload == "" || chargesPayload == "null" {
			chargesPayload = "[]"
		}

		// Check if order exists
		var existingCount int
		_ = db.QueryRowContext(ctx, "SELECT COUNT(*) FROM order_intents WHERE tracking_id = ?", t.TrackingID).Scan(&existingCount)

		if existingCount > 0 {
			// Update order
			_, err = db.ExecContext(ctx, `
				UPDATE order_intents
				SET trace_id = ?, idempotency_key = ?, store_id = ?, country_id = ?,
				    fulfillment_type = ?, status = ?, subtotal = ?, charges_payload = CAST(? AS JSON),
				    tax_amount = ?, discount_amount = ?, total_amount = ?, voucher_code = ?,
				    cart_payload = CAST(? AS JSON), created_at = ?
				WHERE tracking_id = ?
			`, t.TraceID, t.IdempotencyKey, storeID, t.CountryID, t.FulfillmentType, t.Status, t.Subtotal, chargesPayload, t.TaxAmount, t.DiscountAmount, t.TotalAmount, t.VoucherCode, string(t.CartPayload), t.CreatedAt, t.TrackingID)
		} else {
			// Insert order
			_, err = db.ExecContext(ctx, `
				INSERT INTO order_intents (
					tracking_id, trace_id, idempotency_key, user_id, store_id, country_id,
					fulfillment_type, status, subtotal, charges_payload, tax_amount, discount_amount, total_amount,
					voucher_code, cart_payload, created_at
				) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CAST(? AS JSON), ?, ?, ?, ?, CAST(? AS JSON), ?)
			`, t.TrackingID, t.TraceID, t.IdempotencyKey, data.User.ID, storeID, t.CountryID, t.FulfillmentType, t.Status, t.Subtotal, chargesPayload, t.TaxAmount, t.DiscountAmount, t.TotalAmount, t.VoucherCode, string(t.CartPayload), t.CreatedAt)
		}
		if err != nil {
			log.Printf("Failed to seed order %s: %v", t.TrackingID, err)
			continue
		}

		// Seed payment transaction if provided
		if t.Payment != nil {
			_, err = db.ExecContext(ctx, `
				INSERT INTO payment_transactions (id, order_tracking_id, country_id, user_id, provider, payment_method_code, status, currency_code, amount)
				VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
				ON DUPLICATE KEY UPDATE
					status = VALUES(status),
					amount = VALUES(amount)
			`, t.Payment.ID, t.TrackingID, t.CountryID, data.User.ID, t.Payment.Provider, t.Payment.MethodCode, t.Payment.Status, t.Payment.CurrencyCode, t.Payment.Amount)
			if err != nil {
				log.Printf("Failed to seed payment transaction for order %s: %v", t.TrackingID, err)
			}
			if t.Payment.Status == "CAPTURED" {
				if t.Payment.MethodCode == "EWALLET" {
					walletRunningBalance[t.CountryID] -= t.Payment.Amount
					_, _ = db.ExecContext(ctx, `
						INSERT IGNORE INTO wallet_transactions (
							user_id, country_id, transaction_type, amount, balance_after, currency_code,
							reference_type, reference_id, description, created_at
						)
						VALUES (?, ?, 'SPEND', ?, ?, ?, 'PAYMENT', ?, ?, ?)
					`, data.User.ID, t.CountryID, -t.Payment.Amount, walletRunningBalance[t.CountryID], t.Payment.CurrencyCode, t.Payment.ID, "Order "+t.TrackingID, t.CreatedAt)
				}
				points := t.Payment.Amount / 100
				if points <= 0 && t.Payment.Amount > 0 {
					points = 1
				}
				if points > 0 {
					loyaltyRunningBalance[t.CountryID] += points
					_, _ = db.ExecContext(ctx, `
						INSERT IGNORE INTO loyalty_transactions (
							user_id, country_id, transaction_type, points_delta, balance_after,
							reference_type, reference_id, description, created_at
						)
						VALUES (?, ?, 'EARN', ?, ?, 'PAYMENT', ?, ?, ?)
					`, data.User.ID, t.CountryID, points, loyaltyRunningBalance[t.CountryID], t.Payment.ID, "Order "+t.TrackingID, t.CreatedAt)
				}
			}
		}
	}
}

func seedRegionalVouchers(db *sql.DB, countryID string, vouchers []VoucherData) {
	ctx := context.Background()
	log.Printf("Seeding vouchers for %s...", countryID)
	hasRedemptionCount, err := hasColumn(ctx, db, "vouchers", "redemption_count")
	if err != nil {
		log.Printf("Failed to inspect vouchers.redemption_count support: %v", err)
		hasRedemptionCount = false
	}
	hasTNC, err := hasColumn(ctx, db, "vouchers", "terms_and_conditions_markdown")
	if err != nil {
		log.Printf("Failed to inspect vouchers.terms_and_conditions_markdown support: %v", err)
		hasTNC = false
	}

	for _, v := range vouchers {
		var applicableStoreIDs any = nil
		if len(v.ApplicableStoreIDs) > 0 && string(v.ApplicableStoreIDs) != "null" {
			applicableStoreIDs = string(v.ApplicableStoreIDs)
		}
		var applicableCategoryIDs any = nil
		if len(v.ApplicableCategoryIDs) > 0 && string(v.ApplicableCategoryIDs) != "null" {
			applicableCategoryIDs = string(v.ApplicableCategoryIDs)
		}
		var applicableItemIDs any = nil
		if len(v.ApplicableItemIDs) > 0 && string(v.ApplicableItemIDs) != "null" {
			applicableItemIDs = string(v.ApplicableItemIDs)
		}
		var applicablePaymentMethods any = nil
		if len(v.ApplicablePaymentMethods) > 0 && string(v.ApplicablePaymentMethods) != "null" {
			applicablePaymentMethods = string(v.ApplicablePaymentMethods)
		}
		var combinableWithGroups any = nil
		if len(v.CombinableWithGroups) > 0 && string(v.CombinableWithGroups) != "null" {
			combinableWithGroups = string(v.CombinableWithGroups)
		}
		stackingGroup := v.StackingGroup
		if stackingGroup == "" {
			stackingGroup = v.VoucherType
		}
		stackingPriority := v.StackingPriority
		if stackingPriority == 0 {
			stackingPriority = 100
		}
		redemptionCount := 0
		if v.RedemptionCount != nil {
			redemptionCount = *v.RedemptionCount
		}

		var termsMarkdown any = nil
		if v.TermsAndConditionsMarkdown != nil {
			termsMarkdown = *v.TermsAndConditionsMarkdown
		}
		var termsHTML any = nil
		if v.TermsAndConditionsHTML != nil {
			termsHTML = *v.TermsAndConditionsHTML
		}

		columns := []string{
			"code", "country_id", "brand_id", "voucher_type", "discount_type",
			"discount_value", "min_spend", "max_discount_cap", "voided_at",
			"max_redemptions", "max_redemptions_per_user", "allow_promo_items",
			"stacking_group", "stacking_priority", "exclusive", "combinable_with_groups",
			"applicable_store_ids", "applicable_category_ids", "applicable_item_ids", "applicable_payment_methods",
			"starts_at", "expires_at", "is_active",
		}
		values := []string{
			"?", "?", "?", "?", "?",
			"?", "?", "?", "?",
			"?", "?", "?",
			"?", "?", "?", "CAST(? AS JSON)",
			"CAST(? AS JSON)", "CAST(? AS JSON)", "CAST(? AS JSON)", "CAST(? AS JSON)",
			"'2026-01-01 00:00:00'", "'2030-01-01 00:00:00'", "true",
		}
		args := []any{
			v.Code, countryID, v.BrandID, v.VoucherType, v.DiscountType,
			v.DiscountValue, v.MinSpend, v.MaxDiscountCap, v.VoidedAt,
			v.MaxRedemptions, v.MaxRedemptionsPerUser, v.AllowPromoItems,
			stackingGroup, stackingPriority, v.Exclusive, combinableWithGroups,
			applicableStoreIDs, applicableCategoryIDs, applicableItemIDs, applicablePaymentMethods,
		}

		updates := []string{
			"discount_value = VALUES(discount_value)",
			"min_spend = VALUES(min_spend)",
			"max_discount_cap = VALUES(max_discount_cap)",
			"voided_at = VALUES(voided_at)",
			"max_redemptions = VALUES(max_redemptions)",
			"max_redemptions_per_user = VALUES(max_redemptions_per_user)",
			"allow_promo_items = VALUES(allow_promo_items)",
			"stacking_group = VALUES(stacking_group)",
			"stacking_priority = VALUES(stacking_priority)",
			"exclusive = VALUES(exclusive)",
			"combinable_with_groups = VALUES(combinable_with_groups)",
			"applicable_store_ids = VALUES(applicable_store_ids)",
			"applicable_category_ids = VALUES(applicable_category_ids)",
			"applicable_item_ids = VALUES(applicable_item_ids)",
			"applicable_payment_methods = VALUES(applicable_payment_methods)",
			"is_active = true",
		}

		if hasRedemptionCount {
			columns = append(columns, "redemption_count")
			values = append(values, "?")
			args = append(args, redemptionCount)
			updates = append(updates, "redemption_count = VALUES(redemption_count)")
		}

		if hasTNC {
			columns = append(columns, "terms_and_conditions_markdown", "terms_and_conditions_html")
			values = append(values, "?", "?")
			args = append(args, termsMarkdown, termsHTML)
			updates = append(updates, "terms_and_conditions_markdown = VALUES(terms_and_conditions_markdown)", "terms_and_conditions_html = VALUES(terms_and_conditions_html)")
		}

		query := fmt.Sprintf(`
			INSERT INTO vouchers (%s)
			VALUES (%s)
			ON DUPLICATE KEY UPDATE %s
		`, strings.Join(columns, ", "), strings.Join(values, ", "), strings.Join(updates, ", "))

		_, err = db.ExecContext(ctx, query, args...)
		if err != nil {
			log.Printf("Failed to seed voucher %s: %v", v.Code, err)
		}
	}
}

func hasColumn(ctx context.Context, db *sql.DB, tableName, columnName string) (bool, error) {
	var count int
	err := db.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM information_schema.columns
		WHERE table_schema = DATABASE()
		  AND table_name = ?
		  AND column_name = ?
	`, tableName, columnName).Scan(&count)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return count > 0, nil
}
