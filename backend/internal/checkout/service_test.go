package checkout

import (
	"context"
	"database/sql"
	"errors"
	"testing"
	"time"
)

type mockRepository struct {
	getCountry              func(ctx context.Context, countryID string) (Country, error)
	getStore                func(ctx context.Context, countryID string, storeID int) (Store, error)
	upsertUser              func(ctx context.Context, userID, countryID string) error
	getPricedItems          func(ctx context.Context, storeID int, zoneID string, itemIDs []int) (map[int]PricedItem, error)
	getOptionPrices         func(ctx context.Context, storeID int, zoneID string, optionIDs []int) (map[int]OptionPrice, error)
	getCustomizationRules   func(ctx context.Context, menuItemIDs []int) ([]CustomizationGroupRule, map[int]CustomizationOptionRule, error)
	getVoucher              func(ctx context.Context, countryID, userID, code string) (Voucher, error)
	listChargeDefinitions   func(ctx context.Context, countryID string, store Store, fulfillment string) ([]ChargeDefinition, error)
	findIntentByIdempotency func(ctx context.Context, countryID, userID, key string) (IntentWithPayment, error)
	createIntentWithPayment func(ctx context.Context, intent Intent, payment PaymentTransaction) error
	createPaymentIfMissing  func(ctx context.Context, payment PaymentTransaction) (PaymentTransaction, error)
	getStatus               func(ctx context.Context, countryID, trackingID string) (Status, error)
	getStatusForUser        func(ctx context.Context, countryID, userID, trackingID string) (Status, error)
	listStatusesByUser      func(ctx context.Context, countryID, userID string) ([]Status, error)
}

func (m *mockRepository) GetCountry(ctx context.Context, countryID string) (Country, error) {
	return m.getCountry(ctx, countryID)
}
func (m *mockRepository) GetStore(ctx context.Context, countryID string, storeID int) (Store, error) {
	return m.getStore(ctx, countryID, storeID)
}
func (m *mockRepository) UpsertUser(ctx context.Context, userID, countryID string) error {
	return m.upsertUser(ctx, userID, countryID)
}
func (m *mockRepository) GetPricedItems(ctx context.Context, storeID int, zoneID string, itemIDs []int) (map[int]PricedItem, error) {
	return m.getPricedItems(ctx, storeID, zoneID, itemIDs)
}
func (m *mockRepository) GetOptionPrices(ctx context.Context, storeID int, zoneID string, optionIDs []int) (map[int]OptionPrice, error) {
	return m.getOptionPrices(ctx, storeID, zoneID, optionIDs)
}
func (m *mockRepository) GetCustomizationRules(ctx context.Context, menuItemIDs []int) ([]CustomizationGroupRule, map[int]CustomizationOptionRule, error) {
	return m.getCustomizationRules(ctx, menuItemIDs)
}
func (m *mockRepository) GetVoucher(ctx context.Context, countryID, userID, code string) (Voucher, error) {
	return m.getVoucher(ctx, countryID, userID, code)
}
func (m *mockRepository) ListChargeDefinitions(ctx context.Context, countryID string, store Store, fulfillment string) ([]ChargeDefinition, error) {
	if m.listChargeDefinitions == nil {
		return nil, nil
	}
	return m.listChargeDefinitions(ctx, countryID, store, fulfillment)
}
func (m *mockRepository) FindIntentByIdempotency(ctx context.Context, countryID, userID, key string) (IntentWithPayment, error) {
	return m.findIntentByIdempotency(ctx, countryID, userID, key)
}
func (m *mockRepository) CreateIntentWithPayment(ctx context.Context, intent Intent, payment PaymentTransaction) error {
	return m.createIntentWithPayment(ctx, intent, payment)
}
func (m *mockRepository) CreatePaymentIfMissing(ctx context.Context, payment PaymentTransaction) (PaymentTransaction, error) {
	return m.createPaymentIfMissing(ctx, payment)
}
func (m *mockRepository) GetStatus(ctx context.Context, countryID, trackingID string) (Status, error) {
	return m.getStatus(ctx, countryID, trackingID)
}
func (m *mockRepository) GetStatusForUser(ctx context.Context, countryID, userID, trackingID string) (Status, error) {
	return m.getStatusForUser(ctx, countryID, userID, trackingID)
}
func (m *mockRepository) ListStatusesByUser(ctx context.Context, countryID, userID string) ([]Status, error) {
	return m.listStatusesByUser(ctx, countryID, userID)
}

