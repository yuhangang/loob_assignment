package payments

type MockGatewayCallbackRequest struct {
	TransactionID    string         `json:"transaction_id"`
	GatewayReference string         `json:"gateway_reference"`
	GatewayEventID   string         `json:"gateway_event_id"`
	Status           string         `json:"status"`
	FailureReason    string         `json:"failure_reason"`
	Payload          map[string]any `json:"payload"`
}

type Transaction struct {
	ID                string `json:"id"`
	OrderTrackingID   string `json:"order_tracking_id"`
	Provider          string `json:"provider"`
	MethodCode        string `json:"method_code"`
	ProviderReference string `json:"provider_reference,omitempty"`
	Status            string `json:"status"`
	OrderStatus       string `json:"order_status"`
	CurrencyCode      string `json:"currency_code"`
	Amount            int    `json:"amount"`
	UpdatedAt         string `json:"updated_at"`
}

type StartPaymentRequest struct {
	OrderTrackingID string
	CountryID       string
	UserID          string
	BrandID         int
	MethodCode      string
	CurrencyCode    string
	Amount          int
}

type MethodSelection struct {
	Code         string
	ProviderCode string
	CurrencyCode string
}

type Provider struct {
	Code        string         `json:"code"`
	DisplayName string         `json:"display_name"`
	Type        string         `json:"type"`
	CallbackURL string         `json:"callback_url"`
	IsMock      bool           `json:"is_mock"`
	IsActive    bool           `json:"is_active"`
	Config      map[string]any `json:"config"`
}

type Method struct {
	ID           int            `json:"id"`
	Code         string         `json:"code"`
	ProviderCode string         `json:"provider_code"`
	CountryID    string         `json:"country_id"`
	BrandID      *int           `json:"brand_id,omitempty"`
	DisplayName  string         `json:"display_name"`
	Description  string         `json:"description"`
	CurrencyCode string         `json:"currency_code"`
	MinAmount    int            `json:"min_amount"`
	MaxAmount    *int           `json:"max_amount,omitempty"`
	DisplayOrder int            `json:"display_order"`
	Metadata     map[string]any `json:"metadata"`
}
