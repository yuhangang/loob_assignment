package catalog

import (
	"errors"
	"net/http"
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
	brandID, err := intQuery(c, "brand_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "brand_id must be a number"})
	}

	categories, err := h.service.ListCategories(c.Request().Context(), MenuRequest{
		CountryCode: rc.CountryCode,
		Language:    rc.Language,
		StoreID:     storeID,
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
	brandID, err := intQuery(c, "brand_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "brand_id must be a number"})
	}

	items, err := h.service.ListCategoryItems(c.Request().Context(), CategoryItemsRequest{
		CountryCode: rc.CountryCode,
		Language:    rc.Language,
		StoreID:     storeID,
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

	item, err := h.service.GetItem(c.Request().Context(), ItemRequest{
		CountryCode: rc.CountryCode,
		Language:    rc.Language,
		StoreID:     storeID,
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

	stores, err := h.service.ListStores(c.Request().Context(), countryID, rc.Language, brandID, activeOnly)
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
