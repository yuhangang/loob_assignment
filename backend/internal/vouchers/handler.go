package vouchers

import (
	"database/sql"
	"errors"
	"net/http"
	"strconv"

	"github.com/labstack/echo/v4"
	"github.com/loob/backend/internal/checkout"
	"github.com/loob/backend/internal/contextx"
)

type Handler struct {
	service         *Service
	checkoutService *checkout.Service
}

func NewHandler(service *Service, checkoutService *checkout.Service) *Handler {
	return &Handler{service: service, checkoutService: checkoutService}
}

func Register(db *sql.DB, g *echo.Group) {
	h := NewHandler(NewService(NewRepository(db)), checkout.NewService(checkout.NewRepository(db), nil))
	vouchers := g.Group("/vouchers")
	vouchers.GET("/wallet", h.wallet)
	vouchers.POST("/validate", h.validate)
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

func (h *Handler) validate(c echo.Context) error {
	if err := contextx.RequireCountryHeader(c); err != nil {
		return err
	}
	var req checkout.VoucherValidationRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid voucher validation payload"})
	}
	rc := contextx.FromEcho(c)
	result, err := h.checkoutService.ValidateVoucher(c.Request().Context(), checkout.CheckoutContext{
		TraceID:     rc.TraceID,
		CountryCode: rc.CountryCode,
	}, req)
	if err != nil {
		switch {
		case errors.Is(err, checkout.ErrUserRequired),
			errors.Is(err, checkout.ErrStoreRequired),
			errors.Is(err, checkout.ErrCartEmpty),
			errors.Is(err, checkout.ErrInvalidCartItem),
			errors.Is(err, checkout.ErrInvalidCustomization):
			return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": err.Error()})
		case errors.Is(err, checkout.ErrStoreNotFound):
			return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "store not found"})
		case errors.Is(err, checkout.ErrStoreClosed):
			return echo.NewHTTPError(http.StatusConflict, map[string]string{"error": "selected store is closed"})
		case errors.Is(err, checkout.ErrItemUnavailable):
			return echo.NewHTTPError(http.StatusConflict, map[string]string{"error": "one or more cart items are unavailable"})
		default:
			return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to validate voucher"})
		}
	}
	return c.JSON(http.StatusOK, result)
}

func intQuery(c echo.Context, key string) (int, error) {
	raw := c.QueryParam(key)
	if raw == "" {
		return 0, nil
	}
	return strconv.Atoi(raw)
}
