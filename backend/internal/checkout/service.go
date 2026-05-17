package checkout

import (
	"context"
	"encoding/json"
	"errors"
	"math"
	"strings"

	"github.com/loob/backend/internal/payments"
	"github.com/loob/backend/internal/platform"
)

type CheckoutRepository interface {
	GetCountry(ctx context.Context, countryID string) (Country, error)
	GetStore(ctx context.Context, countryID string, storeID int) (Store, error)
	UpsertUser(ctx context.Context, userID, countryID string) error
	GetPricedItems(ctx context.Context, storeID int, zoneID string, itemIDs []int) (map[int]PricedItem, error)
	GetOptionPrices(ctx context.Context, storeID int, zoneID string, optionIDs []int) (map[int]OptionPrice, error)
	GetCustomizationRules(ctx context.Context, menuItemIDs []int) ([]CustomizationGroupRule, map[int]CustomizationOptionRule, error)
	GetVoucher(ctx context.Context, countryID, code string) (Voucher, error)
	FindIntentByIdempotency(ctx context.Context, countryID, userID, key string) (IntentWithPayment, error)
	CreateIntentWithPayment(ctx context.Context, intent Intent, payment PaymentTransaction) error
	CreatePaymentIfMissing(ctx context.Context, payment PaymentTransaction) (PaymentTransaction, error)
	GetStatus(ctx context.Context, countryID, trackingID string) (Status, error)
	ListStatusesByUser(ctx context.Context, countryID, userID string) ([]Status, error)
}

type Service struct {
	repo     CheckoutRepository
	payments PaymentStarter
}

type CheckoutContext struct {
	TraceID     string
	CountryCode string
}

type PaymentStarter interface {
	ValidateMethod(ctx context.Context, req payments.StartPaymentRequest) (payments.MethodSelection, error)
}

func NewService(repo CheckoutRepository, payments PaymentStarter) *Service {
	return &Service{repo: repo, payments: payments}
}

