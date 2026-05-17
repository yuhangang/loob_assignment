package users

import (
	"database/sql"
	"errors"
	"net/http"
	"strings"

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
	users := g.Group("/users")
	users.GET("/profile", h.profile)
	users.PATCH("/profile", h.updateProfile)
}

func (h *Handler) profile(c echo.Context) error {
	rc := contextx.FromEcho(c)
	profile, err := h.service.Profile(c.Request().Context(), rc.CountryCode, userID(c))
	if err != nil {
		return profileError(err)
	}
	return c.JSON(http.StatusOK, profile)
}

func (h *Handler) updateProfile(c echo.Context) error {
	rc := contextx.FromEcho(c)
	var req UpdateProfileRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid profile payload"})
	}

	profile, err := h.service.UpdateProfile(c.Request().Context(), rc.CountryCode, userID(c), req)
	if err != nil {
		return profileError(err)
	}
	return c.JSON(http.StatusOK, profile)
}

func userID(c echo.Context) string {
	if userID := strings.TrimSpace(c.QueryParam("user_id")); userID != "" {
		return userID
	}
	return strings.TrimSpace(c.Request().Header.Get("X-User-Id"))
}

func profileError(err error) error {
	switch {
	case errors.Is(err, ErrUserIDRequired):
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "user_id is required"})
	case errors.Is(err, ErrUnsupportedCountry):
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "unsupported country"})
	default:
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to load user profile"})
	}
}
