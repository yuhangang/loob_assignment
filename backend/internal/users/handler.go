package users

import (
	"errors"
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/loob/backend/internal/apierrors"
	"github.com/loob/backend/internal/contextx"
)

const (
	CodeAuthRequired        = "USR_AUTH_REQUIRED"
	CodeUnsupportedCountry  = "USR_UNSUPPORTED_COUNTRY"
	CodeInvalidProfileBody  = "USR_INVALID_PROFILE_PAYLOAD"
	CodeInvalidWalletTopUp  = "USR_INVALID_WALLET_TOPUP_PAYLOAD"
	CodeInvalidTopUpAmount  = "USR_INVALID_TOPUP_AMOUNT"
	CodeProfileLoadFailed   = "USR_PROFILE_LOAD_FAILED"
	CodeWalletLoadFailed    = "USR_WALLET_LOAD_FAILED"
	CodeLoyaltyLoadFailed   = "USR_LOYALTY_LOAD_FAILED"
	CodeProfileUpdateFailed = "USR_PROFILE_UPDATE_FAILED"
	CodeWalletTopUpFailed   = "USR_WALLET_TOPUP_FAILED"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Profile(c echo.Context) error {
	rc := contextx.FromEcho(c)
	profile, err := h.service.Profile(c.Request().Context(), rc.CountryCode, rc.UserID)
	if err != nil {
		return profileError(err, CodeProfileLoadFailed, "failed to load user profile")
	}
	return c.JSON(http.StatusOK, profile)
}

func (h *Handler) UpdateProfile(c echo.Context) error {
	rc := contextx.FromEcho(c)
	var req UpdateProfileRequest
	if err := c.Bind(&req); err != nil {
		return apierrors.New(http.StatusBadRequest, CodeInvalidProfileBody, "invalid profile payload")
	}

	profile, err := h.service.UpdateProfile(c.Request().Context(), rc.CountryCode, rc.UserID, req)
	if err != nil {
		return profileError(err, CodeProfileUpdateFailed, "failed to update user profile")
	}
	return c.JSON(http.StatusOK, profile)
}

func (h *Handler) WalletHistory(c echo.Context) error {
	rc := contextx.FromEcho(c)
	history, err := h.service.WalletHistory(c.Request().Context(), rc.CountryCode, rc.UserID)
	if err != nil {
		return profileError(err, CodeWalletLoadFailed, "failed to load wallet history")
	}
	return c.JSON(http.StatusOK, history)
}

func (h *Handler) TopUpWallet(c echo.Context) error {
	rc := contextx.FromEcho(c)
	var req WalletTopUpRequest
	if err := c.Bind(&req); err != nil {
		return apierrors.New(http.StatusBadRequest, CodeInvalidWalletTopUp, "invalid wallet top-up payload")
	}
	resp, err := h.service.TopUpWallet(c.Request().Context(), rc.CountryCode, rc.UserID, req)
	if err != nil {
		return profileError(err, CodeWalletTopUpFailed, "failed to top up wallet")
	}
	return c.JSON(http.StatusOK, resp)
}

func (h *Handler) LoyaltyHistory(c echo.Context) error {
	rc := contextx.FromEcho(c)
	history, err := h.service.LoyaltyHistory(c.Request().Context(), rc.CountryCode, rc.UserID)
	if err != nil {
		return profileError(err, CodeLoyaltyLoadFailed, "failed to load loyalty history")
	}
	return c.JSON(http.StatusOK, history)
}

func profileError(err error, fallbackCode, fallbackMessage string) error {
	switch {
	case errors.Is(err, ErrUserIDRequired):
		return apierrors.New(http.StatusUnauthorized, CodeAuthRequired, "authentication required")
	case errors.Is(err, ErrUnsupportedCountry):
		return apierrors.New(http.StatusBadRequest, CodeUnsupportedCountry, "unsupported country")
	case errors.Is(err, ErrInvalidTopUpAmount):
		return apierrors.New(http.StatusBadRequest, CodeInvalidTopUpAmount, err.Error())
	default:
		return apierrors.New(http.StatusInternalServerError, fallbackCode, fallbackMessage)
	}
}
