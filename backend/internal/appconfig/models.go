package appconfig

type AppConfig struct {
	AppName        string         `json:"app_name"`
	AppIcon        string         `json:"app_icon"`
	SplashScreen   SplashScreen   `json:"splash_screen"`
	SupportEmail   string         `json:"support_email"`
	Version        string         `json:"version"`
	FeatureToggles FeatureToggles `json:"feature_toggles"`
	MarketingPopup MarketingPopup `json:"marketing_popup"`
	ThemeConfig    ThemeConfig    `json:"theme_config"`
}

type SplashScreen struct {
	ImageURL        string `json:"image_url"`
	BackgroundColor string `json:"background_color"`
	DurationMs      int    `json:"duration_ms"`
}

type FeatureToggles struct {
	DeliveryEnabled bool `json:"delivery_enabled"`
	PickupEnabled   bool `json:"pickup_enabled"`
	RewardsEnabled  bool `json:"rewards_enabled"`
}

type MarketingPopup struct {
	Active      bool   `json:"active"`
	Title       string `json:"title"`
	Description string `json:"description"`
	ImageURL    string `json:"image_url"`
	ButtonText  string `json:"button_text"`
	Link        string `json:"link"`
}

type ThemeConfig struct {
	PrimaryColor   string `json:"primary_color"`
	AccentColor    string `json:"accent_color"`
	SecondaryColor string `json:"secondary_color"`
}

type FeedItem struct {
	ID          string `json:"id"`
	Type        string `json:"type"` // e.g., NEWS, PROMOTION, EVENT
	Title       string `json:"title"`
	Description string `json:"description"`
	ImageURL    string `json:"image_url"`
	Link        string `json:"link"`
}

type FeedResponse struct {
	Items []FeedItem `json:"items"`
}
