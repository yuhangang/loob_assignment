package catalog

type Catalog struct {
	CatalogVersion string     `json:"catalog_version"`
	Brand          string     `json:"brand"`
	CountryCode    string     `json:"country_code"`
	Currency       string     `json:"currency"`
	TaxInclusive   bool       `json:"tax_inclusive"`
	Language       string     `json:"language_resolved"`
	Categories     []Category `json:"categories"`
}

type Category struct {
	ID           int       `json:"id"`
	DisplayOrder int       `json:"display_order"`
	Name         string    `json:"name"`
	Products     []Product `json:"products"`
}

type Product struct {
	ID                  int                  `json:"id"`
	SKUCode             string               `json:"sku_code"`
	IsAvailable         bool                 `json:"is_available"`
	Name                string               `json:"name"`
	Description         string               `json:"description"`
	Media               Media                `json:"media"`
	BasePrice           int                  `json:"base_price"`
	DietaryTags         []string             `json:"dietary_tags"`
	CustomizationGroups []CustomizationGroup `json:"customization_groups"`
}

type Media struct {
	ImageURLSmall string `json:"image_url_sm"`
	ImageURLLarge string `json:"image_url_lg"`
}

type CustomizationGroup struct {
	ID            int                   `json:"id"`
	Type          string                `json:"type"`
	Required      bool                  `json:"required"`
	MaxSelections int                   `json:"max_selections"`
	Name          string                `json:"name"`
	Options       []CustomizationOption `json:"options"`
}

type CustomizationOption struct {
	ID              int    `json:"id"`
	Name            string `json:"name"`
	PriceAdjustment int    `json:"price_adjustment"`
	IsDefault       bool   `json:"is_default"`
}

type Brand struct {
	ID           int    `json:"id"`
	Slug         string `json:"slug"`
	Name         string `json:"name"`
	PrimaryColor string `json:"primary_color"`
	AccentColor  string `json:"accent_color"`
}

type Store struct {
	ID        int     `json:"id"`
	BrandID   int     `json:"brand_id"`
	CountryID string  `json:"country_id"`
	ZoneID    string  `json:"zone_id"`
	StoreCode string  `json:"store_code"`
	Name      string  `json:"name"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Address   string  `json:"address"`
	IsActive  bool    `json:"is_active"`
}