func TestValidate(t *testing.T) {
	tests := []struct {
		name string
		req  CheckoutRequest
		want error
	}{
		{
			name: "valid request",
			req: CheckoutRequest{
				UserID:         "u1",
				IdempotencyKey: "k1",
				StoreID:        1,
				Fulfillment:    "DINE_IN",
				Items:          []CartItem{{MenuItemID: 1, Quantity: 1}},
			},
			want: nil,
		},
		{
			name: "missing user",
			req:  CheckoutRequest{IdempotencyKey: "k1", StoreID: 1, Fulfillment: "DINE_IN", Items: []CartItem{{MenuItemID: 1, Quantity: 1}}},
			want: ErrUserRequired,
		},
		{
			name: "empty cart",
			req:  CheckoutRequest{UserID: "u1", IdempotencyKey: "k1", StoreID: 1, Fulfillment: "DINE_IN", Items: []CartItem{}},
			want: ErrCartEmpty,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := validate(tt.req); got != tt.want {
				t.Errorf("validate() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestValidateCustomizationsEnforcesGroupRules(t *testing.T) {
	groups := []CustomizationGroupRule{
		{ID: 10, MenuItemID: 1, SelectionType: "SINGLE_SELECT", MinSelections: 1, IsRequired: true, MaxSelections: 1},
		{ID: 20, MenuItemID: 1, SelectionType: "MULTI_SELECT", MaxSelections: 2},
		{ID: 30, MenuItemID: 1, SelectionType: "MULTI_SELECT", MinSelections: 0, MaxSelections: 3},
	}
	options := map[int]CustomizationOptionRule{
		100: {ID: 100, GroupID: 10, MenuItemID: 1},
		101: {ID: 101, GroupID: 10, MenuItemID: 1},
		200: {ID: 200, GroupID: 20, MenuItemID: 1},
		201: {ID: 201, GroupID: 20, MenuItemID: 1},
		202: {ID: 202, GroupID: 20, MenuItemID: 1},
		300: {ID: 300, GroupID: 30, MenuItemID: 1},
	}

	tests := []struct {
		name  string
		items []CartItem
		want  error
	}{
		{
			name:  "valid required single and optional multi",
			items: []CartItem{{MenuItemID: 1, Quantity: 1, CustomizationIDs: []int{100, 200, 201}}},
		},
		{
			name:  "missing required group",
			items: []CartItem{{MenuItemID: 1, Quantity: 1, CustomizationIDs: []int{200}}},
			want:  ErrInvalidCustomization,
		},
		{
			name:  "too many single select options",
			items: []CartItem{{MenuItemID: 1, Quantity: 1, CustomizationIDs: []int{100, 101}}},
			want:  ErrInvalidCustomization,
		},
		{
			name:  "optional group may be omitted",
			items: []CartItem{{MenuItemID: 1, Quantity: 1, CustomizationIDs: []int{100}}},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := validateCustomizations(tt.items, groups, options)
			if got != tt.want {
				t.Fatalf("validateCustomizations() error = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestDiscount(t *testing.T) {
	repo := &mockRepository{
		getVoucher: func(ctx context.Context, countryID, userID, code string) (Voucher, error) {
			if code == "PERCENT10" {
				return Voucher{Code: "PERCENT10", DiscountType: "PERCENTAGE", DiscountValue: 10, MinSpend: 100, AllowPromoItems: true}, nil
			}
			return Voucher{}, ErrNotFound
		},
	}
	svc := NewService(repo, nil)

	t.Run("percentage discount", func(t *testing.T) {
		d, err := svc.discount(context.Background(), voucherEligibilityRequest{
			CountryID: "MY",
			UserID:    "u1",
			Code:      "PERCENT10",
			Subtotal:  1000,
			Lines:     []pricedCartLine{{MenuItemID: 1, CategoryID: 10, BrandID: 1, Subtotal: 1000}},
		})
		if err != nil {
			t.Fatal(err)
		}
		if d != 100 {
			t.Errorf("expected 100, got %d", d)
		}
	})

	t.Run("below min spend", func(t *testing.T) {
		_, err := svc.discount(context.Background(), voucherEligibilityRequest{
			CountryID: "MY",
			UserID:    "u1",
			Code:      "PERCENT10",
			Subtotal:  50,
			Lines:     []pricedCartLine{{MenuItemID: 1, CategoryID: 10, BrandID: 1, Subtotal: 50}},
		})
		if !errors.Is(err, ErrVoucherNotEligible) {
			t.Errorf("expected ErrVoucherNotEligible, got %v", err)
		}
	})
}

func TestDiscountEligibilityRules(t *testing.T) {
	repo := &mockRepository{
		getVoucher: func(ctx context.Context, countryID, userID, code string) (Voucher, error) {
			switch code {
			case "TEAONLY":
				return Voucher{
					Code:                     "TEAONLY",
					BrandID:                  sql.NullInt64{Int64: 1, Valid: true},
					DiscountType:             "FIXED_AMOUNT",
					DiscountValue:            300,
					MinSpend:                 500,
					AllowPromoItems:          false,
					ApplicableCategoryIDs:    []int{10},
					ApplicablePaymentMethods: []string{"EWALLET"},
					MaxRedemptions:           sql.NullInt64{Int64: 10, Valid: true},
					MaxRedemptionsPerUser:    sql.NullInt64{Int64: 1, Valid: true},
				}, nil
			case "USEDUP":
				return Voucher{
					Code:                  "USEDUP",
					DiscountType:          "FIXED_AMOUNT",
					DiscountValue:         300,
					AllowPromoItems:       true,
					MaxRedemptionsPerUser: sql.NullInt64{Int64: 1, Valid: true},
					UserRedemptions:       1,
				}, nil
			default:
				return Voucher{}, ErrNotFound
			}
		},
	}
	svc := NewService(repo, nil)

	discount, err := svc.discount(context.Background(), voucherEligibilityRequest{
		CountryID:     "MY",
		UserID:        "u1",
		Code:          "TEAONLY",
		StoreID:       1,
		PaymentMethod: "EWALLET",
		Subtotal:      2200,
		Lines: []pricedCartLine{
			{MenuItemID: 100, CategoryID: 10, BrandID: 1, Subtotal: 900},
			{MenuItemID: 101, CategoryID: 10, BrandID: 1, Subtotal: 800, IsPromoItem: true},
			{MenuItemID: 200, CategoryID: 12, BrandID: 2, Subtotal: 500},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if discount != 300 {
		t.Fatalf("discount = %d, want 300", discount)
	}

	_, err = svc.discount(context.Background(), voucherEligibilityRequest{
		CountryID:     "MY",
		UserID:        "u1",
		Code:          "TEAONLY",
		StoreID:       1,
		PaymentMethod: "CARD",
		Subtotal:      900,
		Lines:         []pricedCartLine{{MenuItemID: 100, CategoryID: 10, BrandID: 1, Subtotal: 900}},
	})
	if !errors.Is(err, ErrVoucherNotEligible) {
		t.Fatalf("payment method error = %v, want %v", err, ErrVoucherNotEligible)
	}

	_, err = svc.discount(context.Background(), voucherEligibilityRequest{
		CountryID: "MY",
		UserID:    "u1",
		Code:      "USEDUP",
		Subtotal:  900,
		Lines:     []pricedCartLine{{MenuItemID: 100, CategoryID: 10, BrandID: 1, Subtotal: 900}},
	})
	if !errors.Is(err, ErrVoucherNotEligible) {
		t.Fatalf("used voucher error = %v, want %v", err, ErrVoucherNotEligible)
	}
}

func TestCalculateChargesIncludesTaxablePackaging(t *testing.T) {
	charges := calculateCharges([]ChargeDefinition{
		{
			Code:            "PACKAGING_FEE",
			Name:            "Packaging fee",
			Scope:           "ORDER",
			CalculationType: "FIXED_AMOUNT",
			Amount:          100,
			Taxable:         true,
		},
	}, chargeCalculationRequest{
		Subtotal: 1000,
		TaxRate:  0.06,
	})

	if len(charges) != 1 {
		t.Fatalf("expected 1 charge, got %d", len(charges))
	}
	charge := charges[0]
	if charge.Code != "PACKAGING_FEE" || charge.Amount != 100 || charge.TaxAmount != 6 || charge.TotalAmount != 106 {
		t.Fatalf("unexpected packaging charge: %+v", charge)
	}
}

func TestCalculateChargesWaivesByMinimumSubtotal(t *testing.T) {
	charges := calculateCharges([]ChargeDefinition{
		{
			Code:              "PACKAGING_FEE",
			Name:              "Packaging fee",
			Scope:             "ORDER",
			CalculationType:   "FIXED_AMOUNT",
			Amount:            100,
			Taxable:           true,
			WaiverMinSubtotal: sql.NullInt64{Int64: 2000, Valid: true},
			WaiverReason:      sql.NullString{String: "MIN_PURCHASE", Valid: true},
		},
	}, chargeCalculationRequest{
		Subtotal: 2500,
		TaxRate:  0.06,
	})

	if len(charges) != 1 {
		t.Fatalf("expected 1 charge, got %d", len(charges))
	}
	charge := charges[0]
	if !charge.Waived || charge.TotalAmount != 0 || charge.TaxAmount != 0 || charge.WaiverReason != "MIN_PURCHASE" {
		t.Fatalf("unexpected waived charge: %+v", charge)
	}
}

func TestCheckoutRejectsClosedStore(t *testing.T) {
	repo := &mockRepository{
		findIntentByIdempotency: func(ctx context.Context, countryID, userID, key string) (IntentWithPayment, error) {
			return IntentWithPayment{}, ErrNotFound
		},
		getCountry: func(ctx context.Context, countryID string) (Country, error) {
			return Country{ID: countryID, Currency: "MYR"}, nil
		},
		getStore: func(ctx context.Context, countryID string, storeID int) (Store, error) {
			return Store{
				ID:                storeID,
				CountryID:         countryID,
				ZoneID:            "MY_KV",
				BrandID:           1,
				OperationalStatus: "TEMPORARILY_CLOSED",
			}, nil
		},
	}

	svc := NewService(repo, nil)
	_, err := svc.Checkout(context.Background(), CheckoutContext{
		TraceID:     "trace-1",
		CountryCode: "MY",
	}, CheckoutRequest{
		UserID:         "u1",
		IdempotencyKey: "k1",
		StoreID:        1,
		Fulfillment:    "TAKEAWAY",
		Items:          []CartItem{{MenuItemID: 1, Quantity: 1}},
	})

	if !errors.Is(err, ErrStoreClosed) {
		t.Fatalf("Checkout() error = %v, want %v", err, ErrStoreClosed)
	}
}

func TestListOrdersReturnsUserOrders(t *testing.T) {
	createdAt := time.Date(2026, 5, 18, 10, 0, 0, 0, time.UTC)
	repo := &mockRepository{
		listStatusesByUser: func(ctx context.Context, countryID, userID string) ([]Status, error) {
			if countryID != "MY" || userID != "u1" {
				t.Fatalf("unexpected scope country=%s user=%s", countryID, userID)
			}
			return []Status{
				{
					TrackingID:     "MY-ORDER-001",
					Status:         "PAYMENT_PENDING",
					PaymentStatus:  sql.NullString{String: "PENDING", Valid: true},
					Subtotal:       1000,
					Charges:        []ChargeLine{{Code: "PACKAGING_FEE", Name: "Packaging fee", Scope: "ORDER", Amount: 100, TaxAmount: 6, TotalAmount: 106, Taxable: true}},
					TaxAmount:      60,
					DiscountAmount: 0,
					TotalAmount:    1166,
					CreatedAt:      createdAt,
					UpdatedAt:      createdAt,
				},
			}, nil
		},
	}
	svc := NewService(repo, nil)

	orders, err := svc.ListOrders(context.Background(), "MY", "u1")
	if err != nil {
		t.Fatal(err)
	}
	if len(orders) != 1 {
		t.Fatalf("expected 1 order, got %d", len(orders))
	}
	if orders[0].TrackingID != "MY-ORDER-001" || orders[0].PaymentStatus != "PENDING" {
		t.Fatalf("unexpected order response: %+v", orders[0])
	}
	if len(orders[0].Charges) != 1 || orders[0].Charges[0].Code != "PACKAGING_FEE" {
		t.Fatalf("unexpected charge response: %+v", orders[0].Charges)
	}
}
