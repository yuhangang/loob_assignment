package checkout

import (
	"database/sql"
	"errors"
	"log"
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/loob/backend/internal/contextx"
	"github.com/loob/backend/internal/payments"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func Register(db *sql.DB, g *echo.Group, ps *payments.Service) {
	h := NewHandler(NewService(NewRepository(db), ps))
	orders := g.Group("/orders")
	orders.POST("/checkout", h.checkout)
	orders.GET("/:tracking_id/status", h.status)
}

func (h *Handler) checkout(c echo.Context) error {
	if err := contextx.RequireCountryHeader(c); err != nil {
		return err
	}

	var req CheckoutRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid checkout payload"})
	}

	rc := contextx.FromEcho(c)
	res, err := h.service.Checkout(c.Request().Context(), CheckoutContext{
		TraceID:     rc.TraceID,
		CountryCode: rc.CountryCode,
	}, req)
	if err != nil {
		log.Printf("checkout failed trace_id=%s country=%s error=%v", rc.TraceID, rc.CountryCode, err)
		return checkoutError(err)
	}
	return c.JSON(http.StatusAccepted, res)
}

func (h *Handler) status(c echo.Context) error {
	if err := contextx.RequireCountryHeader(c); err != nil {
		return err
	}
	rc := contextx.FromEcho(c)
	trackingID := c.Param("tracking_id")
	status, err := h.service.GetStatus(c.Request().Context(), rc.CountryCode, trackingID)
	if err != nil {
		if errors.Is(err, ErrOrderNotFound) {
			return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "order not found"})
		}
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to load order status"})
	}
	return c.JSON(http.StatusOK, status)
}

func checkoutError(err error) error {
	switch {
	case errors.Is(err, ErrUserRequired),
		errors.Is(err, ErrIdempotencyRequired),
		errors.Is(err, ErrStoreRequired),
		errors.Is(err, ErrInvalidFulfillment),
		errors.Is(err, ErrCartEmpty),
		errors.Is(err, ErrInvalidCartItem),
		errors.Is(err, ErrInvalidCustomization):
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": err.Error()})
	case errors.Is(err, ErrUnsupportedCountry):
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "unsupported country"})
	case errors.Is(err, ErrStoreNotFound):
		return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "store not found"})
	case errors.Is(err, ErrItemUnavailable):
		return echo.NewHTTPError(http.StatusConflict, map[string]string{"error": "one or more cart items are unavailable"})
	case errors.Is(err, ErrVoucherNotFound), errors.Is(err, ErrVoucherNotEligible):
		return echo.NewHTTPError(http.StatusUnprocessableEntity, map[string]string{"error": err.Error()})
	case errors.Is(err, ErrPaymentMethodUnavailable):
		return echo.NewHTTPError(http.StatusUnprocessableEntity, map[string]string{"error": "payment method unavailable"})
	default:
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "checkout failed"})
	}
}
