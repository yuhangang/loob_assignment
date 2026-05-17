package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"os"
	"path/filepath"
	"strings"

	"github.com/loob/backend/internal/database"
)

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

func main() {
	database.InitDB()
	db := database.DB

	country := strings.ToUpper(os.Getenv("COUNTRY"))

	if os.Getenv("CLEAN") == "true" {
		cleanDB(db, country)
	}

	seed(db, country)
	log.Printf("Seeding for %s completed successfully!", getCountryLabel(country))
}

func getCountryLabel(c string) string {
	if c == "" {
		return "ALL countries"
	}
	return c
}

func cleanDB(db *sql.DB, country string) {
	log.Printf("Cleaning database (Target: %s)...", getCountryLabel(country))
	_, _ = db.Exec("SET FOREIGN_KEY_CHECKS = 0")
	if country == "" {
		tables := []string{
			"order_intents", "wallet_accounts", "loyalty_accounts", "loyalty_checkins", "user_vouchers", "vouchers", "store_menu_item_status", "customization_options", "customization_groups",
			"menu_item_pricing", "menu_items", "categories", "stores", "zones",
			"brands", "users", "countries", "campaigns",
		}
		for _, table := range tables {
			_, _ = db.Exec(fmt.Sprintf("TRUNCATE TABLE %s", table))
		}
	} else {
		_, _ = db.Exec("DELETE smis FROM store_menu_item_status smis INNER JOIN stores s ON s.id = smis.store_id WHERE s.country_id = ?", country)
		_, _ = db.Exec("DELETE FROM menu_item_pricing WHERE zone_id IN (SELECT id FROM zones WHERE country_id = ?)", country)
		_, _ = db.Exec("DELETE FROM stores WHERE country_id = ?", country)
		_, _ = db.Exec("DELETE FROM zones WHERE country_id = ?", country)
		_, _ = db.Exec("DELETE FROM campaigns WHERE country_id = ?", country)
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

	seedVouchers(db, country)
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
			INSERT INTO menu_items (id, category_id, brand_id, item_type, sku_code, name_translations, desc_translations, image_url_sm, image_url_lg, dietary_tags)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
			ON DUPLICATE KEY UPDATE
				category_id = VALUES(category_id),
				brand_id = VALUES(brand_id),
				item_type = VALUES(item_type),
				name_translations = VALUES(name_translations),
				desc_translations = VALUES(desc_translations),
				image_url_sm = VALUES(image_url_sm),
				image_url_lg = VALUES(image_url_lg),
				dietary_tags = VALUES(dietary_tags),
				deleted_at = NULL,
				is_active = true
		`, it.ID, it.CID, it.BID, itemType, it.SKU, names, desc, it.ImageURLSmall, it.ImageURLLarge, tags)

		for _, z := range data.Zones {
			price := it.PriceMin + rand.Intn(it.PriceMax-it.PriceMin+1)
			_, _ = db.ExecContext(ctx, `
				INSERT INTO menu_item_pricing (menu_item_id, zone_id, base_price)
				VALUES (?, ?, ?)
				ON DUPLICATE KEY UPDATE base_price = VALUES(base_price)
			`, it.ID, z.ID, price)
		}
	}

	for _, it := range data.Items {
		if len(it.CustomizationGroups) > 0 {
			seedCustomizationGroups(db, it.ID, it.CustomizationGroups, itemIDsBySKU)
		}
	}

	seedStoreItemStatuses(db, data.StoreItemStatuses, storeIDs, itemIDsBySKU)
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

func seedVouchers(db *sql.DB, country string) {
	ctx := context.Background()
	log.Println("Seeding vouchers & mock user records...")

	// 1. Seed the main test user mock_user_001
	_, err := db.ExecContext(ctx, `
		INSERT INTO users (id, email, phone_number, preferred_language, registered_country_id)
		VALUES ('mock_user_001', 'mock_user_001@loob.com.my', '+60123456789', 'en-US', 'MY')
		ON DUPLICATE KEY UPDATE registered_country_id = 'MY'
	`)
	if err != nil {
		log.Printf("Failed to seed mock_user_001 user: %v", err)
	}

	// 2. Seed mock wallet account and loyalty points for mock_user_001
	_, err = db.ExecContext(ctx, `
		INSERT INTO wallet_accounts (user_id, country_id, balance, currency_code)
		VALUES ('mock_user_001', 'MY', 5000, 'MYR')
		ON DUPLICATE KEY UPDATE balance = 5000
	`)
	if err != nil {
		log.Printf("Failed to seed mock_user_001 wallet: %v", err)
	}

	_, err = db.ExecContext(ctx, `
		INSERT INTO loyalty_accounts (user_id, country_id, points, lifetime_points, tier)
		VALUES ('mock_user_001', 'MY', 120, 120, 'GOLD')
		ON DUPLICATE KEY UPDATE points = 120, tier = 'GOLD'
	`)
	if err != nil {
		log.Printf("Failed to seed mock_user_001 loyalty account: %v", err)
	}

	// 3. Define vouchers to seed
	type SeedVoucher struct {
		Code           string
		CountryID      string
		BrandID        *int
		VoucherType    string
		DiscountType   string
		DiscountValue  int
		MinSpend       int
		MaxDiscountCap *int
	}

	tealiveBrand := 1
	baskbearBrand := 2
	cap500 := 500
	cap1000 := 1000

	vouchersToSeed := []SeedVoucher{
		{
			Code:           "WELCOME10",
			CountryID:      "MY",
			VoucherType:    "CART_DISCOUNT",
			DiscountType:   "PERCENTAGE",
			DiscountValue:  10,
			MinSpend:       0,
			MaxDiscountCap: &cap500,
		},
		{
			Code:          "TEALIVE5",
			CountryID:     "MY",
			BrandID:       &tealiveBrand,
			VoucherType:   "BRAND_DISCOUNT",
			DiscountType:  "FIXED_AMOUNT",
			DiscountValue: 500,  // RM 5.00 off
			MinSpend:      1000, // Min spend RM 10.00
		},
		{
			Code:           "BASKBEAR30",
			CountryID:      "MY",
			BrandID:        &baskbearBrand,
			VoucherType:    "BRAND_DISCOUNT",
			DiscountType:   "PERCENTAGE",
			DiscountValue:  30,
			MinSpend:       1500,     // Min spend RM 15.00
			MaxDiscountCap: &cap1000, // RM 10.00 max cap
		},
		{
			Code:          "LOOBDELIGHT",
			CountryID:     "MY",
			VoucherType:   "CART_DISCOUNT",
			DiscountType:  "FIXED_AMOUNT",
			DiscountValue: 800,  // RM 8.00 off
			MinSpend:      2000, // Min spend RM 20.00
		},
		{
			Code:          "THAI_WELCOME",
			CountryID:     "TH",
			VoucherType:   "CART_DISCOUNT",
			DiscountType:  "PERCENTAGE",
			DiscountValue: 15,
			MinSpend:      0,
		},
	}

	for _, v := range vouchersToSeed {
		if country != "" && v.CountryID != country {
			continue
		}

		res, err := db.ExecContext(ctx, `
			INSERT INTO vouchers (
				code, country_id, brand_id, voucher_type, discount_type,
				discount_value, min_spend, max_discount_cap, starts_at, expires_at, is_active
			) VALUES (?, ?, ?, ?, ?, ?, ?, ?, '2026-01-01 00:00:00', '2030-01-01 00:00:00', true)
			ON DUPLICATE KEY UPDATE
				discount_value = VALUES(discount_value),
				min_spend = VALUES(min_spend),
				max_discount_cap = VALUES(max_discount_cap),
				is_active = true,
				id = LAST_INSERT_ID(id)
		`, v.Code, v.CountryID, v.BrandID, v.VoucherType, v.DiscountType, v.DiscountValue, v.MinSpend, v.MaxDiscountCap)
		if err != nil {
			log.Printf("Failed to seed voucher %s: %v", v.Code, err)
			continue
		}

		voucherID, _ := res.LastInsertId()
		if voucherID == 0 {
			_ = db.QueryRowContext(ctx, "SELECT id FROM vouchers WHERE code = ?", v.Code).Scan(&voucherID)
		}

		// Automatically link the voucher in user_vouchers for mock_user_001
		if v.CountryID == "MY" && voucherID > 0 {
			_, err = db.ExecContext(ctx, `
				INSERT INTO user_vouchers (user_id, voucher_id, status)
				VALUES ('mock_user_001', ?, 'AVAILABLE')
				ON DUPLICATE KEY UPDATE status = 'AVAILABLE'
			`, voucherID)
			if err != nil {
				log.Printf("Failed to link voucher %s to mock_user_001: %v", v.Code, err)
			}
		}
	}
}
