package catalog

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/loob/backend/internal/database"
)

type mockRepository struct {
	CatalogRepository
	getCountry               func(ctx context.Context, countryID string) (Country, error)
	resolveStoreContext      func(ctx context.Context, countryID string, storeID int, storeCode string) (StoreContext, error)
	listCategories           func(ctx context.Context, brandID int) ([]CategoryRow, error)
	listProducts             func(ctx context.Context, storeID int, zoneID string, brandID int, categoryID int) ([]ProductRow, error)
	getProductByID           func(ctx context.Context, storeID int, zoneID string, itemID int) (ProductRow, error)
	listCustomizationGroups  func(ctx context.Context, menuItemIDs []int) ([]GroupRow, error)
	listCustomizationOptions func(ctx context.Context, storeID int, zoneID string, groupIDs []int) ([]OptionRow, error)
	listStores               func(ctx context.Context, countryID string, brandID int, activeOnly bool, limit int, offset int) ([]StoreRow, error)
}

func (m *mockRepository) GetCountry(ctx context.Context, countryID string) (Country, error) {
	return m.getCountry(ctx, countryID)
}
func (m *mockRepository) ResolveStoreContext(ctx context.Context, countryID string, storeID int, storeCode string) (StoreContext, error) {
	return m.resolveStoreContext(ctx, countryID, storeID, storeCode)
}
func (m *mockRepository) ListCategories(ctx context.Context, brandID int) ([]CategoryRow, error) {
	return m.listCategories(ctx, brandID)
}
func (m *mockRepository) ListProducts(ctx context.Context, storeID int, zoneID string, brandID int, categoryID int) ([]ProductRow, error) {
	return m.listProducts(ctx, storeID, zoneID, brandID, categoryID)
}
func (m *mockRepository) GetProductByID(ctx context.Context, storeID int, zoneID string, itemID int) (ProductRow, error) {
	if m.getProductByID != nil {
		return m.getProductByID(ctx, storeID, zoneID, itemID)
	}
	// Default fallback using ListProducts
	products, err := m.listProducts(ctx, storeID, zoneID, 0, 0)
	if err != nil {
		return ProductRow{}, err
	}
	for _, p := range products {
		if p.ID == itemID {
			return p, nil
		}
	}
	return ProductRow{}, ErrNotFound
}
func (m *mockRepository) ListCustomizationGroups(ctx context.Context, menuItemIDs []int) ([]GroupRow, error) {
	return m.listCustomizationGroups(ctx, menuItemIDs)
}
func (m *mockRepository) ListCustomizationOptions(ctx context.Context, storeID int, zoneID string, groupIDs []int) ([]OptionRow, error) {
	return m.listCustomizationOptions(ctx, storeID, zoneID, groupIDs)
}
func (m *mockRepository) ListStores(ctx context.Context, countryID string, brandID int, activeOnly bool, limit int, offset int) ([]StoreRow, error) {
	return m.listStores(ctx, countryID, brandID, activeOnly, limit, offset)
}

