package catalog

import (
	"context"
	"errors"
	"testing"
)

type mockRepository struct {
	CatalogRepository
	getCountry               func(ctx context.Context, countryID string) (Country, error)
	resolveStoreContext      func(ctx context.Context, countryID string, storeID int) (StoreContext, error)
	listCategories           func(ctx context.Context, brandID int) ([]CategoryRow, error)
	listProducts             func(ctx context.Context, storeID int, zoneID string, brandID int, categoryID int) ([]ProductRow, error)
	listCustomizationGroups  func(ctx context.Context, menuItemIDs []int) ([]GroupRow, error)
	listCustomizationOptions func(ctx context.Context, storeID int, zoneID string, groupIDs []int) ([]OptionRow, error)
	listStores               func(ctx context.Context, countryID string, brandID int, activeOnly bool) ([]StoreRow, error)
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
func (m *mockRepository) ListProducts(ctx context.Context, storeID int, zoneID string, brandID int, categoryID int) ([]ProductRow, error) {
	return m.listProducts(ctx, storeID, zoneID, brandID, categoryID)
}
func (m *mockRepository) ListCustomizationGroups(ctx context.Context, menuItemIDs []int) ([]GroupRow, error) {
	return m.listCustomizationGroups(ctx, menuItemIDs)
}
func (m *mockRepository) ListCustomizationOptions(ctx context.Context, storeID int, zoneID string, groupIDs []int) ([]OptionRow, error) {
	return m.listCustomizationOptions(ctx, storeID, zoneID, groupIDs)
}
func (m *mockRepository) ListStores(ctx context.Context, countryID string, brandID int, activeOnly bool) ([]StoreRow, error) {
	return m.listStores(ctx, countryID, brandID, activeOnly)
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

func TestListCategoriesAndCategoryItems(t *testing.T) {
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
		listProducts: func(ctx context.Context, storeID int, zoneID string, brandID int, categoryID int) ([]ProductRow, error) {
			if categoryID == 0 || categoryID == 1 {
				return []ProductRow{
					{ID: 101, CategoryID: 1, SKUCode: "P1", IsAvailable: true, NameTranslations: map[string]string{"en": "Tea"}, BasePrice: 500, TaxInclusive: true},
				}, nil
			}
			return nil, nil
		},
		listCustomizationGroups: func(ctx context.Context, menuItemIDs []int) ([]GroupRow, error) {
			return []GroupRow{
				{ID: 10, MenuItemID: 101, GroupCode: "sugar", NameTranslations: map[string]string{"en": "Sugar Level"}, SelectionType: "SINGLE_SELECT", MinSelections: 1, IsRequired: true, MaxSelections: 1},
			}, nil
		},
		listCustomizationOptions: func(ctx context.Context, storeID int, zoneID string, groupIDs []int) ([]OptionRow, error) {
			return []OptionRow{
				{ID: 1001, GroupID: 10, OptionCode: "sugar_50", NameTranslations: map[string]string{"en": "Half Sugar"}, IsDefault: true, IsAvailable: true},
			}, nil
		},
	}

	svc := NewService(repo, "")

	t.Run("list categories success", func(t *testing.T) {
		catalog, err := svc.ListCategories(context.Background(), MenuRequest{CountryCode: "MY"})
		if err != nil {
			t.Fatal(err)
		}

		if catalog.CountryCode != "MY" {
			t.Errorf("expected MY, got %s", catalog.CountryCode)
		}

		// Empty categories (ID: 2) are now filtered out on the backend
		if len(catalog.Categories) != 1 {
			t.Errorf("expected 1 active category, got %d", len(catalog.Categories))
		}
		if catalog.Categories[0].ID != 1 {
			t.Errorf("expected category 1, got %d", catalog.Categories[0].ID)
		}
		if len(catalog.Categories[0].Products) != 1 {
			t.Errorf("expected categories endpoint to prepopulate products, got %d", len(catalog.Categories[0].Products))
		}
	})

	t.Run("list category items success", func(t *testing.T) {
		items, err := svc.ListCategoryItems(context.Background(), CategoryItemsRequest{CountryCode: "MY", CategoryID: 1})
		if err != nil {
			t.Fatal(err)
		}

		if items.CountryCode != "MY" {
			t.Errorf("expected MY, got %s", items.CountryCode)
		}
		if items.CategoryID != 1 {
			t.Errorf("expected category 1, got %d", items.CategoryID)
		}
		if len(items.Products) != 1 {
			t.Fatalf("expected 1 product, got %d", len(items.Products))
		}
		groups := items.Products[0].CustomizationGroups
		if len(groups) != 1 {
			t.Fatalf("expected 1 customization group, got %d", len(groups))
		}
		if groups[0].Code != "sugar" || groups[0].MinSelections != 1 {
			t.Fatalf("unexpected group payload: %+v", groups[0])
		}
	})

	t.Run("unsupported country", func(t *testing.T) {
		_, err := svc.ListCategories(context.Background(), MenuRequest{CountryCode: "XX"})
		if !errors.Is(err, ErrUnsupportedCountry) {
			t.Errorf("expected ErrUnsupportedCountry, got %v", err)
		}
	})
}
