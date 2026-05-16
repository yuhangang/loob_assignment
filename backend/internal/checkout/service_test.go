package checkout

import (
	"context"
	"errors"
	"testing"
)

type mockRepository struct {
	getCountry              func(ctx context.Context, countryID string) (Country, error)
	getStore                func(ctx context.Context, countryID string, storeID int) (Store, error)
	upsertUser              func(ctx context.Context, userID, countryID string) error
	getPricedItems          func(ctx context.Context, zoneID string, itemIDs []int) (map[int]PricedItem, error)
	getOptionPrices         func(ctx context.Context, optionIDs []int) (map[int]OptionPrice, error)
	getCustomizationRules   func(ctx context.Context, menuItemIDs []int) ([]CustomizationGroupRule, map[int]CustomizationOptionRule, error)
	getVoucher              func(ctx context.Context, countryID, code string) (Voucher, error)
	findIntentByIdempotency func(ctx context.Context, countryID, userID, key string) (IntentWithPayment, error)
	createIntentWithPayment func(ctx context.Context, intent Intent, payment PaymentTransaction) error
	createPaymentIfMissing func(ctx context.Context, payment PaymentTransaction) (PaymentTransaction, error)
	getStatus               func(ctx context.Context, countryID, trackingID string) (Status, error)
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
func (m *mockRepository) GetPricedItems(ctx context.Context, zoneID string, itemIDs []int) (map[int]PricedItem, error) {
	return m.getPricedItems(ctx, zoneID, itemIDs)
}
func (m *mockRepository) GetOptionPrices(ctx context.Context, optionIDs []int) (map[int]OptionPrice, error) {
	return m.getOptionPrices(ctx, optionIDs)
}
func (m *mockRepository) GetCustomizationRules(ctx context.Context, menuItemIDs []int) ([]CustomizationGroupRule, map[int]CustomizationOptionRule, error) {
	return m.getCustomizationRules(ctx, menuItemIDs)
}
func (m *mockRepository) GetVoucher(ctx context.Context, countryID, code string) (Voucher, error) {
	return m.getVoucher(ctx, countryID, code)
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
		{ID: 10, MenuItemID: 1, SelectionType: "SINGLE_SELECT", IsRequired: true, MaxSelections: 1},
		{ID: 20, MenuItemID: 1, SelectionType: "MULTI_SELECT", MaxSelections: 2},
	}
	options := map[int]CustomizationOptionRule{
		100: {ID: 100, GroupID: 10, MenuItemID: 1},
		101: {ID: 101, GroupID: 10, MenuItemID: 1},
		200: {ID: 200, GroupID: 20, MenuItemID: 1},
		201: {ID: 201, GroupID: 20, MenuItemID: 1},
		202: {ID: 202, GroupID: 20, MenuItemID: 1},
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
		getVoucher: func(ctx context.Context, countryID, code string) (Voucher, error) {
			if code == "PERCENT10" {
				return Voucher{Code: "PERCENT10", DiscountType: "PERCENTAGE", DiscountValue: 10, MinSpend: 100}, nil
			}
			return Voucher{}, ErrNotFound
		},
	}
	svc := NewService(repo, nil)

	t.Run("percentage discount", func(t *testing.T) {
		d, err := svc.discount(context.Background(), "MY", "PERCENT10", 1000, nil)
		if err != nil {
			t.Fatal(err)
		}
		if d != 100 {
			t.Errorf("expected 100, got %d", d)
		}
	})

	t.Run("below min spend", func(t *testing.T) {
		_, err := svc.discount(context.Background(), "MY", "PERCENT10", 50, nil)
		if !errors.Is(err, ErrVoucherNotEligible) {
			t.Errorf("expected ErrVoucherNotEligible, got %v", err)
		}
	})
}
