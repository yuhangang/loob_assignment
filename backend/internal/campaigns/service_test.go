package campaigns

import (
	"context"
	"errors"
	"testing"
)

type mockRepository struct {
	getCountry func(ctx context.Context, countryID string) (Country, error)
	listActive func(ctx context.Context, countryID string, brandID int) ([]CampaignRow, error)
}

func (m *mockRepository) GetCountry(ctx context.Context, countryID string) (Country, error) {
	return m.getCountry(ctx, countryID)
}
func (m *mockRepository) ListActive(ctx context.Context, countryID string, brandID int) ([]CampaignRow, error) {
	return m.listActive(ctx, countryID, brandID)
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

func TestLocalize(t *testing.T) {
	values := map[string]string{
		"en":    "Hello",
		"ms":    "Halo",
		"en-US": "Hi",
	}

	tests := []struct {
		name     string
		lang     string
		fallback string
		want     string
	}{
		{"exact match", "ms", "en", "Halo"},
		{"dialect match", "en-US", "en", "Hi"},
		{"fallback", "fr", "en", "Hello"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := localize(values, tt.lang, tt.fallback); got != tt.want {
				t.Errorf("localize() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestHome(t *testing.T) {
	repo := &mockRepository{
		getCountry: func(ctx context.Context, countryID string) (Country, error) {
			if countryID == "MY" {
				return Country{ID: "MY", DefaultLanguage: "en-US"}, nil
			}
			return Country{}, ErrNotFound
		},
		listActive: func(ctx context.Context, countryID string, brandID int) ([]CampaignRow, error) {
			return []CampaignRow{
				{ID: 1, CampaignType: "BANNER", TitleTranslations: map[string]string{"en": "Promo"}},
				{ID: 2, CampaignType: "MODULE", TitleTranslations: map[string]string{"en": "News"}},
			}, nil
		},
	}

	svc := NewService(repo)

	t.Run("success", func(t *testing.T) {
		feed, err := svc.Home(context.Background(), "MY", "en", 0)
		if err != nil {
			t.Fatal(err)
		}

		if len(feed.Banners) != 1 {
			t.Errorf("expected 1 banner, got %d", len(feed.Banners))
		}
		if len(feed.Modules) != 1 {
			t.Errorf("expected 1 module, got %d", len(feed.Modules))
		}
	})

	t.Run("unsupported country", func(t *testing.T) {
		_, err := svc.Home(context.Background(), "XX", "en", 0)
		if !errors.Is(err, ErrUnsupportedCountry) {
			t.Errorf("expected ErrUnsupportedCountry, got %v", err)
		}
	})
}
