package payments

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

func Init(db *sql.DB, mockGatewaySecret string) *Service {
	return NewService(NewRepository(db), mockGatewaySecret)
}

func (h *Handler) ListProviders(c echo.Context) error {
	includeInactive := c.QueryParam("include_inactive") == "true"
	providers, err := h.service.ListProviders(c.Request().Context(), includeInactive)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to list payment providers"})
	}
	return c.JSON(http.StatusOK, providers)
}

func (h *Handler) ListMethods(c echo.Context) error {
	rc := contextx.FromEcho(c)
	brandID, err := intQuery(c, "brand_id")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "brand_id must be a number"})
	}
	includeInactive := c.QueryParam("include_inactive") == "true"
	methods, err := h.service.ListMethods(c.Request().Context(), rc.CountryCode, brandID, includeInactive)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to list payment methods"})
	}
	return c.JSON(http.StatusOK, methods)
}

func (h *Handler) Get(c echo.Context) error {
	if err := contextx.RequireCountryHeader(c); err != nil {
		return err
	}
	rc := contextx.FromEcho(c)
	transaction, err := h.service.GetForUser(c.Request().Context(), rc.CountryCode, rc.UserID, c.Param("transaction_id"))
	if err != nil {
		if errors.Is(err, ErrTransactionNotFound) {
			return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "payment transaction not found"})
		}
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to load payment transaction"})
	}
	return c.JSON(http.StatusOK, transaction)
}

func (h *Handler) MockGatewayCallback(c echo.Context) error {
	if !h.service.AuthorizeMockGateway(c.Request().Header.Get("X-Mock-Gateway-Secret")) {
		return echo.NewHTTPError(http.StatusUnauthorized, map[string]string{"error": "unauthorized payment callback"})
	}

	var req MockGatewayCallbackRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid payment callback payload"})
	}

	transaction, err := h.service.ApplyMockGatewayCallback(c.Request().Context(), req)
	if err != nil {
		switch {
		case errors.Is(err, ErrTransactionRequired), errors.Is(err, ErrUnsupportedStatus):
			return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": err.Error()})
		case errors.Is(err, ErrInsufficientWalletBalance):
			return echo.NewHTTPError(http.StatusConflict, map[string]string{"error": "insufficient wallet balance"})
		case errors.Is(err, ErrVoucherRedemptionLimitExceeded):
			return echo.NewHTTPError(http.StatusConflict, map[string]string{"error": "voucher redemption limit exceeded"})
		case errors.Is(err, ErrTransactionNotFound):
			return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "payment transaction not found"})
		default:
			return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to apply payment callback"})
		}
	}
	return c.JSON(http.StatusOK, transaction)
}

func intQuery(c echo.Context, key string) (int, error) {
	raw := c.QueryParam(key)
	if raw == "" {
		return 0, nil
	}
	return strconv.Atoi(raw)
}
