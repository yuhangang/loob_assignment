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
	Zones      []ZoneData     `json:"zones"`
	Stores     []StoreData    `json:"stores"`
	Categories []CategoryData `json:"categories"`
	Items      []ItemData     `json:"items"`
}

type ZoneData struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type StoreData struct {
	Name string `json:"name"`
	BID  int    `json:"bid"`
	ZID  string `json:"zid"`
}

type CategoryData struct {
	ID   int               `json:"id"`
	BID  int               `json:"bid"`
	Name map[string]string `json:"name"`
}

type ItemData struct {
	ID               int               `json:"id"`
	CID              int               `json:"cid"`
	SKU              string            `json:"sku"`
	Name             map[string]string `json:"name"`
	PriceMin         int               `json:"price_min"`
	PriceMax         int               `json:"price_max"`
	HasCustomization bool              `json:"has_customization"`
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
			"order_intents", "vouchers", "customization_options", "customization_groups",
			"menu_item_pricing", "menu_items", "categories", "stores", "zones",
			"brands", "users", "countries",
		}
		for _, table := range tables {
			_, _ = db.Exec(fmt.Sprintf("TRUNCATE TABLE %s", table))
		}
	} else {
		_, _ = db.Exec("DELETE FROM menu_item_pricing WHERE zone_id IN (SELECT id FROM zones WHERE country_id = ?)", country)
		_, _ = db.Exec("DELETE FROM stores WHERE country_id = ?", country)
		_, _ = db.Exec("DELETE FROM zones WHERE country_id = ?", country)
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
	}
	if country == "" || country == "TH" {
		var th RegionalData
		if err := loadJSON("th.json", &th); err != nil {
			log.Fatalf("Failed to load th.json: %v", err)
		}
		seedRegional(db, "TH", th)
	}
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
}

func seedRegional(db *sql.DB, cid string, data RegionalData) {
	ctx := context.Background()
	log.Printf("Seeding %s specific data...", cid)

	for _, z := range data.Zones {
		_, _ = db.ExecContext(ctx, "INSERT IGNORE INTO zones (id, country_id, name) VALUES (?, ?, ?)", z.ID, cid, z.Name)
	}

	for i, s := range data.Stores {
		code := fmt.Sprintf("%s-%03d", cid, i+1)
		names, _ := json.Marshal(map[string]string{"en-US": s.Name}) // Simplified for example
		tz := "Asia/Kuala_Lumpur"
		if cid == "TH" {
			tz = "Asia/Bangkok"
		}
		_, _ = db.ExecContext(ctx, `
			INSERT IGNORE INTO stores (brand_id, country_id, zone_id, store_code, name_translations, latitude, longitude, timezone)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		`, s.BID, cid, s.ZID, code, names, 3.1+rand.Float64(), 101.6+rand.Float64(), tz)
	}

	for _, c := range data.Categories {
		names, _ := json.Marshal(c.Name)
		_, _ = db.ExecContext(ctx, "INSERT IGNORE INTO categories (id, brand_id, name_translations, display_order) VALUES (?, ?, ?, ?)", c.ID, c.BID, names, c.ID)
	}

	for _, it := range data.Items {
		names, _ := json.Marshal(it.Name)
		_, _ = db.ExecContext(ctx, `
			INSERT IGNORE INTO menu_items (id, category_id, sku_code, name_translations)
			VALUES (?, ?, ?, ?)
		`, it.ID, it.CID, it.SKU, names)

		for _, z := range data.Zones {
			price := it.PriceMin + rand.Intn(it.PriceMax-it.PriceMin+1)
			_, _ = db.ExecContext(ctx, "INSERT IGNORE INTO menu_item_pricing (menu_item_id, zone_id, base_price) VALUES (?, ?, ?)", it.ID, z.ID, price)
		}

		if it.HasCustomization {
			seedCustomization(db, it.ID)
		}
	}
}

func seedCustomization(db *sql.DB, itemID int) {
	ctx := context.Background()
	nameJSON, _ := json.Marshal(map[string]string{"en-US": "Choose Size", "ms-MY": "Pilih Saiz", "th-TH": "เลือกขนาด"})
	res, err := db.ExecContext(ctx, `
		INSERT IGNORE INTO customization_groups (menu_item_id, name_translations, selection_type, is_required, max_selections)
		VALUES (?, ?, 'SINGLE_SELECT', true, 1)
	`, itemID, nameJSON)
	if err != nil || res == nil {
		return
	}
	gid, _ := res.LastInsertId()
	if gid == 0 {
		return // row already existed, INSERT IGNORE returned 0
	}

	opts := []struct {
		en, ms, th string
		price      int
		def        bool
	}{
		{"Regular", "Biasa", "ปกติ", 0, true},
		{"Large", "Besar", "ใหญ่", 150, false},
	}
	for _, o := range opts {
		optNames, _ := json.Marshal(map[string]string{"en-US": o.en, "ms-MY": o.ms, "th-TH": o.th})
		_, _ = db.ExecContext(ctx, "INSERT INTO customization_options (group_id, name_translations, price_adjustment, is_default) VALUES (?, ?, ?, ?)", gid, optNames, o.price, o.def)
	}
}
