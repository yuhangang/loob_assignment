package appconfig

type AppConfig struct {
	AppName      string       `json:"app_name"`
	AppIcon      string       `json:"app_icon"`
	SplashScreen SplashScreen `json:"splash_screen"`
	SupportEmail string       `json:"support_email"`
	Version      string       `json:"version"`
}

type SplashScreen struct {
	ImageURL        string `json:"image_url"`
	BackgroundColor string `json:"background_color"`
	DurationMs      int    `json:"duration_ms"`
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
