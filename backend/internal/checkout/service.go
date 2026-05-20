package checkout

import (
	"context"
	"encoding/json"
	"errors"
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
	GetVoucher(ctx context.Context, countryID, userID, code string) (Voucher, error)
	ListChargeDefinitions(ctx context.Context, countryID string, store Store, fulfillment string) ([]ChargeDefinition, error)
	FindIntentByIdempotency(ctx context.Context, countryID, userID, key string) (IntentWithPayment, error)
	CreateIntentWithPayment(ctx context.Context, intent Intent, payment PaymentTransaction) error
	CreatePaymentIfMissing(ctx context.Context, payment PaymentTransaction) (PaymentTransaction, error)
	GetStatus(ctx context.Context, countryID, trackingID string) (Status, error)
	GetStatusForUser(ctx context.Context, countryID, userID, trackingID string) (Status, error)
	ListStatusesByUser(ctx context.Context, countryID, userID string, statuses []string, limit, offset int) ([]Status, error)
	GetMenuItemNames(ctx context.Context, itemIDs []int) (map[int]string, error)
	GetOptionNames(ctx context.Context, optionIDs []int) (map[int]string, error)
	MarkOrderCollected(ctx context.Context, countryID, userID, trackingID string) error
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

	taxRateBps := taxRateBasisPoints(country.TaxRate)
	subtotal := 0
	lines := make([]pricedCartLine, 0, len(req.Items))
	for _, item := range req.Items {
		pricedItem := pricedItems[item.MenuItemID]
		lineUnitPrice := pricedItem.BasePrice
		lineInclusiveUnitPrice := 0
		lineExclusiveUnitPrice := 0
		if pricedItem.TaxInclusive {
			lineInclusiveUnitPrice += pricedItem.BasePrice
		} else {
			lineExclusiveUnitPrice += pricedItem.BasePrice
		}
		for _, optionID := range item.CustomizationIDs {
			option := optionPrices[optionID]
			if option.MenuItemID != item.MenuItemID {
				return CheckoutResponse{}, ErrInvalidCustomization
			}
			lineUnitPrice += option.PriceAdjustment
			if option.TaxInclusive {
				lineInclusiveUnitPrice += option.PriceAdjustment
			} else {
				lineExclusiveUnitPrice += option.PriceAdjustment
			}
		}
		lineSubtotal := lineUnitPrice * item.Quantity
		subtotal += lineSubtotal
		lines = append(lines, pricedCartLine{
			MenuItemID:        item.MenuItemID,
			CategoryID:        pricedItem.CategoryID,
			BrandID:           pricedItem.BrandID,
			Quantity:          item.Quantity,
			Subtotal:          lineSubtotal,
			TaxInclusiveGross: lineInclusiveUnitPrice * item.Quantity,
			TaxExclusiveNet:   lineExclusiveUnitPrice * item.Quantity,
			IsPromoItem:       pricedItem.IsPromoItem,
		})
	}

	discount := 0
	if strings.TrimSpace(req.VoucherCode) != "" {
		discount, err = s.discount(ctx, voucherEligibilityRequest{
			CountryID:     rc.CountryCode,
			UserID:        req.UserID,
			Code:          req.VoucherCode,
			StoreID:       store.ID,
			ZoneID:        store.ZoneID,
			PaymentMethod: req.PaymentMethod,
			Subtotal:      subtotal,
			Lines:         lines,
		})
		if err != nil {
			return CheckoutResponse{}, err
		}
	}

	chargeDefinitions, err := s.repo.ListChargeDefinitions(ctx, rc.CountryCode, store, req.Fulfillment)
	if err != nil {
		return CheckoutResponse{}, err
	}
	charges := calculateCharges(chargeDefinitions, chargeCalculationRequest{
		Subtotal:   subtotal,
		TaxRateBps: taxRateBps,
	})
	itemTotals := calculateItemTotals(lines, subtotal, discount, taxRateBps)
	chargeTotalAmount := 0
	chargeTaxAmount := 0
	for _, charge := range charges {
		chargeTotalAmount += charge.TotalAmount
		chargeTaxAmount += charge.TaxAmount
	}
	taxAmount := itemTotals.TaxAmount + chargeTaxAmount
	total := itemTotals.TotalAmount + chargeTotalAmount

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
		Charges:        charges,
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

type itemTotals struct {
	TaxAmount   int
	TotalAmount int
}

func calculateItemTotals(lines []pricedCartLine, subtotal int, discount int, taxRateBps int) itemTotals {
	discountedSubtotal := subtotal - discount
	if discountedSubtotal < 0 {
		discountedSubtotal = 0
	}
	if subtotal <= 0 {
		return itemTotals{}
	}

	inclusiveGross := 0
	exclusiveNet := 0
	for _, line := range lines {
		inclusiveGross += line.TaxInclusiveGross
		exclusiveNet += line.TaxExclusiveNet
	}

	discountedInclusiveGross := prorateAmount(inclusiveGross, discountedSubtotal, subtotal)
	discountedExclusiveNet := discountedSubtotal - discountedInclusiveGross
	if discountedExclusiveNet < 0 {
		discountedExclusiveNet = 0
	}

	inclusiveTax := discountedInclusiveGross - netFromTaxInclusive(discountedInclusiveGross, taxRateBps)
	exclusiveTax := taxFromNet(discountedExclusiveNet, taxRateBps)
	return itemTotals{
		TaxAmount:   inclusiveTax + exclusiveTax,
		TotalAmount: discountedInclusiveGross + discountedExclusiveNet + exclusiveTax,
	}
}

func taxRateBasisPoints(rate float64) int {
	if rate <= 0 {
		return 0
	}
	return int(rate*10000 + 0.5)
}

func taxFromNet(amount int, taxRateBps int) int {
	if amount <= 0 || taxRateBps <= 0 {
		return 0
	}
	return (amount*taxRateBps + 5000) / 10000
}

func netFromTaxInclusive(gross int, taxRateBps int) int {
	if gross <= 0 || taxRateBps <= 0 {
		return gross
	}
	denominator := 10000 + taxRateBps
	return (gross*10000 + denominator/2) / denominator
}

func prorateAmount(amount int, numerator int, denominator int) int {
	if amount <= 0 || numerator <= 0 || denominator <= 0 {
		return 0
	}
	return (amount*numerator + denominator/2) / denominator
}

type chargeCalculationRequest struct {
	Subtotal   int
	TaxRateBps int
}

func calculateCharges(definitions []ChargeDefinition, req chargeCalculationRequest) []ChargeLine {
	lines := make([]ChargeLine, 0, len(definitions))
	for _, definition := range definitions {
		if definition.CalculationType != "FIXED_AMOUNT" || definition.Amount <= 0 {
			continue
		}
		line := ChargeLine{
			Code:         definition.Code,
			Name:         definition.Name,
			Scope:        definition.Scope,
			Taxable:      definition.Taxable,
			TaxInclusive: definition.TaxInclusive,
		}
		if definition.WaiverMinSubtotal.Valid && req.Subtotal >= int(definition.WaiverMinSubtotal.Int64) {
			line.Waived = true
			line.WaiverReason = definition.WaiverReason.String
			lines = append(lines, line)
			continue
		}
		if definition.Taxable && definition.TaxInclusive {
			gross := definition.Amount
			net := netFromTaxInclusive(gross, req.TaxRateBps)
			line.Amount = net
			line.TaxableAmount = net
			line.TaxAmount = gross - net
			line.TotalAmount = gross
			lines = append(lines, line)
			continue
		}
		line.Amount = definition.Amount
		line.TotalAmount = definition.Amount
		if definition.Taxable {
			line.TaxableAmount = definition.Amount
			line.TaxAmount = taxFromNet(definition.Amount, req.TaxRateBps)
			line.TotalAmount += line.TaxAmount
		}
		lines = append(lines, line)
	}
	return lines
}

func (s *Service) populateItems(ctx context.Context, countryID string, status Status) ([]OrderStatusItem, error) {
	if len(status.CartPayload) == 0 {
		return []OrderStatusItem{}, nil
	}
	var cartItems []CartItem
	if err := json.Unmarshal(status.CartPayload, &cartItems); err != nil {
		return []OrderStatusItem{}, nil
	}
	if len(cartItems) == 0 {
		return []OrderStatusItem{}, nil
	}

	store, err := s.repo.GetStore(ctx, countryID, status.StoreID)
	if err != nil {
		return nil, err
	}

	itemIDs := make([]int, len(cartItems))
	for i, item := range cartItems {
		itemIDs[i] = item.MenuItemID
	}

	// 1. Fetch menu item names
	names, err := s.repo.GetMenuItemNames(ctx, itemIDs)
	if err != nil {
		return nil, err
	}

	// 2. Fetch menu item base prices
	pricedItems, err := s.repo.GetPricedItems(ctx, store.ID, store.ZoneID, itemIDs)
	if err != nil {
		pricedItems = map[int]PricedItem{}
	}

	// 3. Collect option IDs
	optionIDs := []int{}
	for _, item := range cartItems {
		optionIDs = append(optionIDs, item.CustomizationIDs...)
	}

	// 4. Fetch option prices & names
	optionPrices := map[int]OptionPrice{}
	optionNames := map[int]string{}
	if len(optionIDs) > 0 {
		if prices, err := s.repo.GetOptionPrices(ctx, store.ID, store.ZoneID, optionIDs); err == nil {
			optionPrices = prices
		}
		if nms, err := s.repo.GetOptionNames(ctx, optionIDs); err == nil {
			optionNames = nms
		}
	}

	// 5. Construct OrderStatusItems
	statusItems := make([]OrderStatusItem, len(cartItems))
	for i, item := range cartItems {
		name := names[item.MenuItemID]
		if name == "" {
			name = "Unknown Item"
		}
		basePrice := 0
		if pi, ok := pricedItems[item.MenuItemID]; ok {
			basePrice = pi.BasePrice
		}

		options := make([]OrderStatusItemOption, 0, len(item.CustomizationIDs))
		for _, optID := range item.CustomizationIDs {
			optName := optionNames[optID]
			if optName == "" {
				optName = "Unknown Option"
			}
			priceAdj := 0
			groupID := 0
			if optPrice, ok := optionPrices[optID]; ok {
				priceAdj = optPrice.PriceAdjustment
				groupID = optPrice.GroupID
			}
			options = append(options, OrderStatusItemOption{
				ID:              optID,
				GroupID:         groupID,
				Name:            optName,
				PriceAdjustment: priceAdj,
			})
		}

		statusItems[i] = OrderStatusItem{
			MenuItemID: item.MenuItemID,
			Name:       name,
			Quantity:   item.Quantity,
			BasePrice:  basePrice,
			Options:    options,
		}
	}
	return statusItems, nil
}

func (s *Service) GetStatus(ctx context.Context, countryID, trackingID string) (OrderStatus, error) {
	status, err := s.repo.GetStatus(ctx, countryID, trackingID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return OrderStatus{}, ErrOrderNotFound
		}
		return OrderStatus{}, err
	}
	res := orderStatusFromRow(status)
	items, err := s.populateItems(ctx, countryID, status)
	if err == nil {
		res.Items = items
	}
	return res, nil
}