func (s *Service) Checkout(ctx context.Context, rc CheckoutContext, req CheckoutRequest) (CheckoutResponse, error) {
	if err := validate(req); err != nil {
		return CheckoutResponse{}, err
	}

	existing, err := s.repo.FindIntentByIdempotency(ctx, rc.CountryCode, req.UserID, req.IdempotencyKey)
	if err == nil {
		if existing.Payment.ID == "" {
			return s.createMissingPayment(ctx, existing.Intent, req.PaymentMethod)
		}
		return responseFromIntent(existing), nil
	}
	if !errors.Is(err, ErrNotFound) {
		return CheckoutResponse{}, err
	}

	country, err := s.repo.GetCountry(ctx, rc.CountryCode)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return CheckoutResponse{}, ErrUnsupportedCountry
		}
		return CheckoutResponse{}, err
	}

	store, err := s.repo.GetStore(ctx, rc.CountryCode, req.StoreID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return CheckoutResponse{}, ErrStoreNotFound
		}
		return CheckoutResponse{}, err
	}
	if !store.AcceptsOrders() {
		return CheckoutResponse{}, ErrStoreClosed
	}

	if err := s.repo.UpsertUser(ctx, req.UserID, rc.CountryCode); err != nil {
		return CheckoutResponse{}, err
	}

	itemIDs := uniqueItemIDs(req.Items)
	pricedItems, err := s.repo.GetPricedItems(ctx, store.ID, store.ZoneID, itemIDs)
	if err != nil {
		return CheckoutResponse{}, err
	}
	if len(pricedItems) != len(itemIDs) {
		return CheckoutResponse{}, ErrItemUnavailable
	}

	optionIDs := uniqueOptionIDs(req.Items)
	optionPrices, err := s.repo.GetOptionPrices(ctx, store.ID, store.ZoneID, optionIDs)
	if err != nil {
		return CheckoutResponse{}, err
	}
	if len(optionPrices) != len(optionIDs) {
		return CheckoutResponse{}, ErrInvalidCustomization
	}
	groups, optionRules, err := s.repo.GetCustomizationRules(ctx, itemIDs)
	if err != nil {
		return CheckoutResponse{}, err
	}
	if err := validateCustomizations(req.Items, groups, optionRules); err != nil {
		return CheckoutResponse{}, err
	}

	subtotal := 0
	for _, item := range req.Items {
		pricedItem := pricedItems[item.MenuItemID]
		lineUnitPrice := pricedItem.BasePrice
		for _, optionID := range item.CustomizationIDs {
			option := optionPrices[optionID]
			if option.MenuItemID != item.MenuItemID {
				return CheckoutResponse{}, ErrInvalidCustomization
			}
			lineUnitPrice += option.PriceAdjustment
		}
		subtotal += lineUnitPrice * item.Quantity
	}

	discount := 0
	if strings.TrimSpace(req.VoucherCode) != "" {
		discount, err = s.discount(ctx, rc.CountryCode, req.VoucherCode, subtotal, pricedItems)
		if err != nil {
			return CheckoutResponse{}, err
		}
	}

	taxAmount := int(math.Round(float64(subtotal-discount) * country.TaxRate))
	total := subtotal - discount + taxAmount
	if total < 0 {
		total = 0
	}

	paymentReq := payments.StartPaymentRequest{
		CountryID:    rc.CountryCode,
		UserID:       req.UserID,
		BrandID:      store.BrandID,
		MethodCode:   req.PaymentMethod,
		CurrencyCode: country.Currency,
		Amount:       total,
	}
	method, err := s.payments.ValidateMethod(ctx, paymentReq)
	if err != nil {
		if errors.Is(err, payments.ErrPaymentMethodUnavailable) {
			return CheckoutResponse{}, ErrPaymentMethodUnavailable
		}
		return CheckoutResponse{}, err
	}

	cartPayload, err := json.Marshal(req.Items)
	if err != nil {
		return CheckoutResponse{}, err
	}

	intent := Intent{
		TrackingID:     platform.NewTrackingID(rc.CountryCode),
		TraceID:        rc.TraceID,
		IdempotencyKey: req.IdempotencyKey,
		UserID:         req.UserID,
		StoreID:        req.StoreID,
		CountryID:      rc.CountryCode,
		Fulfillment:    req.Fulfillment,
		Status:         "PAYMENT_PENDING",
		Subtotal:       subtotal,
		TaxAmount:      taxAmount,
		DiscountAmount: discount,
		TotalAmount:    total,
		VoucherCode:    strings.TrimSpace(req.VoucherCode),
		CartPayload:    cartPayload,
	}
	payment := PaymentTransaction{
		ID:              platform.NewPaymentID(rc.CountryCode),
		OrderTrackingID: intent.TrackingID,
		CountryID:       rc.CountryCode,
		UserID:          req.UserID,
		Provider:        method.ProviderCode,
		MethodCode:      method.Code,
		Status:          "PENDING",
		CurrencyCode:    method.CurrencyCode,
		Amount:          total,
	}
	if err := s.repo.CreateIntentWithPayment(ctx, intent, payment); err != nil {
		duplicate, findErr := s.repo.FindIntentByIdempotency(ctx, rc.CountryCode, req.UserID, req.IdempotencyKey)
		if findErr == nil {
			if duplicate.Payment.ID == "" {
				return s.createMissingPayment(ctx, duplicate.Intent, req.PaymentMethod)
			}
			return responseFromIntent(duplicate), nil
		}
		return CheckoutResponse{}, err
	}

	return responseFromIntent(IntentWithPayment{Intent: intent, Payment: payment}), nil
}

