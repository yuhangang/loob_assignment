package cart

// CartItemRequest is the payload for adding or updating a cart item.
type CartItemRequest struct {
	UserID           string `json:"user_id"`
	StoreID          int    `json:"store_id"`
	MenuItemID       int    `json:"menu_item_id"`
	Quantity         int    `json:"quantity"`
	CustomizationIDs []int  `json:"customization_option_ids"`
}

// CartItemUpdateRequest is the payload for replacing an existing cart line.
type CartItemUpdateRequest CartItemRequest

// CartItem is the internal representation of a cart line-item (from DB).
type CartItem struct {
	ID               int64
	UserID           string
	CountryID        string
	StoreID          int
	MenuItemID       int
	Quantity         int
	CustomizationIDs []int
	// Hydrated by joining menu_items / store_menu_item_status:
	Name        string
	ImageURLSm  string
	BasePrice   int
	IsAvailable bool
	Options     []CartItemOption
}

// CartItemOption is the server-hydrated snapshot for selected variants/addons.
type CartItemOption struct {
	ID              int
	GroupID         int
	Code            string
	Name            string
	PriceAdjustment int
	IsAvailable     bool
}

// CartItemResponse is a single item in the API response.
type CartItemResponse struct {
	ID               int64 `json:"id"`
	MenuItemID       int   `json:"menu_item_id"`
	StoreID          int   `json:"store_id"`
	Quantity         int   `json:"quantity"`
	CustomizationIDs []int `json:"customization_option_ids"`
	// Product snapshot so the client doesn't need a second catalog request:
	Name        string                   `json:"name"`
	ImageURLSm  string                   `json:"image_url_sm"`
	BasePrice   int                      `json:"base_price"`
	IsAvailable bool                     `json:"is_available"`
	Options     []CartItemOptionResponse `json:"customization_options"`
}

// CartItemOptionResponse is a selected variant/addon snapshot for display.
type CartItemOptionResponse struct {
	ID              int    `json:"id"`
	GroupID         int    `json:"group_id"`
	Code            string `json:"code"`
	Name            string `json:"name"`
	PriceAdjustment int    `json:"price_adjustment"`
	IsAvailable     bool   `json:"is_available"`
}

// CartResponse is the top-level API response for GET /cart.
type CartResponse struct {
	UserID    string             `json:"user_id"`
	CountryID string             `json:"country_id"`
	Items     []CartItemResponse `json:"items"`
}
