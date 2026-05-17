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

type CategoryItemsRequest struct {
	CountryCode string
	Language    string
	StoreID     int
	BrandID     int
	CategoryID  int
}

type ItemRequest struct {
	CountryCode string
	Language    string
	StoreID     int
	ItemID      int
}

func NewService(repo CatalogRepository) *Service {
	return &Service{repo: repo}
}

func (s *Service) ListCategories(ctx context.Context, req MenuRequest) (CategoryList, error) {
	country, err := s.repo.GetCountry(ctx, req.CountryCode)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return CategoryList{}, ErrUnsupportedCountry
		}
		return CategoryList{}, err
	}

	store, err := s.repo.ResolveStoreContext(ctx, req.CountryCode, req.StoreID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return CategoryList{}, ErrStoreNotFound
		}
		return CategoryList{}, err
	}

	brandID := req.BrandID
	if brandID == 0 {
		brandID = store.BrandID
	}
	language := resolveLanguage(req.Language, country.DefaultLanguage)

	categories, err := s.repo.ListCategories(ctx, brandID)
	if err != nil {
		return CategoryList{}, err
	}

	catalogCategories := make([]Category, 0, len(categories))
	brand := "loob"
	for _, category := range categories {
		if brandID > 0 {
			brand = category.BrandSlug
		}
		catalogCategories = append(catalogCategories, Category{
			ID:           category.ID,
			DisplayOrder: category.DisplayOrder,
			Name:         localize(category.NameTranslations, language, country.DefaultLanguage),
			IconURL:      category.IconURL.String,
		})
	}

	return CategoryList{
		CatalogVersion: "v2",
		Brand:          brand,
		CountryCode:    country.ID,
		Currency:       country.CurrencyCode,
		TaxInclusive:   true,
		Language:       language,
		Categories:     catalogCategories,
	}, nil
}

func (s *Service) ListCategoryItems(ctx context.Context, req CategoryItemsRequest) (CategoryItems, error) {
	country, err := s.repo.GetCountry(ctx, req.CountryCode)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return CategoryItems{}, ErrUnsupportedCountry
		}
		return CategoryItems{}, err
	}

	store, err := s.repo.ResolveStoreContext(ctx, req.CountryCode, req.StoreID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return CategoryItems{}, ErrStoreNotFound
		}
		return CategoryItems{}, err
	}

	brandID := req.BrandID
	if brandID == 0 {
		brandID = store.BrandID
	}

	products, err := s.repo.ListProducts(ctx, store.StoreID, store.ZoneID, brandID, req.CategoryID)
	if err != nil {
		return CategoryItems{}, err
	}

	menuItemIDs := make([]int, 0, len(products))
	for _, product := range products {
		menuItemIDs = append(menuItemIDs, product.ID)
	}

	groups, err := s.repo.ListCustomizationGroups(ctx, menuItemIDs)
	if err != nil {
		return CategoryItems{}, err
	}

	groupIDs := make([]int, 0, len(groups))
	for _, group := range groups {
		groupIDs = append(groupIDs, group.ID)
	}

	options, err := s.repo.ListCustomizationOptions(ctx, store.StoreID, store.ZoneID, groupIDs)
	if err != nil {
		return CategoryItems{}, err
	}

	language := resolveLanguage(req.Language, country.DefaultLanguage)
	productsPayload, taxInclusive := buildProducts(products, groups, options, language, country.DefaultLanguage)

	return CategoryItems{
		CatalogVersion: "v2",
		Brand:          "loob",
		CountryCode:    country.ID,
		Currency:       country.CurrencyCode,
		TaxInclusive:   taxInclusive,
		Language:       language,
		CategoryID:     req.CategoryID,
		Products:       productsPayload,
	}, nil
}

