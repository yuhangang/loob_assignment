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

func Register(db *sql.DB, g *echo.Group, publicBaseURL string) {
	h := NewHandler(NewService(NewRepository(db), publicBaseURL))
	users := g.Group("/users")
	users.GET("/profile", h.profile)
	users.PATCH("/profile", h.updateProfile)
	users.GET("/wallet/history", h.walletHistory)
	users.POST("/wallet/topups", h.topUpWallet)
	users.GET("/loyalty/history", h.loyaltyHistory)
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

func (h *Handler) walletHistory(c echo.Context) error {
	rc := contextx.FromEcho(c)
	history, err := h.service.WalletHistory(c.Request().Context(), rc.CountryCode, userID(c))
	if err != nil {
		return profileError(err)
	}
	return c.JSON(http.StatusOK, history)
}

func (h *Handler) topUpWallet(c echo.Context) error {
	rc := contextx.FromEcho(c)
	var req WalletTopUpRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid wallet top-up payload"})
	}
	history, err := h.service.TopUpWallet(c.Request().Context(), rc.CountryCode, userID(c), req)
	if err != nil {
		return profileError(err)
	}
	return c.JSON(http.StatusOK, history)
}

func (h *Handler) loyaltyHistory(c echo.Context) error {
	rc := contextx.FromEcho(c)
	history, err := h.service.LoyaltyHistory(c.Request().Context(), rc.CountryCode, userID(c))
	if err != nil {
		return profileError(err)
	}
	return c.JSON(http.StatusOK, history)
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
	case errors.Is(err, ErrInvalidTopUpAmount):
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": err.Error()})
	default:
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to load user profile"})
	}
}
