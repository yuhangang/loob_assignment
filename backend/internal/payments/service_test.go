package payments

import (
	"context"
	"errors"
	"testing"
)

type mockRepository struct {
	applyCallback            func(ctx context.Context, update CallbackUpdate) (TransactionRow, error)
	get                      func(ctx context.Context, countryID, transactionID string) (TransactionRow, error)
	resolvePaymentMethod     func(ctx context.Context, countryID string, brandID int, methodCode string, amount int) (PaymentMethod, error)
	createPendingTransaction func(ctx context.Context, tx PendingTransaction) (TransactionRow, error)
	listProviders            func(ctx context.Context, includeInactive bool) ([]ProviderRow, error)
	listMethods              func(ctx context.Context, countryID string, brandID int, includeInactive bool) ([]MethodRow, error)
}

func (m *mockRepository) ApplyCallback(ctx context.Context, update CallbackUpdate) (TransactionRow, error) {
	return m.applyCallback(ctx, update)
}
func (m *mockRepository) Get(ctx context.Context, countryID, transactionID string) (TransactionRow, error) {
	return m.get(ctx, countryID, transactionID)
}
func (m *mockRepository) GetForUser(ctx context.Context, countryID, userID, transactionID string) (TransactionRow, error) {
	return m.get(ctx, countryID, transactionID)
}
func (m *mockRepository) ResolvePaymentMethod(ctx context.Context, countryID string, brandID int, methodCode string, amount int) (PaymentMethod, error) {
	return m.resolvePaymentMethod(ctx, countryID, brandID, methodCode, amount)
}
func (m *mockRepository) CreatePendingTransaction(ctx context.Context, tx PendingTransaction) (TransactionRow, error) {
	return m.createPendingTransaction(ctx, tx)
}
func (m *mockRepository) ListProviders(ctx context.Context, includeInactive bool) ([]ProviderRow, error) {
	return m.listProviders(ctx, includeInactive)
}
func (m *mockRepository) ListMethods(ctx context.Context, countryID string, brandID int, includeInactive bool) ([]MethodRow, error) {
	return m.listMethods(ctx, countryID, brandID, includeInactive)
}

func TestMapGatewayStatus(t *testing.T) {
	tests := []struct {
		status  string
		wantPay string
		wantOrd string
		wantErr bool
	}{
		{"SUCCESS", "CAPTURED", "READY_TO_COLLECT", false},
		{"FAILED", "FAILED", "PAYMENT_FAILED", false},
		{"UNKNOWN", "", "", true},
	}

	for _, tt := range tests {
		pay, ord, err := mapGatewayStatus(tt.status)
		if (err != nil) != tt.wantErr {
			t.Errorf("mapGatewayStatus(%s) error = %v, wantErr %v", tt.status, err, tt.wantErr)
		}
		if pay != tt.wantPay || ord != tt.wantOrd {
			t.Errorf("mapGatewayStatus(%s) = (%s, %s), want (%s, %s)", tt.status, pay, ord, tt.wantPay, tt.wantOrd)
		}
	}
}

func TestNormalizeMethod(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"wallet", "EWALLET"},
		{"bank", "FPX"},
		{"CREDIT_CARD", "CREDIT_CARD"},
	}

	for _, tt := range tests {
		if got := normalizeMethod(tt.input); got != tt.want {
			t.Errorf("normalizeMethod(%s) = %s, want %s", tt.input, got, tt.want)
		}
	}
}

func TestAuthorizeMockGateway(t *testing.T) {
	svc := NewService(nil, "secret123")
	if !svc.AuthorizeMockGateway("secret123") {
		t.Error("expected true for correct secret")
	}
	if svc.AuthorizeMockGateway("wrong") {
		t.Error("expected false for wrong secret")
	}
	if svc.AuthorizeMockGateway("secret123-extra") {
		t.Error("expected false for different length secret")
	}
}

func TestApplyMockGatewayCallbackPreservesVoucherLimitError(t *testing.T) {
	svc := NewService(&mockRepository{
		applyCallback: func(ctx context.Context, update CallbackUpdate) (TransactionRow, error) {
			return TransactionRow{}, ErrVoucherRedemptionLimitExceeded
		},
	}, "secret123")

	_, err := svc.ApplyMockGatewayCallback(context.Background(), MockGatewayCallbackRequest{
		TransactionID: "PAY-MY-1",
		Status:        "SUCCESS",
	})
	if !errors.Is(err, ErrVoucherRedemptionLimitExceeded) {
		t.Fatalf("expected ErrVoucherRedemptionLimitExceeded, got %v", err)
	}
}