func (s *Service) GetStatusForUser(ctx context.Context, countryID, userID, trackingID string) (OrderStatus, error) {
	if strings.TrimSpace(userID) == "" {
		return OrderStatus{}, ErrUserRequired
	}
	status, err := s.repo.GetStatusForUser(ctx, countryID, userID, trackingID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return OrderStatus{}, ErrOrderNotFound
		}
		return OrderStatus{}, err
	}
	res := orderStatusFromRow(status)
	items, err := s.populateItems(ctx, countryID, status)
	if err == nil {
		res.Items = items
	}
	return res, nil
}

func (s *Service) MarkOrderCollected(ctx context.Context, countryID, userID, trackingID string) (OrderStatus, error) {
	if strings.TrimSpace(userID) == "" {
		return OrderStatus{}, ErrUserRequired
	}
	if strings.TrimSpace(trackingID) == "" {
		return OrderStatus{}, errors.New("tracking_id is required")
	}
	err := s.repo.MarkOrderCollected(ctx, countryID, userID, trackingID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return OrderStatus{}, ErrOrderNotFound
		}
		return OrderStatus{}, err
	}
	return s.GetStatusForUser(ctx, countryID, userID, trackingID)
}

func (s *Service) ListOrders(ctx context.Context, countryID, userID string, req OrderListRequest) (OrderListResponse, error) {
	if strings.TrimSpace(userID) == "" {
		return OrderListResponse{}, ErrUserRequired
	}
	page, limit := normalizeOrderListRequest(req)
	statusFilters := normalizeOrderStatusFilters(req.Statuses)
	offset := (page - 1) * limit
	statuses, err := s.repo.ListStatusesByUser(ctx, countryID, userID, statusFilters, limit+1, offset)
	if err != nil {
		return OrderListResponse{}, err
	}
	hasMore := len(statuses) > limit
	if hasMore {
		statuses = statuses[:limit]
	}
	orders := make([]OrderStatus, 0, len(statuses))
	for _, status := range statuses {
		res := orderStatusFromRow(status)
		items, err := s.populateItems(ctx, countryID, status)
		if err == nil {
			res.Items = items
		}
		orders = append(orders, res)
	}
	return OrderListResponse{
		Items:   orders,
		Page:    page,
		Limit:   limit,
		HasMore: hasMore,
	}, nil
}

