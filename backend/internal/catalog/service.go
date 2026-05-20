package catalog

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/loob/backend/internal/database"
)

type Service struct {
	repo               CatalogRepository
	publicBaseURL      string
	menuCacheTTL       time.Duration
	storeContextTTL    time.Duration
	menuRebuildLockTTL time.Duration
}

type MenuRequest struct {
	CountryCode string
	Language    string
	StoreID     int
	StoreCode   string
	BrandID     int
}

type CategoryItemsRequest struct {
	CountryCode string
	Language    string
	StoreID     int
	StoreCode   string
	BrandID     int
	CategoryID  int
}

type ItemRequest struct {
	CountryCode string
	Language    string
	StoreID     int
	StoreCode   string
	ItemID      int
}

func NewService(repo CatalogRepository, publicBaseURL string) *Service {
	return &Service{
		repo:               repo,
		publicBaseURL:      publicBaseURL,
		menuCacheTTL:       durationEnv("CATALOG_MENU_CACHE_TTL", 24*time.Hour),
		storeContextTTL:    durationEnv("CATALOG_STORE_CONTEXT_CACHE_TTL", 5*time.Minute),
		menuRebuildLockTTL: durationEnv("CATALOG_MENU_REBUILD_LOCK_TTL", 10*time.Second),
	}
}

func durationEnv(key string, fallback time.Duration) time.Duration {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback
	}
	value, err := time.ParseDuration(raw)
	if err != nil || value <= 0 {
		return fallback
	}
	return value
}

func (s *Service) resolveStoreContextCached(ctx context.Context, countryID string, storeID int, storeCode string) (StoreContext, error) {
	cacheKey := fmt.Sprintf("catalog:storectx:%s:%d:%s", countryID, storeID, storeCode)
	if database.RedisClientInstance != nil {
		cached, err := database.RedisClientInstance.Get(ctx, cacheKey)
		if err == nil {
			var store StoreContext
			if err := json.Unmarshal([]byte(cached), &store); err == nil {
				return store, nil
			}
		}
	}

	store, err := s.repo.ResolveStoreContext(ctx, countryID, storeID, storeCode)
	if err != nil {
		return StoreContext{}, err
	}

	if database.RedisClientInstance != nil {
		if data, err := json.Marshal(store); err == nil {
			_ = database.RedisClientInstance.Set(ctx, cacheKey, string(data), s.storeContextTTL)
		}
	}

	return store, nil
}

func (s *Service) getStoreCacheVersion(ctx context.Context, storeIdentifier string) string {
	if database.RedisClientInstance == nil {
		return "0"
	}
	versionKey := fmt.Sprintf("catalog:menu:version:store:%s", storeIdentifier)
	ver, err := database.RedisClientInstance.Get(ctx, versionKey)
	if err != nil || ver == "" {
		return "0"
	}
	return ver
}

