package users

import (
	"context"
	"errors"
	"strings"
)

type ProfileRepository interface {
	GetCountry(ctx context.Context, countryID string) (Country, error)
	EnsureAccount(ctx context.Context, userID string, country Country) error
	GetProfile(ctx context.Context, userID, countryID string) (Profile, error)
	UpdateProfile(ctx context.Context, userID string, update ProfileUpdate) error
}

type Service struct {
	repo ProfileRepository
}

func NewService(repo ProfileRepository) *Service {
	return &Service{repo: repo}
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
	return s.repo.GetProfile(ctx, userID, country.ID)
}

func (s *Service) UpdateProfile(ctx context.Context, countryID, userID string, req UpdateProfileRequest) (Profile, error) {
	current, err := s.Profile(ctx, countryID, userID)
	if err != nil {
		return Profile{}, err
	}

	update := ProfileUpdate{
		DisplayName:       current.DisplayName,
		Email:             current.Email,
		PhoneNumber:       current.PhoneNumber,
		AvatarURL:         current.AvatarURL,
		PreferredLanguage: current.PreferredLanguage,
		MarketingOptIn:    current.MarketingOptIn,
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
		update.AvatarURL = strings.TrimSpace(*req.AvatarURL)
	}
	if req.PreferredLanguage != nil {
		update.PreferredLanguage = strings.TrimSpace(*req.PreferredLanguage)
		if update.PreferredLanguage == "" {
			update.PreferredLanguage = current.PreferredLanguage
		}
	}
	if req.MarketingOptIn != nil {
		update.MarketingOptIn = *req.MarketingOptIn
	}

	if err := s.repo.UpdateProfile(ctx, current.UserID, update); err != nil {
		return Profile{}, err
	}
	return s.repo.GetProfile(ctx, current.UserID, countryID)
}

var (
	ErrUnsupportedCountry = errors.New("unsupported country")
	ErrUserIDRequired     = errors.New("user_id is required")
)