func normalizeOrderStatusFilters(statuses []string) []string {
	seen := map[string]struct{}{}
	filters := make([]string, 0, len(statuses))
	for _, status := range statuses {
		normalized := strings.ToUpper(strings.TrimSpace(status))
		if normalized == "" {
			continue
		}
		if _, exists := seen[normalized]; exists {
			continue
		}
		seen[normalized] = struct{}{}
		filters = append(filters, normalized)
	}
	return filters
}

func normalizeOrderListRequest(req OrderListRequest) (int, int) {
	page := req.Page
	if page < 1 {
		page = 1
	}
	limit := req.Limit
	if limit < 1 {
		limit = 20
	}
	if limit > 50 {
		limit = 50
	}
	return page, limit
}

func (s *Service) ValidateVoucher(ctx context.Context, rc CheckoutContext, req VoucherValidationRequest) (VoucherValidationResponse, error) {
	code := strings.ToUpper(strings.TrimSpace(req.VoucherCode))
	if code == "" {
		return VoucherValidationResponse{}, ErrVoucherNotFound
	}
	if strings.TrimSpace(req.UserID) == "" {
		return VoucherValidationResponse{}, ErrUserRequired
	}
	if req.StoreID <= 0 {
		return VoucherValidationResponse{}, ErrStoreRequired
	}
	if len(req.Items) == 0 {
		return VoucherValidationResponse{}, ErrCartEmpty
	}
	for _, item := range req.Items {
		if item.MenuItemID <= 0 || item.Quantity <= 0 {
			return VoucherValidationResponse{}, ErrInvalidCartItem
		}
	}

	store, err := s.repo.GetStore(ctx, rc.CountryCode, req.StoreID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return VoucherValidationResponse{}, ErrStoreNotFound
		}
		return VoucherValidationResponse{}, err
	}
	if !store.AcceptsOrders() {
		return VoucherValidationResponse{}, ErrStoreClosed
	}

	itemIDs := uniqueItemIDs(req.Items)
	pricedItems, err := s.repo.GetPricedItems(ctx, store.ID, store.ZoneID, itemIDs)
	if err != nil {
		return VoucherValidationResponse{}, err
	}
	if len(pricedItems) != len(itemIDs) {
		return VoucherValidationResponse{}, ErrItemUnavailable
	}
	optionIDs := uniqueOptionIDs(req.Items)
	optionPrices, err := s.repo.GetOptionPrices(ctx, store.ID, store.ZoneID, optionIDs)
	if err != nil {
		return VoucherValidationResponse{}, err
	}
	if len(optionPrices) != len(optionIDs) {
		return VoucherValidationResponse{}, ErrInvalidCustomization
	}

	subtotal := 0
	lines := make([]pricedCartLine, 0, len(req.Items))
	for _, item := range req.Items {
		pricedItem := pricedItems[item.MenuItemID]
		lineUnitPrice := pricedItem.BasePrice
		for _, optionID := range item.CustomizationIDs {
			option := optionPrices[optionID]
			if option.MenuItemID != item.MenuItemID {
				return VoucherValidationResponse{}, ErrInvalidCustomization
			}
			lineUnitPrice += option.PriceAdjustment
		}
		lineSubtotal := lineUnitPrice * item.Quantity
		subtotal += lineSubtotal
		lines = append(lines, pricedCartLine{
			MenuItemID:  item.MenuItemID,
			CategoryID:  pricedItem.CategoryID,
			BrandID:     pricedItem.BrandID,
			Quantity:    item.Quantity,
			Subtotal:    lineSubtotal,
			IsPromoItem: pricedItem.IsPromoItem,
		})
	}

	voucher, err := s.repo.GetVoucher(ctx, rc.CountryCode, req.UserID, code)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return VoucherValidationResponse{Code: code, IsValid: false, Reason: ErrVoucherNotFound.Error()}, nil
		}
		return VoucherValidationResponse{}, err
	}
	eligibleSubtotal := voucherEligibleSubtotal(voucher, voucherEligibilityRequest{
		CountryID:     rc.CountryCode,
		UserID:        req.UserID,
		Code:          code,
		StoreID:       store.ID,
		ZoneID:        store.ZoneID,
		PaymentMethod: req.PaymentMethod,
		Subtotal:      subtotal,
		Lines:         lines,
	})
	discount, err := s.discount(ctx, voucherEligibilityRequest{
		CountryID:     rc.CountryCode,
		UserID:        req.UserID,
		Code:          code,
		StoreID:       store.ID,
		ZoneID:        store.ZoneID,
		PaymentMethod: req.PaymentMethod,
		Subtotal:      subtotal,
		Lines:         lines,
	})
	if err != nil {
		if errors.Is(err, ErrVoucherNotEligible) {
			return VoucherValidationResponse{Code: code, IsValid: false, Reason: err.Error(), EligibleSubtotal: eligibleSubtotal}, nil
		}
		if errors.Is(err, ErrVoucherNotFound) {
			return VoucherValidationResponse{Code: code, IsValid: false, Reason: err.Error()}, nil
		}
		return VoucherValidationResponse{}, err
	}
	return VoucherValidationResponse{
		Code:             code,
		IsValid:          true,
		EligibleSubtotal: eligibleSubtotal,
		DiscountAmount:   discount,
	}, nil
}

