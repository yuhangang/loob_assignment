package catalog

type CategoryList struct {
	CatalogVersion string     `json:"catalog_version"`
	Brand          string     `json:"brand"`
	CountryCode    string     `json:"country_code"`
	Currency       string     `json:"currency"`
	TaxInclusive   bool       `json:"tax_inclusive"`
	Language       string     `json:"language_resolved"`
	Categories     []Category `json:"categories"`
}

type CategoryItems struct {
	CatalogVersion string    `json:"catalog_version"`
	Brand          string    `json:"brand"`
	CountryCode    string    `json:"country_code"`
	Currency       string    `json:"currency"`
	TaxInclusive   bool      `json:"tax_inclusive"`
	Language       string    `json:"language_resolved"`
	CategoryID     int       `json:"category_id"`
	Products       []Product `json:"products"`
}

type Category struct {
	ID           int       `json:"id"`
	DisplayOrder int       `json:"display_order"`
	Name         string    `json:"name"`
	IconURL      string    `json:"icon_url"`
	Products     []Product `json:"products,omitempty"`
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
	IsPromo             bool                 `json:"is_promo"`
}

type ProductAvailability struct {
	ItemID       int                         `json:"item_id"`
	StoreID      int                         `json:"store_id"`
	IsAvailable  bool                        `json:"is_available"`
	OptionStatus []CustomizationAvailability `json:"customization_options"`
}

type CustomizationAvailability struct {
	ID          int  `json:"id"`
	IsAvailable bool `json:"is_available"`
}

type Media struct {
	ImageURLSmall string `json:"image_url_sm"`
	ImageURLLarge string `json:"image_url_lg"`
}

type CustomizationGroup struct {
	Code          string                `json:"code"`
	ID            int                   `json:"id"`
	Type          string                `json:"type"`
	Required      bool                  `json:"required"`
	MinSelections int                   `json:"min_selections"`
	MaxSelections int                   `json:"max_selections"`
	Name          string                `json:"name"`
	Options       []CustomizationOption `json:"options"`
}

type CustomizationOption struct {
	Code            string `json:"code"`
	ID              int    `json:"id"`
	Name            string `json:"name"`
	PriceAdjustment int    `json:"price_adjustment"`
	IsDefault       bool   `json:"is_default"`
	IsAvailable     bool   `json:"is_available"`
}

type Brand struct {
	ID           int    `json:"id"`
	Slug         string `json:"slug"`
	Name         string `json:"name"`
	PrimaryColor string `json:"primary_color"`
	AccentColor  string `json:"accent_color"`
}

type Store struct {
	ID                int     `json:"id"`
	BrandID           int     `json:"brand_id"`
	CountryID         string  `json:"country_id"`
	ZoneID            string  `json:"zone_id"`
	StoreCode         string  `json:"store_code"`
	Name              string  `json:"name"`
	Latitude          float64 `json:"latitude"`
	Longitude         float64 `json:"longitude"`
	Address           string  `json:"address"`
	IsActive          bool    `json:"is_active"`
	OperationalStatus string  `json:"operational_status"`
	StatusMessage     string  `json:"status_message"`
}

type StoreListRequest struct {
	Page  int
	Limit int
}

type StoreListResponse struct {
	Items   []Store `json:"items"`
	Page    int     `json:"page"`
	Limit   int     `json:"limit"`
	HasMore bool    `json:"has_more"`
}
