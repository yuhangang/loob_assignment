package checkout

type CheckoutRequest struct {
	UserID         string     `json:"user_id"`
	StoreID        int        `json:"store_id"`
	Fulfillment    string     `json:"fulfillment_type"`
	VoucherCode    string     `json:"voucher_code"`
	PaymentMethod  string     `json:"payment_method"`
	IdempotencyKey string     `json:"idempotency_key"`
	Items          []CartItem `json:"items"`
}

type CartItem struct {
	MenuItemID       int   `json:"menu_item_id"`
	Quantity         int   `json:"quantity"`
	CustomizationIDs []int `json:"customization_option_ids"`
}

type CheckoutResponse struct {
	Status          string                      `json:"status"`
	OrderTrackingID string                      `json:"order_tracking_id"`
	StatusURL       string                      `json:"status_url"`
	Subtotal        int                         `json:"subtotal"`
	Charges         []ChargeLineResponse        `json:"charges"`
	TaxAmount       int                         `json:"tax_amount"`
	DiscountAmount  int                         `json:"discount_amount"`
	TotalAmount     int                         `json:"total_amount"`
	Payment         *PaymentTransactionResponse `json:"payment,omitempty"`
}

type VoucherValidationRequest struct {
	UserID        string     `json:"user_id"`
	StoreID       int        `json:"store_id"`
	VoucherCode   string     `json:"voucher_code"`
	PaymentMethod string     `json:"payment_method"`
	Items         []CartItem `json:"items"`
}

type VoucherValidationResponse struct {
	Code             string `json:"code"`
	IsValid          bool   `json:"is_valid"`
	Reason           string `json:"reason,omitempty"`
	EligibleSubtotal int    `json:"eligible_subtotal"`
	DiscountAmount   int    `json:"discount_amount"`
}

type PaymentTransactionResponse struct {
	ID              string `json:"id"`
	Provider        string `json:"provider"`
	MethodCode      string `json:"method_code"`
	Status          string `json:"status"`
	CurrencyCode    string `json:"currency_code"`
	Amount          int    `json:"amount"`
	MockRedirectURL string `json:"mock_redirect_url"`
}

type ChargeLineResponse struct {
	Code          string `json:"code"`
	Name          string `json:"name"`
	Scope         string `json:"scope"`
	Amount        int    `json:"amount"`
	TaxableAmount int    `json:"taxable_amount"`
	TaxAmount     int    `json:"tax_amount"`
	TotalAmount   int    `json:"total_amount"`
	Taxable       bool   `json:"taxable"`
	TaxInclusive  bool   `json:"tax_inclusive"`
	Waived        bool   `json:"waived"`
	WaiverReason  string `json:"waiver_reason,omitempty"`
}

type OrderStatus struct {
	TrackingID     string               `json:"order_tracking_id"`
	Status         string               `json:"status"`
	PaymentStatus  string               `json:"payment_status"`
	Subtotal       int                  `json:"subtotal"`
	Charges        []ChargeLineResponse `json:"charges"`
	TaxAmount      int                  `json:"tax_amount"`
	DiscountAmount int                  `json:"discount_amount"`
	TotalAmount    int                  `json:"total_amount"`
	CreatedAt      string               `json:"created_at"`
	UpdatedAt      string               `json:"updated_at"`
}