func (s *Service) ListCategories(ctx context.Context, req MenuRequest) (CategoryList, error) {
	countryCode := req.CountryCode
	if req.StoreCode != "" {
		parts := strings.SplitN(req.StoreCode, "-", 2)
		if len(parts) >= 2 && len(parts[0]) == 2 {
			countryCode = strings.ToUpper(parts[0])
		}
	}

	var country Country
	var err error
	if cachedCountry, ok := CountryConfigMap[countryCode]; ok {
		country = cachedCountry
	} else {
		country, err = s.repo.GetCountry(ctx, countryCode)
		if err != nil {
			if errors.Is(err, ErrNotFound) {
				return CategoryList{}, ErrUnsupportedCountry
			}
			return CategoryList{}, err
		}
	}

	store, err := s.resolveStoreContextCached(ctx, countryCode, req.StoreID, req.StoreCode)
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

	// Build Versioned Cache Key to avoid expensive wildcard key scans
	var storeIdentifier string
	if req.StoreCode != "" {
		storeIdentifier = req.StoreCode
	} else {
		storeIdentifier = fmt.Sprintf("id-%d", store.StoreID)
	}

	version := s.getStoreCacheVersion(ctx, storeIdentifier)
	cacheKey := fmt.Sprintf("catalog:menu:%s:%s:store:%s:brand:%d:v:%s", countryCode, language, storeIdentifier, brandID, version)

	if database.RedisClientInstance != nil {
		cached, err := database.RedisClientInstance.Get(ctx, cacheKey)
		if err == nil {
			var cachedList CategoryList
			if err := json.Unmarshal([]byte(cached), &cachedList); err == nil {
				return cachedList, nil
			}
		}
	}

	unlock, cachedList, ok := s.waitForMenuRebuildSlot(ctx, cacheKey)
	if ok {
		return cachedList, nil
	}
	if unlock != nil {
		defer unlock()
		if database.RedisClientInstance != nil {
			cached, err := database.RedisClientInstance.Get(ctx, cacheKey)
			if err == nil {
				var cachedList CategoryList
				if err := json.Unmarshal([]byte(cached), &cachedList); err == nil {
					return cachedList, nil
				}
			}
		}
	}

	categories, products, err := s.listCategoriesAndProducts(ctx, store, brandID)
	if err != nil {
		return CategoryList{}, err
	}

	menuItemIDs := make([]int, 0, len(products))
	for _, product := range products {
		menuItemIDs = append(menuItemIDs, product.ID)
	}

	groups, err := s.repo.ListCustomizationGroups(ctx, menuItemIDs)
	if err != nil {
		return CategoryList{}, err
	}

	groupIDs := make([]int, 0, len(groups))
	for _, group := range groups {
		groupIDs = append(groupIDs, group.ID)
	}

	options, err := s.repo.ListCustomizationOptions(ctx, store.StoreID, store.ZoneID, groupIDs)
	if err != nil {
		return CategoryList{}, err
	}

	productsPayload, taxInclusive := buildProducts(products, groups, options, language, country.DefaultLanguage, s.publicBaseURL)

	productIDToCategoryID := make(map[int]int)
	for _, p := range products {
		productIDToCategoryID[p.ID] = p.CategoryID
	}

	productsByCategory := make(map[int][]Product)
	for _, p := range productsPayload {
		catID := productIDToCategoryID[p.ID]
		productsByCategory[catID] = append(productsByCategory[catID], p)
	}

	catalogCategories := make([]Category, 0, len(categories))
	brand := "loob"
	for _, category := range categories {
		if brandID > 0 {
			brand = category.BrandSlug
		}
		catProducts := productsByCategory[category.ID]
		if len(catProducts) == 0 {
			continue
		}
		catalogCategories = append(catalogCategories, Category{
			ID:           category.ID,
			DisplayOrder: category.DisplayOrder,
			Name:         localize(category.NameTranslations, language, country.DefaultLanguage),
			IconURL:      resolveAssetURL(s.publicBaseURL, category.IconURL.String),
			Products:     catProducts,
		})
	}

	res := CategoryList{
		CatalogVersion: "v2",
		Brand:          brand,
		CountryCode:    country.ID,
		Currency:       country.CurrencyCode,
		TaxInclusive:   taxInclusive,
		Language:       language,
		Categories:     catalogCategories,
	}

	if database.RedisClientInstance != nil {
		if data, err := json.Marshal(res); err == nil {
			_ = database.RedisClientInstance.Set(ctx, cacheKey, string(data), s.menuCacheTTL)
		}
	}

	return res, nil
}

func (s *Service) listCategoriesAndProducts(ctx context.Context, store StoreContext, brandID int) ([]CategoryRow, []ProductRow, error) {
	queryCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	var wg sync.WaitGroup
	var categories []CategoryRow
	var products []ProductRow
	errCh := make(chan error, 2)

	wg.Add(2)
	go func() {
		defer wg.Done()
		rows, err := s.repo.ListCategories(queryCtx, brandID)
		if err != nil {
			errCh <- err
			cancel()
			return
		}
		categories = rows
	}()
	go func() {
		defer wg.Done()
		rows, err := s.repo.ListProducts(queryCtx, store.StoreID, store.ZoneID, brandID, 0)
		if err != nil {
			errCh <- err
			cancel()
			return
		}
		products = rows
	}()

	wg.Wait()
	close(errCh)
	for err := range errCh {
		if err != nil {
			return nil, nil, err
		}
	}

	return categories, products, nil
}

func (s *Service) waitForMenuRebuildSlot(ctx context.Context, cacheKey string) (func(), CategoryList, bool) {
	if database.RedisClientInstance == nil {
		return nil, CategoryList{}, false
	}
	lockKey := "lock:" + cacheKey
	token := fmt.Sprintf("%d", time.Now().UnixNano())
	for attempt := 0; attempt < 8; attempt++ {
		locked, err := database.RedisClientInstance.SetNX(ctx, lockKey, token, s.menuRebuildLockTTL)
		if err != nil {
			return nil, CategoryList{}, false
		}
		if locked {
			return func() {
				_ = database.RedisClientInstance.Del(context.Background(), lockKey)
			}, CategoryList{}, false
		}
		select {
		case <-ctx.Done():
			return nil, CategoryList{}, false
		case <-time.After(75 * time.Millisecond):
		}
		cached, err := database.RedisClientInstance.Get(ctx, cacheKey)
		if err == nil && cached != "" {
			var cachedList CategoryList
			if err := json.Unmarshal([]byte(cached), &cachedList); err == nil {
				return nil, cachedList, true
			}
		}
	}
	return nil, CategoryList{}, false
}