func (s *Service) GetItem(ctx context.Context, req ItemRequest) (Product, error) {
	country, err := s.repo.GetCountry(ctx, req.CountryCode)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return Product{}, ErrUnsupportedCountry
		}
		return Product{}, err
	}

	store, err := s.repo.ResolveStoreContext(ctx, req.CountryCode, req.StoreID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return Product{}, ErrStoreNotFound
		}
		return Product{}, err
	}

	// Re-use ListProducts with no category filter, scoped to a single item ID.
	products, err := s.repo.ListProducts(ctx, store.StoreID, store.ZoneID, 0, 0)
	if err != nil {
		return Product{}, err
	}

	var found *ProductRow
	for i := range products {
		if products[i].ID == req.ItemID {
			found = &products[i]
			break
		}
	}
	if found == nil {
		return Product{}, ErrItemNotFound
	}

	groups, err := s.repo.ListCustomizationGroups(ctx, []int{found.ID})
	if err != nil {
		return Product{}, err
	}

	groupIDs := make([]int, 0, len(groups))
	for _, g := range groups {
		groupIDs = append(groupIDs, g.ID)
	}

	options, err := s.repo.ListCustomizationOptions(ctx, store.StoreID, store.ZoneID, groupIDs)
	if err != nil {
		return Product{}, err
	}

	language := resolveLanguage(req.Language, country.DefaultLanguage)
	productsPayload, _ := buildProducts([]ProductRow{*found}, groups, options, language, country.DefaultLanguage)
	if len(productsPayload) == 0 {
		return Product{}, ErrItemNotFound
	}
	return productsPayload[0], nil
}

func buildProducts(products []ProductRow, groups []GroupRow, options []OptionRow, language string, fallback string) ([]Product, bool) {
	optionsByGroup := map[int][]CustomizationOption{}
	for _, option := range options {
		optionsByGroup[option.GroupID] = append(optionsByGroup[option.GroupID], CustomizationOption{
			Code:            option.OptionCode,
			ID:              option.ID,
			Name:            localize(option.NameTranslations, language, fallback),
			PriceAdjustment: option.PriceAdjustment,
			IsDefault:       option.IsDefault,
			IsAvailable:     option.IsAvailable,
		})
	}

	groupsByProduct := map[int][]CustomizationGroup{}
	for _, group := range groups {
		groupsByProduct[group.MenuItemID] = append(groupsByProduct[group.MenuItemID], CustomizationGroup{
			Code:          group.GroupCode,
			ID:            group.ID,
			Type:          group.SelectionType,
			Required:      group.MinSelections > 0 || group.IsRequired,
			MinSelections: group.MinSelections,
			MaxSelections: group.MaxSelections,
			Name:          localize(group.NameTranslations, language, fallback),
			Options:       optionsByGroup[group.ID],
		})
	}

	out := make([]Product, 0, len(products))
	taxInclusive := true
	for _, product := range products {
		taxInclusive = taxInclusive && product.TaxInclusive
		out = append(out, Product{
			ID:          product.ID,
			SKUCode:     product.SKUCode,
			IsAvailable: product.IsAvailable,
			Name:        localize(product.NameTranslations, language, fallback),
			Description: localize(product.DescTranslations, language, fallback),
			Media: Media{
				ImageURLSmall: product.ImageURLSmall,
				ImageURLLarge: product.ImageURLLarge,
			},
			BasePrice:           product.BasePrice,
			DietaryTags:         product.DietaryTags,
			CustomizationGroups: groupsByProduct[product.ID],
		})
	}
	return out, taxInclusive
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

func (s *Service) ListStores(ctx context.Context, countryID, language string, brandID int, activeOnly bool) ([]Store, error) {
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

	rows, err := s.repo.ListStores(ctx, countryID, brandID, activeOnly)
	if err != nil {
		return nil, err
	}

	resolvedLanguage := resolveLanguage(language, fallback)
	stores := make([]Store, 0, len(rows))
	for _, row := range rows {
		stores = append(stores, Store{
			ID:                row.ID,
			BrandID:           row.BrandID,
			CountryID:         row.CountryID,
			ZoneID:            row.ZoneID,
			StoreCode:         row.StoreCode,
			Name:              localize(row.NameTranslations, resolvedLanguage, fallback),
			Latitude:          row.Latitude,
			Longitude:         row.Longitude,
			Address:           localize(row.AddressTranslations, resolvedLanguage, fallback),
			IsActive:          row.IsActive,
			OperationalStatus: row.OperationalStatus,
			StatusMessage:     row.StatusMessage.String,
		})
	}
	return stores, nil
}

var (
	ErrUnsupportedCountry = errors.New("unsupported country")
	ErrStoreNotFound      = errors.New("store not found")
	ErrItemNotFound       = errors.New("item not found")
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
