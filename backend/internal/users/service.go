package users

import (
	"context"
	"errors"
	"strings"

	"github.com/loob/backend/internal/payments"
)

type ProfileRepository interface {
	GetCountry(ctx context.Context, countryID string) (Country, error)
	EnsureAccount(ctx context.Context, userID string, country Country) error
	GetProfile(ctx context.Context, userID, countryID string) (Profile, error)
	UpdateProfile(ctx context.Context, userID string, update ProfileUpdate) error
	ListWalletTransactions(ctx context.Context, userID, countryID string, limit int) (WalletHistory, error)
	ListLoyaltyTransactions(ctx context.Context, userID, countryID string, limit int) (LoyaltyHistory, error)
	TopUpWallet(ctx context.Context, userID string, country Country, amount int, description string) (WalletHistory, error)
}

type Service struct {
	repo          ProfileRepository
	payments      *payments.Service
	publicBaseURL string
}

func NewService(repo ProfileRepository, pm *payments.Service, publicBaseURL string) *Service {
	return &Service{repo: repo, payments: pm, publicBaseURL: publicBaseURL}
}

func (s *Service) Profile(ctx context.Context, countryID, userID string) (Profile, error) {
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return Profile{}, ErrUserIDRequired
	}

	country, err := s.repo.GetCountry(ctx, countryID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return Profile{}, ErrUnsupportedCountry
		}
		return Profile{}, err
	}
	if err := s.repo.EnsureAccount(ctx, userID, country); err != nil {
		return Profile{}, err
	}
	prof, err := s.repo.GetProfile(ctx, userID, country.ID)
	if err != nil {
		return Profile{}, err
	}
	prof.AvatarURL = resolveAssetURL(s.publicBaseURL, prof.AvatarURL)
	return prof, nil
}

func (s *Service) UpdateProfile(ctx context.Context, countryID, userID string, req UpdateProfileRequest) (Profile, error) {
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return Profile{}, ErrUserIDRequired
	}
	country, err := s.repo.GetCountry(ctx, countryID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return Profile{}, ErrUnsupportedCountry
		}
		return Profile{}, err
	}
	if err := s.repo.EnsureAccount(ctx, userID, country); err != nil {
		return Profile{}, err
	}
	current, err := s.repo.GetProfile(ctx, userID, country.ID)
	if err != nil {
		return Profile{}, err
	}

	update := ProfileUpdate{
		DisplayName:         current.DisplayName,
		Email:               current.Email,
		PhoneNumber:         current.PhoneNumber,
		AvatarURL:           current.AvatarURL,
		PreferredLanguage:   current.PreferredLanguage,
		RegisteredCountryID: current.RegisteredCountryID,
		MarketingOptIn:      current.MarketingOptIn,
	}
	if req.DisplayName != nil {
		update.DisplayName = strings.TrimSpace(*req.DisplayName)
	}
	if req.Email != nil {
		update.Email = strings.TrimSpace(*req.Email)
	}
	if req.PhoneNumber != nil {
		update.PhoneNumber = strings.TrimSpace(*req.PhoneNumber)
	}
	if req.AvatarURL != nil {
		// Strip public base url prefix if user sends full URL in update payload
		val := strings.TrimSpace(*req.AvatarURL)
		if after, ok := strings.CutPrefix(val, s.publicBaseURL); ok {
			val = after
		}
		update.AvatarURL = val
	}
	if req.PreferredLanguage != nil {
		update.PreferredLanguage = strings.TrimSpace(*req.PreferredLanguage)
		if update.PreferredLanguage == "" {
			update.PreferredLanguage = current.PreferredLanguage
		}
	}
	if req.RegisteredCountryID != nil {
		targetCountryID := strings.ToUpper(strings.TrimSpace(*req.RegisteredCountryID))
		if targetCountryID != "" {
			targetCountry, err := s.repo.GetCountry(ctx, targetCountryID)
			if err != nil {
				if errors.Is(err, ErrNotFound) {
					return Profile{}, ErrUnsupportedCountry
				}
				return Profile{}, err
			}
			if err := s.repo.EnsureAccount(ctx, current.UserID, targetCountry); err != nil {
				return Profile{}, err
			}
			update.RegisteredCountryID = targetCountry.ID
			countryID = targetCountry.ID
		}
	}
	if req.MarketingOptIn != nil {
		update.MarketingOptIn = *req.MarketingOptIn
	}

	if err := s.repo.UpdateProfile(ctx, current.UserID, update); err != nil {
		return Profile{}, err
	}
	prof, err := s.repo.GetProfile(ctx, current.UserID, countryID)
	if err != nil {
		return Profile{}, err
	}
	prof.AvatarURL = resolveAssetURL(s.publicBaseURL, prof.AvatarURL)
	return prof, nil
}

func (s *Service) WalletHistory(ctx context.Context, countryID, userID string) (WalletHistory, error) {
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return WalletHistory{}, ErrUserIDRequired
	}
	country, err := s.repo.GetCountry(ctx, countryID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return WalletHistory{}, ErrUnsupportedCountry
		}
		return WalletHistory{}, err
	}
	if err := s.repo.EnsureAccount(ctx, userID, country); err != nil {
		return WalletHistory{}, err
	}
	return s.repo.ListWalletTransactions(ctx, userID, country.ID, defaultHistoryLimit)
}

func (s *Service) LoyaltyHistory(ctx context.Context, countryID, userID string) (LoyaltyHistory, error) {
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return LoyaltyHistory{}, ErrUserIDRequired
	}
	country, err := s.repo.GetCountry(ctx, countryID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return LoyaltyHistory{}, ErrUnsupportedCountry
		}
		return LoyaltyHistory{}, err
	}
	if err := s.repo.EnsureAccount(ctx, userID, country); err != nil {
		return LoyaltyHistory{}, err
	}
	return s.repo.ListLoyaltyTransactions(ctx, userID, country.ID, defaultHistoryLimit)
}

func (s *Service) TopUpWallet(ctx context.Context, countryID, userID string, req WalletTopUpRequest) (WalletTopUpResponse, error) {
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return WalletTopUpResponse{}, ErrUserIDRequired
	}
	if req.Amount <= 0 {
		return WalletTopUpResponse{}, ErrInvalidTopUpAmount
	}
	country, err := s.repo.GetCountry(ctx, countryID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return WalletTopUpResponse{}, ErrUnsupportedCountry
		}
		return WalletTopUpResponse{}, err
	}
	if err := s.repo.EnsureAccount(ctx, userID, country); err != nil {
		return WalletTopUpResponse{}, err
	}

	methodCode := strings.TrimSpace(req.PaymentMethod)
	if methodCode == "" {
		methodCode = "FPX"
	}

	paymentReq := payments.StartPaymentRequest{
		CountryID:    country.ID,
		UserID:       userID,
		BrandID:      0,
		MethodCode:   methodCode,
		CurrencyCode: country.CurrencyCode,
		Amount:       req.Amount,
	}

	tx, err := s.payments.StartPayment(ctx, paymentReq)
	if err != nil {
		return WalletTopUpResponse{}, err
	}

	return WalletTopUpResponse{
		Payment: &tx,
	}, nil
}

var (
	ErrUnsupportedCountry = errors.New("unsupported country")
	ErrUserIDRequired     = errors.New("user_id is required")
	ErrInvalidTopUpAmount = errors.New("top-up amount must be greater than zero")
)

const defaultHistoryLimit = 50

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
