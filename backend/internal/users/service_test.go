package users

import (
	"context"
	"errors"
	"testing"
)

type mockProfileRepository struct {
	country Country
	profile Profile
	update  ProfileUpdate
}

func (m *mockProfileRepository) GetCountry(ctx context.Context, countryID string) (Country, error) {
	if countryID != m.country.ID {
		return Country{}, ErrNotFound
	}
	return m.country, nil
}

func (m *mockProfileRepository) EnsureAccount(ctx context.Context, userID string, country Country) error {
	return nil
}

func (m *mockProfileRepository) GetProfile(ctx context.Context, userID, countryID string) (Profile, error) {
	m.profile.UserID = userID
	m.profile.RegisteredCountryID = countryID
	return m.profile, nil
}

func (m *mockProfileRepository) UpdateProfile(ctx context.Context, userID string, update ProfileUpdate) error {
	m.update = update
	m.profile.DisplayName = update.DisplayName
	m.profile.Email = update.Email
	m.profile.PhoneNumber = update.PhoneNumber
	m.profile.AvatarURL = update.AvatarURL
	m.profile.PreferredLanguage = update.PreferredLanguage
	m.profile.MarketingOptIn = update.MarketingOptIn
	return nil
}

func (m *mockProfileRepository) ListWalletTransactions(ctx context.Context, userID, countryID string, limit int) (WalletHistory, error) {
	return WalletHistory{
		UserID:       userID,
		CountryCode:  countryID,
		CurrencyCode: m.country.CurrencyCode,
		Balance:      m.profile.WalletBalance,
	}, nil
}

func (m *mockProfileRepository) ListLoyaltyTransactions(ctx context.Context, userID, countryID string, limit int) (LoyaltyHistory, error) {
	return LoyaltyHistory{
		UserID:      userID,
		CountryCode: countryID,
		Points:      m.profile.LoyaltyPoints,
		Tier:        m.profile.LoyaltyTier,
	}, nil
}

func (m *mockProfileRepository) TopUpWallet(ctx context.Context, userID string, country Country, amount int, description string) (WalletHistory, error) {
	m.profile.WalletBalance += amount
	return WalletHistory{
		UserID:       userID,
		CountryCode:  country.ID,
		CurrencyCode: country.CurrencyCode,
		Balance:      m.profile.WalletBalance,
		Transactions: []WalletTransaction{{
			TransactionType: "TOPUP",
			Amount:          amount,
			BalanceAfter:    m.profile.WalletBalance,
			CurrencyCode:    country.CurrencyCode,
			Description:     description,
		}},
	}, nil
}

func TestProfileRequiresUserID(t *testing.T) {
	svc := NewService(&mockProfileRepository{country: Country{ID: "MY"}}, "")
	_, err := svc.Profile(context.Background(), "MY", " ")
	if !errors.Is(err, ErrUserIDRequired) {
		t.Fatalf("expected ErrUserIDRequired, got %v", err)
	}
}

func TestUpdateProfilePreservesUnspecifiedFields(t *testing.T) {
	repo := &mockProfileRepository{
		country: Country{ID: "MY", CurrencyCode: "MYR", DefaultLanguage: "en-US"},
		profile: Profile{
			DisplayName:       "Dev User",
			Email:             "dev@example.com",
			PhoneNumber:       "+60123456789",
			PreferredLanguage: "en-US",
			MarketingOptIn:    false,
		},
	}
	svc := NewService(repo, "")

	name := "Jane"
	optIn := true
	profile, err := svc.UpdateProfile(context.Background(), "MY", "user1", UpdateProfileRequest{
		DisplayName:    &name,
		MarketingOptIn: &optIn,
	})
	if err != nil {
		t.Fatal(err)
	}

	if profile.DisplayName != "Jane" {
		t.Fatalf("expected updated display name, got %q", profile.DisplayName)
	}
	if profile.Email != "dev@example.com" {
		t.Fatalf("expected email to be preserved, got %q", profile.Email)
	}
	if !profile.MarketingOptIn {
		t.Fatal("expected marketing opt-in to update")
	}
}

func TestTopUpWalletRequiresPositiveAmount(t *testing.T) {
	svc := NewService(&mockProfileRepository{country: Country{ID: "MY", CurrencyCode: "MYR"}}, "")
	_, err := svc.TopUpWallet(context.Background(), "MY", "user1", WalletTopUpRequest{Amount: 0})
	if !errors.Is(err, ErrInvalidTopUpAmount) {
		t.Fatalf("expected ErrInvalidTopUpAmount, got %v", err)
	}
}
