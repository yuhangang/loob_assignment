package catalog

import (
	"context"
	"errors"
	"strings"
)

type Service struct {
	repo CatalogRepository
}

type MenuRequest struct {
	CountryCode string
	Language    string
	StoreID     int
	BrandID     int
}

func NewService(repo CatalogRepository) *Service {
	return &Service{repo: repo}
}


func (s *Service) GetMenu(ctx context.Context, req MenuRequest) (Catalog, error) {
	country, err := s.repo.GetCountry(ctx, req.CountryCode)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return Catalog{}, ErrUnsupportedCountry
		}
		return Catalog{}, err
	}

	store, err := s.repo.ResolveStoreContext(ctx, req.CountryCode, req.StoreID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return Catalog{}, ErrStoreNotFound
		}
		return Catalog{}, err
	}

	brandID := req.BrandID
	if brandID == 0 && req.StoreID > 0 {
		brandID = store.BrandID
	}

	categories, err := s.repo.ListCategories(ctx, brandID)
	if err != nil {
		return Catalog{}, err
	}
	products, err := s.repo.ListProducts(ctx, store.ZoneID, brandID)
	if err != nil {
		return Catalog{}, err
	}

	menuItemIDs := make([]int, 0, len(products))
	for _, product := range products {
		menuItemIDs = append(menuItemIDs, product.ID)
	}

	groups, err := s.repo.ListCustomizationGroups(ctx, menuItemIDs)
	if err != nil {
		return Catalog{}, err
	}

	groupIDs := make([]int, 0, len(groups))
	for _, group := range groups {
		groupIDs = append(groupIDs, group.ID)
	}

	options, err := s.repo.ListCustomizationOptions(ctx, groupIDs)
	if err != nil {
		return Catalog{}, err
	}

	language := resolveLanguage(req.Language, country.DefaultLanguage)
	optionsByGroup := map[int][]CustomizationOption{}
	for _, option := range options {
		optionsByGroup[option.GroupID] = append(optionsByGroup[option.GroupID], CustomizationOption{
			ID:              option.ID,
			Name:            localize(option.NameTranslations, language, country.DefaultLanguage),
			PriceAdjustment: option.PriceAdjustment,
			IsDefault:       option.IsDefault,
		})
	}

	groupsByProduct := map[int][]CustomizationGroup{}
	for _, group := range groups {
		groupsByProduct[group.MenuItemID] = append(groupsByProduct[group.MenuItemID], CustomizationGroup{
			ID:            group.ID,
			Type:          group.SelectionType,
			Required:      group.IsRequired,
			MaxSelections: group.MaxSelections,
			Name:          localize(group.NameTranslations, language, country.DefaultLanguage),
			Options:       optionsByGroup[group.ID],
		})
	}

	productsByCategory := map[int][]Product{}
	taxInclusive := true
	for _, product := range products {
		taxInclusive = taxInclusive && product.TaxInclusive
		productsByCategory[product.CategoryID] = append(productsByCategory[product.CategoryID], Product{
			ID:          product.ID,
			SKUCode:     product.SKUCode,
			IsAvailable: true,
			Name:        localize(product.NameTranslations, language, country.DefaultLanguage),
			Description: localize(product.DescTranslations, language, country.DefaultLanguage),
			Media: Media{
				ImageURLSmall: product.ImageURLSmall,
				ImageURLLarge: product.ImageURLLarge,
			},
			BasePrice:           product.BasePrice,
			DietaryTags:         product.DietaryTags,
			CustomizationGroups: groupsByProduct[product.ID],
		})
	}

	catalogCategories := make([]Category, 0, len(categories))
	brand := "loob"
	for _, category := range categories {
		categoryProducts := productsByCategory[category.ID]
		if len(categoryProducts) == 0 {
			continue
		}
		if brandID > 0 {
			brand = category.BrandSlug
		}
		catalogCategories = append(catalogCategories, Category{
			ID:           category.ID,
			DisplayOrder: category.DisplayOrder,
			Name:         localize(category.NameTranslations, language, country.DefaultLanguage),
			Products:     categoryProducts,
		})
	}

	return Catalog{
		CatalogVersion: "v1",
		Brand:          brand,
		CountryCode:    country.ID,
		Currency:       country.CurrencyCode,
		TaxInclusive:   taxInclusive,
		Language:       language,
		Categories:     catalogCategories,
	}, nil
}

func (s *Service) ListBrands(ctx context.Context) ([]Brand, error) {
	rows, err := s.repo.ListBrands(ctx)
	if err != nil {
		return nil, err
	}

	brands := make([]Brand, 0, len(rows))
	for _, row := range rows {
		brands = append(brands, Brand{
			ID:           row.ID,
			Slug:         row.Slug,
			Name:         row.Name,
			PrimaryColor: row.ThemeConfig["primary"],
			AccentColor:  row.ThemeConfig["accent"],
		})
	}
	return brands, nil
}

func (s *Service) ListStores(ctx context.Context, countryID, language string) ([]Store, error) {
	var fallback string
	if countryID != "" {
		country, err := s.repo.GetCountry(ctx, countryID)
		if err == nil {
			fallback = country.DefaultLanguage
		}
	}
	if fallback == "" {
		fallback = "en-US"
	}

	rows, err := s.repo.ListStores(ctx, countryID)
	if err != nil {
		return nil, err
	}

	resolvedLanguage := resolveLanguage(language, fallback)
	stores := make([]Store, 0, len(rows))
	for _, row := range rows {
		stores = append(stores, Store{
			ID:        row.ID,
			BrandID:   row.BrandID,
			CountryID: row.CountryID,
			ZoneID:    row.ZoneID,
			StoreCode: row.StoreCode,
			Name:      localize(row.NameTranslations, resolvedLanguage, fallback),
			Latitude:  row.Latitude,
			Longitude: row.Longitude,
			Address:   localize(row.AddressTranslations, resolvedLanguage, fallback),
			IsActive:  row.IsActive,
		})
	}
	return stores, nil
}

var (
	ErrUnsupportedCountry = errors.New("unsupported country")
	ErrStoreNotFound      = errors.New("store not found")
)

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