func (s *Service) createMissingPayment(ctx context.Context, intent Intent, methodCode string) (CheckoutResponse, error) {
	country, err := s.repo.GetCountry(ctx, intent.CountryID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return CheckoutResponse{}, ErrUnsupportedCountry
		}
		return CheckoutResponse{}, err
	}
	store, err := s.repo.GetStore(ctx, intent.CountryID, intent.StoreID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return CheckoutResponse{}, ErrStoreNotFound
		}
		return CheckoutResponse{}, err
	}
	if !store.AcceptsOrders() {
		return CheckoutResponse{}, ErrStoreClosed
	}
	method, err := s.payments.ValidateMethod(ctx, payments.StartPaymentRequest{
		OrderTrackingID: intent.TrackingID,
		CountryID:       intent.CountryID,
		UserID:          intent.UserID,
		BrandID:         store.BrandID,
		MethodCode:      methodCode,
		CurrencyCode:    country.Currency,
		Amount:          intent.TotalAmount,
	})
	if err != nil {
		if errors.Is(err, payments.ErrPaymentMethodUnavailable) {
			return CheckoutResponse{}, ErrPaymentMethodUnavailable
		}
		return CheckoutResponse{}, err
	}
	payment := PaymentTransaction{
		ID:              platform.NewPaymentID(intent.CountryID),
		OrderTrackingID: intent.TrackingID,
		CountryID:       intent.CountryID,
		UserID:          intent.UserID,
		Provider:        method.ProviderCode,
		MethodCode:      method.Code,
		Status:          "PENDING",
		CurrencyCode:    method.CurrencyCode,
		Amount:          intent.TotalAmount,
	}
	payment, err = s.repo.CreatePaymentIfMissing(ctx, payment)
	if err != nil {
		return CheckoutResponse{}, err
	}
	return responseFromIntent(IntentWithPayment{Intent: intent, Payment: payment}), nil
}

func (s *Service) GetStatus(ctx context.Context, countryID, trackingID string) (OrderStatus, error) {
	status, err := s.repo.GetStatus(ctx, countryID, trackingID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return OrderStatus{}, ErrOrderNotFound
		}
		return OrderStatus{}, err
	}
	return orderStatusFromRow(status), nil
}

func (s *Service) ListOrders(ctx context.Context, countryID, userID string) ([]OrderStatus, error) {
	if strings.TrimSpace(userID) == "" {
		return nil, ErrUserRequired
	}
	statuses, err := s.repo.ListStatusesByUser(ctx, countryID, userID)
	if err != nil {
		return nil, err
	}
	orders := make([]OrderStatus, 0, len(statuses))
	for _, status := range statuses {
		orders = append(orders, orderStatusFromRow(status))
	}
	return orders, nil
}

func (s *Service) discount(ctx context.Context, countryID, code string, subtotal int, items map[int]PricedItem) (int, error) {
	voucher, err := s.repo.GetVoucher(ctx, countryID, strings.ToUpper(strings.TrimSpace(code)))
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return 0, ErrVoucherNotFound
		}
		return 0, err
	}
	if subtotal < voucher.MinSpend {
		return 0, ErrVoucherNotEligible
	}
	if voucher.BrandID.Valid {
		hasBrand := false
		for _, item := range items {
			if int64(item.BrandID) == voucher.BrandID.Int64 {
				hasBrand = true
				break
			}
		}
		if !hasBrand {
			return 0, ErrVoucherNotEligible
		}
	}

	var discount int
	switch voucher.DiscountType {
	case "PERCENTAGE":
		discount = int(math.Round(float64(subtotal) * float64(voucher.DiscountValue) / 100))
		if voucher.MaxDiscountCap.Valid && discount > int(voucher.MaxDiscountCap.Int64) {
			discount = int(voucher.MaxDiscountCap.Int64)
		}
	case "FIXED_AMOUNT":
		discount = voucher.DiscountValue
	}
	if discount > subtotal {
		return subtotal, nil
	}
	return discount, nil
}

