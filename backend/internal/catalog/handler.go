package catalog

import (
	"crypto/subtle"
	"errors"
	"net/http"
	"os"
	"strconv"

	"github.com/labstack/echo/v4"
	"github.com/loob/backend/internal/contextx"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) ListCategories(c echo.Context) error {
	rc := contextx.FromEcho(c)
	storeID, err := intQuery(c, "store_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "store_id must be a number"})
	}
	storeCode := c.QueryParam("store_code")
	brandID, err := intQuery(c, "brand_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "brand_id must be a number"})
	}

	categories, err := h.service.ListCategories(c.Request().Context(), MenuRequest{
		CountryCode: rc.CountryCode,
		Language:    rc.Language,
		StoreID:     storeID,
		StoreCode:   storeCode,
		BrandID:     brandID,
	})
	if err != nil {
		return catalogError(err, "failed to list categories")
	}

	return c.JSON(http.StatusOK, categories)
}

func (h *Handler) ListCategoryItems(c echo.Context) error {
	rc := contextx.FromEcho(c)
	categoryID, err := strconv.Atoi(c.Param("category_id"))
	if err != nil || categoryID <= 0 {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "category_id must be a positive number"})
	}
	storeID, err := intQuery(c, "store_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "store_id must be a number"})
	}
	storeCode := c.QueryParam("store_code")
	brandID, err := intQuery(c, "brand_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "brand_id must be a number"})
	}

	items, err := h.service.ListCategoryItems(c.Request().Context(), CategoryItemsRequest{
		CountryCode: rc.CountryCode,
		Language:    rc.Language,
		StoreID:     storeID,
		StoreCode:   storeCode,
		BrandID:     brandID,
		CategoryID:  categoryID,
	})
	if err != nil {
		return catalogError(err, "failed to list category items")
	}

	return c.JSON(http.StatusOK, items)
}

func (h *Handler) GetItem(c echo.Context) error {
	rc := contextx.FromEcho(c)
	itemID, err := strconv.Atoi(c.Param("item_id"))
	if err != nil || itemID <= 0 {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "item_id must be a positive number"})
	}
	storeID, err := intQuery(c, "store_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "store_id must be a number"})
	}
	storeCode := c.QueryParam("store_code")

	item, err := h.service.GetItem(c.Request().Context(), ItemRequest{
		CountryCode: rc.CountryCode,
		Language:    rc.Language,
		StoreID:     storeID,
		StoreCode:   storeCode,
		ItemID:      itemID,
	})
	if err != nil {
		if errors.Is(err, ErrItemNotFound) {
			return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "item not found"})
		}
		return catalogError(err, "failed to get item")
	}
	return c.JSON(http.StatusOK, item)
}

func (h *Handler) GetItemAvailability(c echo.Context) error {
	rc := contextx.FromEcho(c)
	itemID, err := strconv.Atoi(c.Param("item_id"))
	if err != nil || itemID <= 0 {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "item_id must be a positive number"})
	}
	storeID, err := intQuery(c, "store_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "store_id must be a number"})
	}
	storeCode := c.QueryParam("store_code")

	availability, err := h.service.GetItemAvailability(c.Request().Context(), ItemRequest{
		CountryCode: rc.CountryCode,
		Language:    rc.Language,
		StoreID:     storeID,
		StoreCode:   storeCode,
		ItemID:      itemID,
	})
	if err != nil {
		return catalogError(err, "failed to get item availability")
	}
	return c.JSON(http.StatusOK, availability)
}

func (h *Handler) ListBrands(c echo.Context) error {
	brands, err := h.service.ListBrands(c.Request().Context())
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to list brands"})
	}
	return c.JSON(http.StatusOK, brands)
}

func (h *Handler) ListStores(c echo.Context) error {
	rc := contextx.FromEcho(c)
	countryID := c.QueryParam("country_id")
	if countryID == "" {
		countryID = rc.CountryCode
	}
	brandID, err := intQuery(c, "brand_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "brand_id must be a number"})
	}
	activeOnly := c.QueryParam("active_only") != "false"

	stores, err := h.service.ListStores(c.Request().Context(), countryID, rc.Language, brandID, activeOnly, StoreListRequest{
		Page:  parsePositiveInt(c.QueryParam("page")),
		Limit: parsePositiveInt(c.QueryParam("limit")),
	})
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to list stores"})
	}
	return c.JSON(http.StatusOK, stores)
}

func intQuery(c echo.Context, key string) (int, error) {
	raw := c.QueryParam(key)
	if raw == "" {
		return 0, nil
	}
	return strconv.Atoi(raw)
}

func parsePositiveInt(raw string) int {
	if raw == "" {
		return 0
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value < 1 {
		return 0
	}
	return value
}

func catalogError(err error, fallback string) error {
	switch {
	case errors.Is(err, ErrUnsupportedCountry):
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "unsupported country"})
	case errors.Is(err, ErrStoreNotFound):
		return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "store not found"})
	default:
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": fallback})
	}
}

type InvalidateRequest struct {
	CountryCode string `json:"country_code"`
	StoreCode   string `json:"store_code"`
}

func (h *Handler) InvalidateMenuCache(c echo.Context) error {
	// Secure the cache invalidation endpoint (Admin/Internal only)
	secret := c.Request().Header.Get("X-Internal-Secret")
	expectedSecret := os.Getenv("INTERNAL_API_SECRET")
	if expectedSecret == "" {
		// Fail closed for maximum production security: if secret environment variable is not defined, deny all access.
		return echo.NewHTTPError(http.StatusForbidden, map[string]string{"error": "admin invalidation is disabled (security configuration missing)"})
	}
	if len(secret) != len(expectedSecret) || subtle.ConstantTimeCompare([]byte(secret), []byte(expectedSecret)) != 1 {
		return echo.NewHTTPError(http.StatusUnauthorized, map[string]string{"error": "unauthorized admin access required"})
	}

	var req InvalidateRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}
	if req.CountryCode == "" || req.StoreCode == "" {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "country_code and store_code are required"})
	}

	err := h.service.InvalidateMenuCache(c.Request().Context(), req.CountryCode, req.StoreCode)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to invalidate menu cache"})
	}

	return c.JSON(http.StatusOK, map[string]string{"message": "menu cache successfully invalidated"})
}
