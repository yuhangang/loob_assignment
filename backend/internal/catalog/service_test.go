package catalog

import (
	"context"
	"errors"
	"testing"
)

type mockRepository struct {
	CatalogRepository
	getCountry              func(ctx context.Context, countryID string) (Country, error)
	resolveStoreContext     func(ctx context.Context, countryID string, storeID int) (StoreContext, error)
	listCategories          func(ctx context.Context, brandID int) ([]CategoryRow, error)
	listProducts            func(ctx context.Context, zoneID string, brandID int) ([]ProductRow, error)
	listCustomizationGroups func(ctx context.Context, menuItemIDs []int) ([]GroupRow, error)
	listCustomizationOptions func(ctx context.Context, groupIDs []int) ([]OptionRow, error)
}

func (m *mockRepository) GetCountry(ctx context.Context, countryID string) (Country, error) {
	return m.getCountry(ctx, countryID)
}
func (m *mockRepository) ResolveStoreContext(ctx context.Context, countryID string, storeID int) (StoreContext, error) {
	return m.resolveStoreContext(ctx, countryID, storeID)
}
func (m *mockRepository) ListCategories(ctx context.Context, brandID int) ([]CategoryRow, error) {
	return m.listCategories(ctx, brandID)
}
func (m *mockRepository) ListProducts(ctx context.Context, zoneID string, brandID int) ([]ProductRow, error) {
	return m.listProducts(ctx, zoneID, brandID)
}
func (m *mockRepository) ListCustomizationGroups(ctx context.Context, menuItemIDs []int) ([]GroupRow, error) {
	return m.listCustomizationGroups(ctx, menuItemIDs)
}
func (m *mockRepository) ListCustomizationOptions(ctx context.Context, groupIDs []int) ([]OptionRow, error) {
	return m.listCustomizationOptions(ctx, groupIDs)
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
		"en":    "Water",
		"ms":    "Air",
		"zh":    "水",
		"en-US": "Mineral Water",
	}

	tests := []struct {
		name     string
		lang     string
		fallback string
		want     string
	}{
		{"exact match", "ms", "en", "Air"},
		{"dialect match", "en-US", "en", "Mineral Water"},
		{"fallback to en", "fr", "en", "Water"},
		{"fallback to global default", "fr", "de", "Mineral Water"},

	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := localize(values, tt.lang, tt.fallback); got != tt.want {
				t.Errorf("localize() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestGetMenu(t *testing.T) {
	repo := &mockRepository{
		getCountry: func(ctx context.Context, countryID string) (Country, error) {
			if countryID == "MY" {
				return Country{ID: "MY", CurrencyCode: "MYR", DefaultLanguage: "en-US"}, nil
			}
			return Country{}, ErrNotFound
		},
		resolveStoreContext: func(ctx context.Context, countryID string, storeID int) (StoreContext, error) {
			return StoreContext{StoreID: 1, ZoneID: "Z1", BrandID: 1}, nil
		},
		listCategories: func(ctx context.Context, brandID int) ([]CategoryRow, error) {
			return []CategoryRow{
				{ID: 1, BrandSlug: "tealive", NameTranslations: map[string]string{"en": "Drinks"}},
				{ID: 2, BrandSlug: "tealive", NameTranslations: map[string]string{"en": "Empty"}},
			}, nil
		},
		listProducts: func(ctx context.Context, zoneID string, brandID int) ([]ProductRow, error) {
			return []ProductRow{
				{ID: 101, CategoryID: 1, SKUCode: "P1", NameTranslations: map[string]string{"en": "Tea"}, BasePrice: 500, TaxInclusive: true},
			}, nil
		},
		listCustomizationGroups: func(ctx context.Context, menuItemIDs []int) ([]GroupRow, error) {
			return nil, nil
		},
		listCustomizationOptions: func(ctx context.Context, groupIDs []int) ([]OptionRow, error) {
			return nil, nil
		},
	}

	svc := NewService(repo)

	t.Run("success", func(t *testing.T) {
		catalog, err := svc.GetMenu(context.Background(), MenuRequest{CountryCode: "MY"})
		if err != nil {
			t.Fatal(err)
		}

		if catalog.CountryCode != "MY" {
			t.Errorf("expected MY, got %s", catalog.CountryCode)
		}

		// Verify empty categories are filtered out
		if len(catalog.Categories) != 1 {
			t.Errorf("expected 1 category, got %d", len(catalog.Categories))
		}
		if catalog.Categories[0].ID != 1 {
			t.Errorf("expected category 1, got %d", catalog.Categories[0].ID)
		}
	})

	t.Run("unsupported country", func(t *testing.T) {
		_, err := svc.GetMenu(context.Background(), MenuRequest{CountryCode: "XX"})
		if !errors.Is(err, ErrUnsupportedCountry) {
			t.Errorf("expected ErrUnsupportedCountry, got %v", err)
		}
	})
}