func TestResolveLanguage(t *testing.T) {
	tests := []struct {
		name     string
		lang     string
		fallback string
		want     string
	}{
		{"exact_en", "en-US", "en-US", "en-US"},
		{"use_fallback_on_empty", "", "en-US", "en-US"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := resolveLanguage(tt.lang, tt.fallback); got != tt.want {
				t.Errorf("resolveLanguage() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestNewServiceCacheTTLConfig(t *testing.T) {
	t.Setenv("CATALOG_MENU_CACHE_TTL", "30m")
	t.Setenv("CATALOG_STORE_CONTEXT_CACHE_TTL", "45s")
	t.Setenv("CATALOG_MENU_REBUILD_LOCK_TTL", "3s")

	svc := NewService(&mockRepository{}, "")

	if svc.menuCacheTTL != 30*time.Minute {
		t.Fatalf("menuCacheTTL = %s, want 30m", svc.menuCacheTTL)
	}
	if svc.storeContextTTL != 45*time.Second {
		t.Fatalf("storeContextTTL = %s, want 45s", svc.storeContextTTL)
	}
	if svc.menuRebuildLockTTL != 3*time.Second {
		t.Fatalf("menuRebuildLockTTL = %s, want 3s", svc.menuRebuildLockTTL)
	}
}

func TestNewServiceCacheTTLConfigFallsBack(t *testing.T) {
	t.Setenv("CATALOG_MENU_CACHE_TTL", "bad")
	t.Setenv("CATALOG_STORE_CONTEXT_CACHE_TTL", "0s")
	t.Setenv("CATALOG_MENU_REBUILD_LOCK_TTL", "-1s")

	svc := NewService(&mockRepository{}, "")

	if svc.menuCacheTTL != 24*time.Hour {
		t.Fatalf("menuCacheTTL = %s, want 24h", svc.menuCacheTTL)
	}
	if svc.storeContextTTL != 5*time.Minute {
		t.Fatalf("storeContextTTL = %s, want 5m", svc.storeContextTTL)
	}
	if svc.menuRebuildLockTTL != 10*time.Second {
		t.Fatalf("menuRebuildLockTTL = %s, want 10s", svc.menuRebuildLockTTL)
	}
}

func TestLocalize(t *testing.T) {
	values := map[string]string{
		"en":    "Hello",
		"en-US": "Hello US",
		"th":    "Sawasdee",
	}

	tests := []struct {
		name     string
		lang     string
		fallback string
		want     string
	}{
		{"exact_match", "th", "en", "Sawasdee"},
		{"dialect_match", "en-GB", "en", "Hello"},
		{"fallback_to_en", "fr", "en-US", "Hello US"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := localize(values, tt.lang, tt.fallback); got != tt.want {
				t.Errorf("localize() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestListStoresPaginatesAndLocalizes(t *testing.T) {
	repo := &mockRepository{
		getCountry: func(ctx context.Context, countryID string) (Country, error) {
			if countryID != "MY" {
				t.Fatalf("unexpected country lookup: %s", countryID)
			}
			return Country{ID: "MY", DefaultLanguage: "en-US"}, nil
		},
		listStores: func(ctx context.Context, countryID string, brandID int, activeOnly bool, limit int, offset int) ([]StoreRow, error) {
			if countryID != "MY" || brandID != 1 || !activeOnly {
				t.Fatalf("unexpected filters country=%s brand=%d activeOnly=%v", countryID, brandID, activeOnly)
			}
			if limit != 3 || offset != 2 {
				t.Fatalf("unexpected pagination limit=%d offset=%d", limit, offset)
			}
			return []StoreRow{
				{ID: 3, BrandID: 1, CountryID: "MY", ZoneID: "MY_KV", StoreCode: "MY-TL-003", NameTranslations: map[string]string{"en-US": "Outlet 3"}, AddressTranslations: map[string]string{"en-US": "Address 3"}, IsActive: true, OperationalStatus: "OPEN"},
				{ID: 4, BrandID: 1, CountryID: "MY", ZoneID: "MY_KV", StoreCode: "MY-TL-004", NameTranslations: map[string]string{"en-US": "Outlet 4"}, AddressTranslations: map[string]string{"en-US": "Address 4"}, IsActive: true, OperationalStatus: "OPEN"},
				{ID: 5, BrandID: 1, CountryID: "MY", ZoneID: "MY_KV", StoreCode: "MY-TL-005", NameTranslations: map[string]string{"en-US": "Outlet 5"}, AddressTranslations: map[string]string{"en-US": "Address 5"}, IsActive: true, OperationalStatus: "OPEN"},
			}, nil
		},
	}

	svc := NewService(repo, "")
	res, err := svc.ListStores(context.Background(), "MY", "en-US", 1, true, StoreListRequest{Page: 2, Limit: 2})
	if err != nil {
		t.Fatal(err)
	}
	if res.Page != 2 || res.Limit != 2 || !res.HasMore {
		t.Fatalf("unexpected pagination response: %+v", res)
	}
	if len(res.Items) != 2 {
		t.Fatalf("expected 2 stores, got %d", len(res.Items))
	}
	if res.Items[0].Name != "Outlet 3" || res.Items[1].StoreCode != "MY-TL-004" {
		t.Fatalf("unexpected stores: %+v", res.Items)
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
		resolveStoreContext: func(ctx context.Context, countryID string, storeID int, storeCode string) (StoreContext, error) {
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
		catalog, err := svc.ListCategories(context.Background(), MenuRequest{CountryCode: "MY", StoreCode: "MY-TL-PAV"})
		if err != nil {
			t.Fatal(err)
		}
		if len(catalog.Categories) != 1 {
			t.Fatalf("expected 1 category, got %d", len(catalog.Categories))
		}
		if catalog.Categories[0].Products[0].Name != "Tea" {
			t.Errorf("expected product Tea, got %s", catalog.Categories[0].Products[0].Name)
		}
	})

	t.Run("list category items success", func(t *testing.T) {
		items, err := svc.ListCategoryItems(context.Background(), CategoryItemsRequest{CountryCode: "MY", StoreCode: "MY-TL-PAV", CategoryID: 1})
		if err != nil {
			t.Fatal(err)
		}
		if len(items.Products) != 1 {
			t.Fatalf("expected 1 product, got %d", len(items.Products))
		}
	})

	t.Run("unsupported country", func(t *testing.T) {
		_, err := svc.ListCategories(context.Background(), MenuRequest{CountryCode: "JP"})
		if !errors.Is(err, ErrUnsupportedCountry) {
			t.Errorf("expected ErrUnsupportedCountry, got %v", err)
		}
	})
}

func TestCatalogService_RedisCaching(t *testing.T) {
	// Setup custom DialFn mock over net.Pipe
	store := make(map[string]string)
	var mu sync.Mutex

	dialFn := func(network, addr string) (net.Conn, error) {
		c1, c2 := net.Pipe()

		go func(c net.Conn) {
			defer c.Close()
			reader := bufio.NewReader(c)

			for {
				line, err := reader.ReadString('\n')
				if err != nil {
					return
				}
				if line[0] != '*' {
					continue
				}

				numArgs, _ := strconv.Atoi(line[1 : len(line)-2])
				args := make([]string, numArgs)

				for i := 0; i < numArgs; i++ {
					lenLine, err := reader.ReadString('\n')
					if err != nil {
						return
					}
					length, _ := strconv.Atoi(lenLine[1 : len(lenLine)-2])
					valBuf := make([]byte, length+2)
					_, err = io.ReadFull(reader, valBuf)
					if err != nil {
						return
					}
					args[i] = string(valBuf[:length])
				}

				cmd := strings.ToUpper(args[0])
				mu.Lock()
				switch cmd {
				case "PING":
					c.Write([]byte("+PONG\r\n"))
				case "GET":
					key := args[1]
					val, ok := store[key]
					if !ok {
						c.Write([]byte("$-1\r\n"))
					} else {
						c.Write([]byte(fmt.Sprintf("$%d\r\n%s\r\n", len(val), val)))
					}
				case "SET":
					key := args[1]
					val := args[2]
					store[key] = val
					c.Write([]byte("+OK\r\n"))
				case "INCR":
					key := args[1]
					valStr := store[key]
					valInt, _ := strconv.ParseInt(valStr, 10, 64)
					valInt++
					store[key] = strconv.FormatInt(valInt, 10)
					c.Write([]byte(fmt.Sprintf(":%d\r\n", valInt)))
				case "DEL":
					deletedCount := 0
					for i := 1; i < len(args); i++ {
						if _, ok := store[args[i]]; ok {
							delete(store, args[i])
							deletedCount++
						}
					}
					c.Write([]byte(fmt.Sprintf(":%d\r\n", deletedCount)))
				case "SCAN":
					var keys []string
					matchPattern := args[3]
					for k := range store {
						parts := strings.Split(matchPattern, "*")
						matched := true
						for _, part := range parts {
							if part != "" && !strings.Contains(k, part) {
								matched = false
								break
							}
						}
						if matched {
							keys = append(keys, k)
						}
					}

					var resp []byte
					resp = append(resp, "*2\r\n$1\r\n0\r\n"...) // scan finished cursor = "0"
					resp = append(resp, '*')
					resp = append(resp, []byte(strconv.Itoa(len(keys)))...)
					resp = append(resp, "\r\n"...)
					for _, k := range keys {
						resp = append(resp, '$')
						resp = append(resp, []byte(strconv.Itoa(len(k)))...)
						resp = append(resp, "\r\n"...)
						resp = append(resp, []byte(k)...)
						resp = append(resp, "\r\n"...)
					}
					c.Write(resp)
				}
				mu.Unlock()
			}
		}(c2)

		return c1, nil
	}

	// Initialize our custom database.RedisClientInstance using the dialFn mock dialer
	database.RedisClientInstance = database.NewMockRedisClient(dialFn)
	defer func() {
		database.RedisClientInstance = nil
	}()

	var dbCalls int64
	resetDBCalls := func() {
		atomic.StoreInt64(&dbCalls, 0)
	}
	countDBCall := func() {
		atomic.AddInt64(&dbCalls, 1)
	}
	requireDBCalls := func(t *testing.T, want int64, label string) {
		t.Helper()
		if got := atomic.LoadInt64(&dbCalls); got != want {
			t.Errorf("expected exactly %d database calls %s, got %d", want, label, got)
		}
	}
	repo := &mockRepository{
		getCountry: func(ctx context.Context, countryID string) (Country, error) {
			countDBCall()
			return Country{ID: "MY", CurrencyCode: "MYR", DefaultLanguage: "en-US"}, nil
		},
		resolveStoreContext: func(ctx context.Context, countryID string, storeID int, storeCode string) (StoreContext, error) {
			countDBCall()
			return StoreContext{StoreID: 1, ZoneID: "Z1", BrandID: 1}, nil
		},
		listCategories: func(ctx context.Context, brandID int) ([]CategoryRow, error) {
			countDBCall()
			return []CategoryRow{
				{ID: 1, BrandSlug: "tealive", NameTranslations: map[string]string{"en": "Drinks"}},
			}, nil
		},
		listProducts: func(ctx context.Context, storeID int, zoneID string, brandID int, categoryID int) ([]ProductRow, error) {
			countDBCall()
			return []ProductRow{
				{ID: 101, CategoryID: 1, SKUCode: "P1", IsAvailable: true, NameTranslations: map[string]string{"en": "Tea"}, BasePrice: 500, TaxInclusive: true},
			}, nil
		},
		listCustomizationGroups: func(ctx context.Context, menuItemIDs []int) ([]GroupRow, error) {
			countDBCall()
			return []GroupRow{}, nil
		},
		listCustomizationOptions: func(ctx context.Context, storeID int, zoneID string, groupIDs []int) ([]OptionRow, error) {
			countDBCall()
			return []OptionRow{}, nil
		},
	}

	svc := NewService(repo, "")

	// 1. First Call: Cache Miss, should hit mock database and write to Redis
	t.Run("cache miss writes to redis", func(t *testing.T) {
		resetDBCalls()
		res1, err := svc.ListCategories(context.Background(), MenuRequest{CountryCode: "MY", StoreCode: "MY-TL-PAV"})
		if err != nil {
			t.Fatal(err)
		}
		requireDBCalls(t, 5, "on cache miss")

		// Ensure it wrote to Redis by waiting a tiny bit then making a second call
		time.Sleep(10 * time.Millisecond)

		// 2. Second Call: Cache Hit, should read from Redis directly and NOT hit database at all (exactly 0 DB calls!)
		resetDBCalls()
		res2, err := svc.ListCategories(context.Background(), MenuRequest{CountryCode: "MY", StoreCode: "MY-TL-PAV"})
		if err != nil {
			t.Fatal(err)
		}
		requireDBCalls(t, 0, "on cache hit")

		if res1.Categories[0].Name != res2.Categories[0].Name {
			t.Errorf("cached result name mismatched: got %s, want %s", res2.Categories[0].Name, res1.Categories[0].Name)
		}

		// 3. Third Call: Call InvalidateMenuCache, should clear in-memory cache and incr key version in Redis
		err = svc.InvalidateMenuCache(context.Background(), "MY", "MY-TL-PAV")
		if err != nil {
			t.Fatal(err)
		}

		// 4. Fourth Call: Cache Miss again since the cache key version changed, should hit mock database to rebuild cache
		resetDBCalls()
		_, err = svc.ListCategories(context.Background(), MenuRequest{CountryCode: "MY", StoreCode: "MY-TL-PAV"})
		if err != nil {
			t.Fatal(err)
		}
		requireDBCalls(t, 5, "on cache miss after invalidation")

		// 5. Fifth Call: Query by StoreID numeric, should result in a Cache Miss first to populate the cache
		resetDBCalls()
		_, err = svc.ListCategories(context.Background(), MenuRequest{CountryCode: "MY", StoreID: 1})
		if err != nil {
			t.Fatal(err)
		}
		requireDBCalls(t, 5, "on store_id cache miss")

		// 6. Sixth Call: Query by StoreID numeric again, should result in a Cache Hit (exactly 0 DB calls!)
		resetDBCalls()
		_, err = svc.ListCategories(context.Background(), MenuRequest{CountryCode: "MY", StoreID: 1})
		if err != nil {
			t.Fatal(err)
		}
		requireDBCalls(t, 0, "on store_id cache hit")

		// 7. Seventh Call: Call InvalidateMenuCache by storeCode, should invalidate both storeCode and storeID
		err = svc.InvalidateMenuCache(context.Background(), "MY", "MY-TL-PAV")
		if err != nil {
			t.Fatal(err)
		}

		// 8. Eighth Call: Query by StoreID numeric again, should be a Cache Miss (exactly 5 DB calls!)
		resetDBCalls()
		_, err = svc.ListCategories(context.Background(), MenuRequest{CountryCode: "MY", StoreID: 1})
		if err != nil {
			t.Fatal(err)
		}
		requireDBCalls(t, 5, "on store_id cache miss after invalidation")
	})
}
