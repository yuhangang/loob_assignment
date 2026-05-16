package vouchers

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
	vouchers := g.Group("/vouchers")
	vouchers.GET("/wallet", h.wallet)
}

func (h *Handler) wallet(c echo.Context) error {
	rc := contextx.FromEcho(c)
	brandID, err := intQuery(c, "brand_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "brand_id must be a number"})
	}

	userID := c.QueryParam("user_id")
	wallet, err := h.service.Wallet(c.Request().Context(), rc.CountryCode, rc.Language, userID, brandID)
	if err != nil {
		if errors.Is(err, ErrUnsupportedCountry) {
			return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "unsupported country"})
		}
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to load voucher wallet"})
	}
	return c.JSON(http.StatusOK, wallet)
}

func intQuery(c echo.Context, key string) (int, error) {
	raw := c.QueryParam(key)
	if raw == "" {
		return 0, nil
	}
	return strconv.Atoi(raw)
}