func (s *Service) ListCategoryItems(ctx context.Context, req CategoryItemsRequest) (CategoryItems, error) {
	countryCode := req.CountryCode
	if req.StoreCode != "" {
		parts := strings.SplitN(req.StoreCode, "-", 2)
		if len(parts) >= 2 && len(parts[0]) == 2 {
			countryCode = strings.ToUpper(parts[0])
		}
	}

	var country Country
	var err error
	if cachedCountry, ok := CountryConfigMap[countryCode]; ok {
		country = cachedCountry
	} else {
		country, err = s.repo.GetCountry(ctx, countryCode)
		if err != nil {
			if errors.Is(err, ErrNotFound) {
				return CategoryItems{}, ErrUnsupportedCountry
			}
			return CategoryItems{}, err
		}
	}

	store, err := s.resolveStoreContextCached(ctx, countryCode, req.StoreID, req.StoreCode)
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
	productsPayload, taxInclusive := buildProducts(products, groups, options, language, country.DefaultLanguage, s.publicBaseURL)

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
	countryCode := req.CountryCode
	if req.StoreCode != "" {
		parts := strings.SplitN(req.StoreCode, "-", 2)
		if len(parts) >= 2 && len(parts[0]) == 2 {
			countryCode = strings.ToUpper(parts[0])
		}
	}

	var country Country
	var err error
	if cachedCountry, ok := CountryConfigMap[countryCode]; ok {
		country = cachedCountry
	} else {
		country, err = s.repo.GetCountry(ctx, countryCode)
		if err != nil {
			if errors.Is(err, ErrNotFound) {
				return Product{}, ErrUnsupportedCountry
			}
			return Product{}, err
		}
	}

	store, err := s.resolveStoreContextCached(ctx, countryCode, req.StoreID, req.StoreCode)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return Product{}, ErrStoreNotFound
		}
		return Product{}, err
	}

	// Scope query to a single product point lookup directly in DB to optimize detail path under load
	foundRow, err := s.repo.GetProductByID(ctx, store.StoreID, store.ZoneID, req.ItemID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return Product{}, ErrItemNotFound
		}
		return Product{}, err
	}

	groups, err := s.repo.ListCustomizationGroups(ctx, []int{foundRow.ID})
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
	productsPayload, _ := buildProducts([]ProductRow{foundRow}, groups, options, language, country.DefaultLanguage, s.publicBaseURL)

	if len(productsPayload) == 0 {
		return Product{}, ErrItemNotFound
	}
	return productsPayload[0], nil
}

func buildProducts(products []ProductRow, groups []GroupRow, options []OptionRow, language string, fallback string, publicBaseURL string) ([]Product, bool) {
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
				ImageURLSmall: resolveAssetURL(publicBaseURL, product.ImageURLSmall),
				ImageURLLarge: resolveAssetURL(publicBaseURL, product.ImageURLLarge),
			},
			BasePrice:           product.BasePrice,
			DietaryTags:         product.DietaryTags,
			CustomizationGroups: groupsByProduct[product.ID],
			IsPromo:             product.IsPromo,
		})
	}
	return out, taxInclusive
}

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

// InvalidateMenuCache increments the store menu version in Redis.
func (s *Service) InvalidateMenuCache(ctx context.Context, countryCode, storeCode string) error {
	// Resolve the store context to obtain storeID
	var storeIDKey string
	store, err := s.repo.ResolveStoreContext(ctx, countryCode, 0, storeCode)
	if err == nil {
		storeIDKey = fmt.Sprintf("id-%d", store.StoreID)
	}

	if database.RedisClientInstance == nil {
		return nil
	}
	_ = database.RedisClientInstance.Del(ctx, fmt.Sprintf("catalog:storectx:%s:%d:%s", countryCode, 0, storeCode))
	if storeIDKey != "" {
		_ = database.RedisClientInstance.Del(ctx, fmt.Sprintf("catalog:storectx:%s:%d:", countryCode, store.StoreID))
	}

	if storeCode != "" {
		versionKey := fmt.Sprintf("catalog:menu:version:store:%s", storeCode)
		_, err = database.RedisClientInstance.Incr(ctx, versionKey)
		if err != nil {
			return err
		}
	}

	// Also increment store version for numeric id-{storeID} mapping to support mobile traffic paths
	if storeIDKey != "" {
		versionKeyID := fmt.Sprintf("catalog:menu:version:store:%s", storeIDKey)
		_, err = database.RedisClientInstance.Incr(ctx, versionKeyID)
		if err != nil {
			return err
		}
	}

	return nil
}
