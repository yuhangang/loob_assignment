package users

type Profile struct {
	UserID              string `json:"user_id"`
	DisplayName         string `json:"display_name"`
	Email               string `json:"email,omitempty"`
	PhoneNumber         string `json:"phone_number,omitempty"`
	AvatarURL           string `json:"avatar_url,omitempty"`
	PreferredLanguage   string `json:"preferred_language"`
	RegisteredCountryID string `json:"registered_country_id"`
	MarketingOptIn      bool   `json:"marketing_opt_in"`
	WalletBalance       int    `json:"wallet_balance"`
	CurrencyCode        string `json:"currency_code"`
	LoyaltyPoints       int    `json:"loyalty_points"`
	LoyaltyTier         string `json:"loyalty_tier"`
}

type UpdateProfileRequest struct {
	DisplayName       *string `json:"display_name"`
	Email             *string `json:"email"`
	PhoneNumber       *string `json:"phone_number"`
	AvatarURL         *string `json:"avatar_url"`
	PreferredLanguage *string `json:"preferred_language"`
	MarketingOptIn    *bool   `json:"marketing_opt_in"`
}

type ProfileUpdate struct {
	DisplayName       string
	Email             string
	PhoneNumber       string
	AvatarURL         string
	PreferredLanguage string
	MarketingOptIn    bool
}