func orderStatusFromRow(status Status) OrderStatus {
	return OrderStatus{
		TrackingID:     status.TrackingID,
		Status:         status.Status,
		PaymentStatus:  status.PaymentStatus.String,
		Subtotal:       status.Subtotal,
		TaxAmount:      status.TaxAmount,
		DiscountAmount: status.DiscountAmount,
		TotalAmount:    status.TotalAmount,
		CreatedAt:      status.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt:      status.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}

func validate(req CheckoutRequest) error {
	if strings.TrimSpace(req.UserID) == "" {
		return ErrUserRequired
	}
	if strings.TrimSpace(req.IdempotencyKey) == "" {
		return ErrIdempotencyRequired
	}
	if req.StoreID <= 0 {
		return ErrStoreRequired
	}
	switch req.Fulfillment {
	case "DINE_IN", "TAKEAWAY", "DELIVERY":
	default:
		return ErrInvalidFulfillment
	}
	if len(req.Items) == 0 {
		return ErrCartEmpty
	}
	for _, item := range req.Items {
		if item.MenuItemID <= 0 || item.Quantity <= 0 {
			return ErrInvalidCartItem
		}
	}
	return nil
}

func validateCustomizations(items []CartItem, groups []CustomizationGroupRule, options map[int]CustomizationOptionRule) error {
	groupsByItem := map[int][]CustomizationGroupRule{}
	for _, group := range groups {
		groupsByItem[group.MenuItemID] = append(groupsByItem[group.MenuItemID], group)
	}

	for _, item := range items {
		selectedByGroup := map[int]int{}
		seenOptions := map[int]bool{}
		for _, optionID := range item.CustomizationIDs {
			if optionID <= 0 || seenOptions[optionID] {
				return ErrInvalidCustomization
			}
			seenOptions[optionID] = true
			option, ok := options[optionID]
			if !ok || option.MenuItemID != item.MenuItemID {
				return ErrInvalidCustomization
			}
			selectedByGroup[option.GroupID]++
		}

		for _, group := range groupsByItem[item.MenuItemID] {
			count := selectedByGroup[group.ID]
			minSelections := group.MinSelections
			if minSelections == 0 && group.IsRequired {
				minSelections = 1
			}
			if count < minSelections {
				return ErrInvalidCustomization
			}
			if group.SelectionType == "SINGLE_SELECT" && count > 1 {
				return ErrInvalidCustomization
			}
			if group.MaxSelections > 0 && count > group.MaxSelections {
				return ErrInvalidCustomization
			}
		}
	}
	return nil
}

func responseFromIntent(intentWithPayment IntentWithPayment) CheckoutResponse {
	intent := intentWithPayment.Intent
	payment := intentWithPayment.Payment
	var responsePayment *PaymentTransactionResponse
	if payment.ID != "" {
		responsePayment = &PaymentTransactionResponse{
			ID:              payment.ID,
			Provider:        payment.Provider,
			MethodCode:      payment.MethodCode,
			Status:          payment.Status,
			CurrencyCode:    payment.CurrencyCode,
			Amount:          payment.Amount,
			MockRedirectURL: "/mock-gateway/pay/" + payment.ID,
		}
	}
	return CheckoutResponse{
		Status:          intent.Status,
		OrderTrackingID: intent.TrackingID,
		StatusURL:       "/api/v1/orders/" + intent.TrackingID + "/status",
		Subtotal:        intent.Subtotal,
		TaxAmount:       intent.TaxAmount,
		DiscountAmount:  intent.DiscountAmount,
		TotalAmount:     intent.TotalAmount,
		Payment:         responsePayment,
	}
}

func uniqueItemIDs(items []CartItem) []int {
	seen := map[int]bool{}
	var ids []int
	for _, item := range items {
		if !seen[item.MenuItemID] {
			seen[item.MenuItemID] = true
			ids = append(ids, item.MenuItemID)
		}
	}
	return ids
}

func uniqueOptionIDs(items []CartItem) []int {
	seen := map[int]bool{}
	var ids []int
	for _, item := range items {
		for _, id := range item.CustomizationIDs {
			if !seen[id] {
				seen[id] = true
				ids = append(ids, id)
			}
		}
	}
	return ids
}

var (
	ErrUserRequired             = errors.New("user_id is required")
	ErrIdempotencyRequired      = errors.New("idempotency_key is required")
	ErrStoreRequired            = errors.New("store_id is required")
	ErrInvalidFulfillment       = errors.New("fulfillment_type must be DINE_IN, TAKEAWAY, or DELIVERY")
	ErrCartEmpty                = errors.New("cart must contain at least one item")
	ErrInvalidCartItem          = errors.New("cart item must include menu_item_id and positive quantity")
	ErrUnsupportedCountry       = errors.New("unsupported country")
	ErrStoreNotFound            = errors.New("store not found")
	ErrStoreClosed              = errors.New("selected store is closed")
	ErrItemUnavailable          = errors.New("menu item unavailable")
	ErrInvalidCustomization     = errors.New("invalid customization")
	ErrVoucherNotFound          = errors.New("voucher not found")
	ErrVoucherNotEligible       = errors.New("voucher not eligible")
	ErrOrderNotFound            = errors.New("order not found")
	ErrPaymentMethodUnavailable = errors.New("payment method unavailable")
)
