package catalog

import (
	"database/sql"
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

func Register(db *sql.DB, g *echo.Group) {
	h := NewHandler(NewService(NewRepository(db)))
	catalog := g.Group("/catalog")
	catalog.GET("/menu", h.getMenu)
	catalog.GET("/brands", h.listBrands)
	catalog.GET("/stores", h.listStores)
}

func (h *Handler) getMenu(c echo.Context) error {
	rc := contextx.FromEcho(c)
	storeID, err := intQuery(c, "store_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "store_id must be a number"})
	}
	brandID, err := intQuery(c, "brand_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "brand_id must be a number"})
	}

	menu, err := h.service.GetMenu(c.Request().Context(), MenuRequest{
		CountryCode: rc.CountryCode,
		Language:    rc.Language,
		StoreID:     storeID,
		BrandID:     brandID,
	})
	if err != nil {
		switch {
		case errors.Is(err, ErrUnsupportedCountry):
			return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "unsupported country"})
		case errors.Is(err, ErrStoreNotFound):
			return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "store not found"})
		default:
			return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to load menu"})
		}
	}

	return c.JSON(http.StatusOK, menu)
}

func (h *Handler) listBrands(c echo.Context) error {
	brands, err := h.service.ListBrands(c.Request().Context())
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to list brands"})
	}
	return c.JSON(http.StatusOK, brands)
}

func (h *Handler) listStores(c echo.Context) error {
	rc := contextx.FromEcho(c)
	countryID := c.QueryParam("country_id")
	if countryID == "" {
		countryID = rc.CountryCode
	}

	stores, err := h.service.ListStores(c.Request().Context(), countryID, rc.Language)
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
