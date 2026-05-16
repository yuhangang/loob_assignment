package campaigns

import (
	"context"
	"errors"
	"strings"
)

type CampaignRepository interface {
	GetCountry(ctx context.Context, countryID string) (Country, error)
	ListActive(ctx context.Context, countryID string, brandID int) ([]CampaignRow, error)
}

type Service struct {
	repo CampaignRepository
}

func NewService(repo CampaignRepository) *Service {
	return &Service{repo: repo}
}

func (s *Service) Home(ctx context.Context, countryID, language string, brandID int) (HomeFeed, error) {
	country, err := s.repo.GetCountry(ctx, countryID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return HomeFeed{}, ErrUnsupportedCountry
		}
		return HomeFeed{}, err
	}

	rows, err := s.repo.ListActive(ctx, countryID, brandID)
	if err != nil {
		return HomeFeed{}, err
	}

	resolved := resolveLanguage(language, country.DefaultLanguage)
	feed := HomeFeed{
		CountryCode: country.ID,
		Language:    resolved,
		Banners:     []Campaign{},
		Modules:     []Campaign{},
	}
	for _, row := range rows {
		campaign := Campaign{
			ID:         row.ID,
			Type:       row.CampaignType,
			Title:      localize(row.TitleTranslations, resolved, country.DefaultLanguage),
			Subtitle:   localize(row.SubtitleTranslations, resolved, country.DefaultLanguage),
			ImageURL:   row.ImageURL,
			DeepLink:   row.DeepLink,
			WebviewURL: row.WebviewURL,
			Priority:   row.Priority,
			Metadata:   row.Metadata,
		}
		if row.BrandID.Valid {
			brandID := int(row.BrandID.Int64)
			campaign.BrandID = &brandID
		}
		if row.CampaignType == "BANNER" || row.CampaignType == "FLASH_SALE" {
			feed.Banners = append(feed.Banners, campaign)
			continue
		}
		feed.Modules = append(feed.Modules, campaign)
	}
	return feed, nil
}

var ErrUnsupportedCountry = errors.New("unsupported country")

func resolveLanguage(language, fallback string) string {
	if strings.TrimSpace(language) == "" {
		return fallback
	}
	return language
}

func localize(values map[string]string, language, fallback string) string {
	candidates := []string{language}
	if i := strings.Index(language, "-"); i > 0 {
		candidates = append(candidates, language[:i])
	}
	candidates = append(candidates, fallback, "en-US", "en")

	for _, candidate := range candidates {
		if value := strings.TrimSpace(values[candidate]); value != "" {
			return value
		}
	}
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}
