package campaigns

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

func Register(db *sql.DB, g *echo.Group, publicBaseURL string) {
	h := NewHandler(NewService(NewRepository(db), publicBaseURL))
	campaigns := g.Group("/campaigns")
	campaigns.GET("/home", h.home)
}

func (h *Handler) home(c echo.Context) error {
	rc := contextx.FromEcho(c)
	brandID, err := intQuery(c, "brand_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "brand_id must be a number"})
	}

	feed, err := h.service.Home(c.Request().Context(), rc.CountryCode, rc.Language, brandID)
	if err != nil {
		if errors.Is(err, ErrUnsupportedCountry) {
			return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "unsupported country"})
		}
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to load campaigns"})
	}
	return c.JSON(http.StatusOK, feed)
}

func intQuery(c echo.Context, key string) (int, error) {
	raw := c.QueryParam(key)
	if raw == "" {
		return 0, nil
	}
	return strconv.Atoi(raw)
}
