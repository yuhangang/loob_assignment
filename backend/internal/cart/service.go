package cart

import (
	"context"
	"errors"
	"sort"
	"strings"
)

// CartRepository defines the persistence contract for the cart service.
type CartRepository interface {
	GetCart(ctx context.Context, userID, countryID string, overrideStoreID int) ([]CartItem, error)
	UpsertCartItem(ctx context.Context, item CartItem) (CartItem, error)
	UpdateCartItem(ctx context.Context, itemID int64, item CartItem) (CartItem, error)
	RemoveCartItem(ctx context.Context, itemID int64, userID, countryID string) error
	ClearCart(ctx context.Context, userID, countryID string) error
}

// Service owns all cart business logic.
type Service struct {
	repo          CartRepository
	publicBaseURL string
}

func NewService(repo CartRepository, publicBaseURL string) *Service {
	return &Service{repo: repo, publicBaseURL: publicBaseURL}
}

// GetCart returns the current cart contents for a user.
// When overrideStoreID > 0 the availability flags are evaluated against that
// store rather than the store_id stored in each cart row.
func (s *Service) GetCart(ctx context.Context, countryCode, userID string, overrideStoreID int) (CartResponse, error) {
	if strings.TrimSpace(userID) == "" {
		return CartResponse{}, ErrUserRequired
	}
	items, err := s.repo.GetCart(ctx, userID, countryCode, overrideStoreID)
	if err != nil {
		return CartResponse{}, err
	}
	return toCartResponse(countryCode, userID, items, s.publicBaseURL), nil
}

// UpsertItem adds a new item or updates the quantity of an existing identical item.
func (s *Service) UpsertItem(ctx context.Context, countryCode string, req CartItemRequest) (CartResponse, error) {
	if err := validateUpsert(req); err != nil {
		return CartResponse{}, err
	}

	item := requestToItem(countryCode, req)
	if _, err := s.repo.UpsertCartItem(ctx, item); err != nil {
		return CartResponse{}, err
	}

	// Return the refreshed cart (0 = use persisted store_id).
	return s.GetCart(ctx, countryCode, req.UserID, 0)
}

// UpdateItem replaces an existing cart line-item by ID.
func (s *Service) UpdateItem(ctx context.Context, countryCode string, itemID int64, req CartItemUpdateRequest) (CartResponse, error) {
	if itemID <= 0 {
		return CartResponse{}, ErrInvalidItemID
	}
	cartReq := CartItemRequest(req)
	if err := validateUpsert(cartReq); err != nil {
		return CartResponse{}, err
	}

	if _, err := s.repo.UpdateCartItem(ctx, itemID, requestToItem(countryCode, cartReq)); err != nil {
		if errors.Is(err, ErrNotFound) {
			return CartResponse{}, ErrNotFound
		}
		return CartResponse{}, err
	}
	return s.GetCart(ctx, countryCode, cartReq.UserID, 0)
}

// RemoveItem deletes a single line-item from the cart.
func (s *Service) RemoveItem(ctx context.Context, countryCode, userID string, itemID int64) (CartResponse, error) {
	if strings.TrimSpace(userID) == "" {
		return CartResponse{}, ErrUserRequired
	}
	if err := s.repo.RemoveCartItem(ctx, itemID, userID, countryCode); err != nil {
		if errors.Is(err, ErrNotFound) {
			return CartResponse{}, ErrNotFound
		}
		return CartResponse{}, err
	}
	return s.GetCart(ctx, countryCode, userID, 0)
}

// ClearCart wipes the entire cart for a user.
func (s *Service) ClearCart(ctx context.Context, countryCode, userID string) error {
	if strings.TrimSpace(userID) == "" {
		return ErrUserRequired
	}
	return s.repo.ClearCart(ctx, userID, countryCode)
}