type pricedCartLine struct {
	MenuItemID        int
	CategoryID        int
	BrandID           int
	Quantity          int
	Subtotal          int
	TaxInclusiveGross int
	TaxExclusiveNet   int
	IsPromoItem       bool
}

type voucherEligibilityRequest struct {
	CountryID     string
	UserID        string
	Code          string
	StoreID       int
	ZoneID        string
	PaymentMethod string
	Subtotal      int
	Lines         []pricedCartLine
}

func (s *Service) discount(ctx context.Context, req voucherEligibilityRequest) (int, error) {
	voucher, err := s.repo.GetVoucher(ctx, req.CountryID, req.UserID, strings.ToUpper(strings.TrimSpace(req.Code)))
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return 0, ErrVoucherNotFound
		}
		return 0, err
	}
	eligibleSubtotal := voucherEligibleSubtotal(voucher, req)
	if eligibleSubtotal <= 0 {
		return 0, ErrVoucherNotEligible
	}
	if eligibleSubtotal < voucher.MinSpend {
		return 0, ErrVoucherNotEligible
	}
	if voucher.UserVoucherStatus.Valid && voucher.UserVoucherStatus.String != "AVAILABLE" {
		return 0, ErrVoucherNotEligible
	}
	if voucher.ZoneID.Valid && voucher.ZoneID.String != req.ZoneID {
		return 0, ErrVoucherNotEligible
	}
	if voucher.MaxRedemptions.Valid && voucher.TotalRedemptions >= int(voucher.MaxRedemptions.Int64) {
		return 0, ErrVoucherNotEligible
	}
	if voucher.MaxRedemptionsPerUser.Valid && voucher.UserRedemptions >= int(voucher.MaxRedemptionsPerUser.Int64) {
		return 0, ErrVoucherNotEligible
	}
	if len(voucher.ApplicablePaymentMethods) > 0 && !containsStringFold(voucher.ApplicablePaymentMethods, req.PaymentMethod) {
		return 0, ErrVoucherNotEligible
	}

	var discount int
	switch voucher.DiscountType {
	case "PERCENTAGE":
		discount = (eligibleSubtotal*voucher.DiscountValue + 50) / 100
		if voucher.MaxDiscountCap.Valid && discount > int(voucher.MaxDiscountCap.Int64) {
			discount = int(voucher.MaxDiscountCap.Int64)
		}
	case "FIXED_AMOUNT":
		discount = voucher.DiscountValue
	}
	if discount > eligibleSubtotal {
		return eligibleSubtotal, nil
	}
	return discount, nil
}

