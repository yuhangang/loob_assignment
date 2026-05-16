package campaigns

type HomeFeed struct {
	CountryCode string     `json:"country_code"`
	Language    string     `json:"language_resolved"`
	Banners     []Campaign `json:"banners"`
	Modules     []Campaign `json:"modules"`
}

type Campaign struct {
	ID         int            `json:"id"`
	Type       string         `json:"type"`
	BrandID    *int           `json:"brand_id,omitempty"`
	Title      string         `json:"title"`
	Subtitle   string         `json:"subtitle"`
	ImageURL   string         `json:"image_url"`
	DeepLink   string         `json:"deep_link"`
	WebviewURL string         `json:"webview_url,omitempty"`
	Priority   int            `json:"priority"`
	Metadata   map[string]any `json:"metadata"`
}
