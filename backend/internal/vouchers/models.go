package vouchers

type Wallet struct {
	CountryCode   string    `json:"country_code"`
	Language      string    `json:"language_resolved"`
	UserID        string    `json:"user_id,omitempty"`
	CurrencyCode  string    `json:"currency_code"`
	WalletBalance int       `json:"wallet_balance"`
	LoyaltyPoints int       `json:"loyalty_points"`
	LoyaltyTier   string    `json:"loyalty_tier"`
	VoucherCount  int       `json:"voucher_count"`
	Vouchers      []Voucher `json:"vouchers"`
}

type Voucher struct {
	ID             int    `json:"id"`
	Code           string `json:"code"`
	Title          string `json:"title"`
	Description    string `json:"description"`
	VoucherType    string `json:"voucher_type"`
	DiscountType   string `json:"discount_type"`
	DiscountValue  int    `json:"discount_value"`
	MinSpend       int    `json:"min_spend"`
	MaxDiscountCap *int   `json:"max_discount_cap,omitempty"`
	BrandID        *int   `json:"brand_id,omitempty"`
	ZoneID         string `json:"zone_id,omitempty"`
	Status         string `json:"status"`
	StartsAt       string `json:"starts_at"`
	ExpiresAt      string `json:"expires_at"`
}