// UpdateCart is the consolidated mutation endpoint.
// It dispatches to the correct operation based on req.Method.
func (s *Service) UpdateCart(ctx context.Context, countryCode string, req CartUpdateRequest) (CartResponse, error) {
	switch strings.ToLower(strings.TrimSpace(req.Method)) {
	case "upsert":
		return s.UpsertItem(ctx, countryCode, CartItemRequest{
			UserID:           req.UserID,
			StoreID:          req.StoreID,
			MenuItemID:       req.MenuItemID,
			Quantity:         req.Quantity,
			CustomizationIDs: req.CustomizationIDs,
		})
	case "update":
		return s.UpdateItem(ctx, countryCode, req.ItemID, CartItemUpdateRequest{
			UserID:           req.UserID,
			StoreID:          req.StoreID,
			MenuItemID:       req.MenuItemID,
			Quantity:         req.Quantity,
			CustomizationIDs: req.CustomizationIDs,
		})
	case "remove":
		return s.RemoveItem(ctx, countryCode, req.UserID, req.ItemID)
	case "clear":
		if err := s.ClearCart(ctx, countryCode, req.UserID); err != nil {
			return CartResponse{}, err
		}
		return s.GetCart(ctx, countryCode, req.UserID, 0)
	default:
		return CartResponse{}, ErrInvalidMethod
	}
}

// ── helpers ────────────────────────────────────────────────────────────────

func requestToItem(countryCode string, req CartItemRequest) CartItem {
	ids := make([]int, len(req.CustomizationIDs))
	copy(ids, req.CustomizationIDs)
	sort.Ints(ids)

	return CartItem{
		UserID:           req.UserID,
		CountryID:        countryCode,
		StoreID:          req.StoreID,
		MenuItemID:       req.MenuItemID,
		Quantity:         req.Quantity,
		CustomizationIDs: ids,
	}
}

func validateUpsert(req CartItemRequest) error {
	if strings.TrimSpace(req.UserID) == "" {
		return ErrUserRequired
	}
	if req.StoreID <= 0 {
		return ErrStoreRequired
	}
	if req.MenuItemID <= 0 || req.Quantity <= 0 {
		return ErrInvalidItem
	}
	seenOptions := map[int]bool{}
	for _, optionID := range req.CustomizationIDs {
		if optionID <= 0 || seenOptions[optionID] {
			return ErrInvalidItem
		}
		seenOptions[optionID] = true
	}
	return nil
}

func toCartResponse(countryID, userID string, items []CartItem, publicBaseURL string) CartResponse {
	resp := CartResponse{
		UserID:    userID,
		CountryID: countryID,
		Items:     make([]CartItemResponse, 0, len(items)),
	}
	for _, item := range items {
		ids := item.CustomizationIDs
		if ids == nil {
			ids = []int{}
		}
		options := make([]CartItemOptionResponse, 0, len(item.Options))
		for _, option := range item.Options {
			options = append(options, CartItemOptionResponse{
				ID:              option.ID,
				GroupID:         option.GroupID,
				Code:            option.Code,
				Name:            option.Name,
				PriceAdjustment: option.PriceAdjustment,
				IsAvailable:     option.IsAvailable,
			})
		}
		resp.Items = append(resp.Items, CartItemResponse{
			ID:               item.ID,
			MenuItemID:       item.MenuItemID,
			StoreID:          item.StoreID,
			Quantity:         item.Quantity,
			CustomizationIDs: ids,
			Name:             item.Name,
			ImageURLSm:       resolveAssetURL(publicBaseURL, item.ImageURLSm),
			BasePrice:        item.BasePrice,
			IsAvailable:      item.IsAvailable,
			Options:          options,
		})
	}
	return resp
}

// ── sentinel errors ────────────────────────────────────────────────────────

var (
	ErrUserRequired  = errors.New("user_id is required")
	ErrStoreRequired = errors.New("store_id is required")
	ErrInvalidItem   = errors.New("menu_item_id and positive quantity are required")
	ErrInvalidItemID = errors.New("valid cart item id is required")
	ErrNotFound      = errors.New("cart item not found")
	ErrInvalidMethod = errors.New("method must be one of: upsert, update, remove, clear")
)

func resolveAssetURL(publicBaseURL, path string) string {
	if path == "" {
		return ""
	}
	if strings.HasPrefix(path, "http://") || strings.HasPrefix(path, "https://") {
		return path
	}
	publicBaseURL = strings.TrimRight(publicBaseURL, "/")
	if strings.HasPrefix(path, "/") {
		return publicBaseURL + path
	}
	return publicBaseURL + "/" + path
}
