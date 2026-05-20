package users

import "github.com/loob/backend/internal/payments"

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

type WalletTransaction struct {
	ID              int    `json:"id"`
	TransactionType string `json:"transaction_type"`
	Amount          int    `json:"amount"`
	BalanceAfter    int    `json:"balance_after"`
	CurrencyCode    string `json:"currency_code"`
	ReferenceType   string `json:"reference_type,omitempty"`
	ReferenceID     string `json:"reference_id,omitempty"`
	Description     string `json:"description,omitempty"`
	CreatedAt       string `json:"created_at"`
}

type LoyaltyTransaction struct {
	ID              int    `json:"id"`
	TransactionType string `json:"transaction_type"`
	PointsDelta     int    `json:"points_delta"`
	BalanceAfter    int    `json:"balance_after"`
	ReferenceType   string `json:"reference_type,omitempty"`
	ReferenceID     string `json:"reference_id,omitempty"`
	Description     string `json:"description,omitempty"`
	CreatedAt       string `json:"created_at"`
}

type WalletHistory struct {
	UserID       string              `json:"user_id"`
	CountryCode  string              `json:"country_code"`
	CurrencyCode string              `json:"currency_code"`
	Balance      int                 `json:"balance"`
	Transactions []WalletTransaction `json:"transactions"`
}

type LoyaltyHistory struct {
	UserID       string               `json:"user_id"`
	CountryCode  string               `json:"country_code"`
	Points       int                  `json:"points"`
	Tier         string               `json:"tier"`
	Transactions []LoyaltyTransaction `json:"transactions"`
}

type UpdateProfileRequest struct {
	DisplayName         *string `json:"display_name"`
	Email               *string `json:"email"`
	PhoneNumber         *string `json:"phone_number"`
	AvatarURL           *string `json:"avatar_url"`
	PreferredLanguage   *string `json:"preferred_language"`
	RegisteredCountryID *string `json:"registered_country_id"`
	MarketingOptIn      *bool   `json:"marketing_opt_in"`
}

type WalletTopUpRequest struct {
	Amount        int    `json:"amount"`
	Description   string `json:"description"`
	PaymentMethod string `json:"payment_method"`
}

type WalletTopUpResponse struct {
	Payment *payments.Transaction `json:"payment,omitempty"`
}

type ProfileUpdate struct {
	DisplayName         string
	Email               string
	PhoneNumber         string
	AvatarURL           string
	PreferredLanguage   string
	RegisteredCountryID string
	MarketingOptIn      bool
}
