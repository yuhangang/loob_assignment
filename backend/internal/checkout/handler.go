package checkout

import (
	"errors"
	"log"
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/loob/backend/internal/contextx"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) List(c echo.Context) error {
	if err := contextx.RequireCountryHeader(c); err != nil {
		return err
	}
	rc := contextx.FromEcho(c)
	orders, err := h.service.ListOrders(c.Request().Context(), rc.CountryCode, rc.UserID)
	if err != nil {
		if errors.Is(err, ErrUserRequired) {
			return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "user_id is required"})
		}
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to load orders"})
	}
	return c.JSON(http.StatusOK, orders)
}

func (h *Handler) Checkout(c echo.Context) error {
	if err := contextx.RequireCountryHeader(c); err != nil {
		return err
	}

	var req CheckoutRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid checkout payload"})
	}

	rc := contextx.FromEcho(c)
	req.UserID = rc.UserID
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

func (h *Handler) Status(c echo.Context) error {
	if err := contextx.RequireCountryHeader(c); err != nil {
		return err
	}
	rc := contextx.FromEcho(c)
	trackingID := c.Param("tracking_id")
	status, err := h.service.GetStatusForUser(c.Request().Context(), rc.CountryCode, rc.UserID, trackingID)
	if err != nil {
		if errors.Is(err, ErrOrderNotFound) {
			return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "order not found"})
		}
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to load order status"})
	}
	return c.JSON(http.StatusOK, status)
}

func (h *Handler) Collect(c echo.Context) error {
	if err := contextx.RequireCountryHeader(c); err != nil {
		return err
	}
	rc := contextx.FromEcho(c)
	trackingID := c.Param("tracking_id")
	status, err := h.service.MarkOrderCollected(c.Request().Context(), rc.CountryCode, rc.UserID, trackingID)
	if err != nil {
		if errors.Is(err, ErrOrderNotFound) {
			return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "order not found"})
		}
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to collect order"})
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
	case errors.Is(err, ErrStoreClosed):
		return echo.NewHTTPError(http.StatusConflict, map[string]string{"error": "selected store is closed"})
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