func voucherEligibleSubtotal(voucher Voucher, req voucherEligibilityRequest) int {
	if len(voucher.ApplicableStoreIDs) > 0 && !containsInt(voucher.ApplicableStoreIDs, req.StoreID) {
		return 0
	}
	eligibleSubtotal := 0
	for _, line := range req.Lines {
		if voucher.BrandID.Valid && int64(line.BrandID) != voucher.BrandID.Int64 {
			continue
		}
		if !voucher.AllowPromoItems && line.IsPromoItem {
			continue
		}
		if len(voucher.ApplicableCategoryIDs) > 0 && !containsInt(voucher.ApplicableCategoryIDs, line.CategoryID) {
			continue
		}
		if len(voucher.ApplicableItemIDs) > 0 && !containsInt(voucher.ApplicableItemIDs, line.MenuItemID) {
			continue
		}
		eligibleSubtotal += line.Subtotal
	}
	return eligibleSubtotal
}

func containsInt(values []int, want int) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}

func containsStringFold(values []string, want string) bool {
	want = strings.TrimSpace(want)
	for _, value := range values {
		if strings.EqualFold(strings.TrimSpace(value), want) {
			return true
		}
	}
	return false
}

func orderStatusFromRow(status Status) OrderStatus {
	return OrderStatus{
		TrackingID:           status.TrackingID,
		Status:               status.Status,
		PaymentStatus:        status.PaymentStatus.String,
		PaymentTransactionID: status.TransactionID.String,
		Subtotal:             status.Subtotal,
		Charges:              chargeLineResponses(status.Charges),
		TaxAmount:            status.TaxAmount,
		DiscountAmount:       status.DiscountAmount,
		TotalAmount:          status.TotalAmount,
		CreatedAt:            status.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt:            status.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
		Items:                []OrderStatusItem{},
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
		Charges:         chargeLineResponses(intent.Charges),
		TaxAmount:       intent.TaxAmount,
		DiscountAmount:  intent.DiscountAmount,
		TotalAmount:     intent.TotalAmount,
		Payment:         responsePayment,
	}
}

func chargeLineResponses(lines []ChargeLine) []ChargeLineResponse {
	if len(lines) == 0 {
		return []ChargeLineResponse{}
	}
	responses := make([]ChargeLineResponse, 0, len(lines))
	for _, line := range lines {
		responses = append(responses, ChargeLineResponse{
			Code:          line.Code,
			Name:          line.Name,
			Scope:         line.Scope,
			Amount:        line.Amount,
			TaxableAmount: line.TaxableAmount,
			TaxAmount:     line.TaxAmount,
			TotalAmount:   line.TotalAmount,
			Taxable:       line.Taxable,
			TaxInclusive:  line.TaxInclusive,
			Waived:        line.Waived,
			WaiverReason:  line.WaiverReason,
		})
	}
	return responses
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
