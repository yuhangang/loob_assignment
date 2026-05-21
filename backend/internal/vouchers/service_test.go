package vouchers

import (
	"context"
	"errors"
	"testing"
)

type mockRepository struct {
	getCountry           func(ctx context.Context, countryID string) (Country, error)
	listWallet           func(ctx context.Context, countryID, userID string, brandID int) ([]VoucherRow, error)
	getWalletSummary     func(ctx context.Context, country Country, userID string) (WalletSummary, error)
	assignActiveVouchers func(ctx context.Context, countryID, userID string) error
}

func (m *mockRepository) GetCountry(ctx context.Context, countryID string) (Country, error) {
	return m.getCountry(ctx, countryID)
}
func (m *mockRepository) ListWallet(ctx context.Context, countryID, userID string, brandID int) ([]VoucherRow, error) {
	return m.listWallet(ctx, countryID, userID, brandID)
}
func (m *mockRepository) GetWalletSummary(ctx context.Context, country Country, userID string) (WalletSummary, error) {
	return m.getWalletSummary(ctx, country, userID)
}
func (m *mockRepository) AssignActiveVouchers(ctx context.Context, countryID, userID string) error {
	return m.assignActiveVouchers(ctx, countryID, userID)
}

func TestResolveLanguage(t *testing.T) {
	tests := []struct {
		lang     string
		fallback string
		want     string
	}{
		{"ms", "en-US", "ms"},
		{"", "en-US", "en-US"},
		{"  ", "en-US", "en-US"},
	}

	for _, tt := range tests {
		if got := resolveLanguage(tt.lang, tt.fallback); got != tt.want {
			t.Errorf("resolveLanguage(%q, %q) = %q, want %q", tt.lang, tt.fallback, got, tt.want)
		}
	}
}

func TestTitle(t *testing.T) {
	tests := []struct {
		code         string
		discountType string
		value        int
		currencyCode string
		want         string
	}{
		{"SAVE10", "PERCENTAGE", 10, "MYR", "10% off"},
		{"CASH5", "FIXED_AMOUNT", 500, "MYR", "RM 5 off"},
		{"UNKNOWN", "OTHER", 0, "MYR", "UNKNOWN"},
	}

	for _, tt := range tests {
		if got := title(tt.code, tt.discountType, tt.value, tt.currencyCode); got != tt.want {
			t.Errorf("title(%q, %q, %d, %q) = %q, want %q", tt.code, tt.discountType, tt.value, tt.currencyCode, got, tt.want)
		}
	}
}

func TestWallet(t *testing.T) {
	repo := &mockRepository{
		getCountry: func(ctx context.Context, countryID string) (Country, error) {
			if countryID == "MY" {
				return Country{ID: "MY", CurrencyCode: "MYR", DefaultLanguage: "en-US"}, nil
			}
			return Country{}, ErrNotFound
		},
		assignActiveVouchers: func(ctx context.Context, countryID, userID string) error {
			return nil
		},
		listWallet: func(ctx context.Context, countryID, userID string, brandID int) ([]VoucherRow, error) {
			return []VoucherRow{
				{ID: 1, Code: "PROMO1", DiscountType: "PERCENTAGE", DiscountValue: 10, MinSpend: 100},
			}, nil
		},
		getWalletSummary: func(ctx context.Context, country Country, userID string) (WalletSummary, error) {
			return WalletSummary{CurrencyCode: country.CurrencyCode, Balance: 1200, LoyaltyPoints: 450, LoyaltyTier: "GOLD"}, nil
		},
	}

	svc := NewService(repo)

	t.Run("success", func(t *testing.T) {
		wallet, err := svc.Wallet(context.Background(), "MY", "en", "user1", 0)
		if err != nil {
			t.Fatal(err)
		}

		if len(wallet.Vouchers) != 1 {
			t.Errorf("expected 1 voucher, got %d", len(wallet.Vouchers))
		}
		if wallet.Vouchers[0].Code != "PROMO1" {
			t.Errorf("expected PROMO1, got %s", wallet.Vouchers[0].Code)
		}
		if wallet.Vouchers[0].Description != "Save 10% when you spend at least RM 1." {
			t.Errorf("unexpected voucher description %q", wallet.Vouchers[0].Description)
		}
		if wallet.Vouchers[0].TermsAndConditionsMarkdown == "" {
			t.Error("expected voucher markdown terms")
		}
		if wallet.Vouchers[0].TermsAndConditionsHTML == "" {
			t.Error("expected voucher html terms")
		}
		if wallet.WalletBalance != 1200 {
			t.Errorf("expected wallet balance 1200, got %d", wallet.WalletBalance)
		}
		if wallet.LoyaltyPoints != 450 {
			t.Errorf("expected loyalty points 450, got %d", wallet.LoyaltyPoints)
		}
		if wallet.VoucherCount != 1 {
			t.Errorf("expected voucher count 1, got %d", wallet.VoucherCount)
		}
	})

	t.Run("unsupported country", func(t *testing.T) {
		_, err := svc.Wallet(context.Background(), "XX", "en", "user1", 0)
		if !errors.Is(err, ErrUnsupportedCountry) {
			t.Errorf("expected ErrUnsupportedCountry, got %v", err)
		}
	})
}
