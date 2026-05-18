package cart

import (
	"errors"
	"log"
	"net/http"
	"strconv"

	"github.com/labstack/echo/v4"
	"github.com/loob/backend/internal/contextx"
)

// Handler exposes the cart CRUD endpoints.
type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) GetCart(c echo.Context) error {
	rc := contextx.FromEcho(c)
	userID := rc.UserID

	// Optional: override the store used for availability checks.
	var overrideStoreID int
	if raw := c.QueryParam("store_id"); raw != "" {
		if id, err := strconv.Atoi(raw); err == nil && id > 0 {
			overrideStoreID = id
		}
	}

	resp, err := h.service.GetCart(c.Request().Context(), rc.CountryCode, userID, overrideStoreID)
	if err != nil {
		log.Printf("trace_id=%s country=%s get_cart user=%s error=%v", rc.TraceID, rc.CountryCode, userID, err)
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to load cart"})
	}
	return c.JSON(http.StatusOK, resp)
}

// UpsertItem handles PUT /api/v1/cart/items
func (h *Handler) UpsertItem(c echo.Context) error {
	rc := contextx.FromEcho(c)

	var req CartItemRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}
	req.UserID = rc.UserID

	resp, err := h.service.UpsertItem(c.Request().Context(), rc.CountryCode, req)
	if err != nil {
		return cartError(err)
	}
	return c.JSON(http.StatusOK, resp)
}

// UpdateItem handles PATCH /api/v1/cart/items/:item_id
func (h *Handler) UpdateItem(c echo.Context) error {
	rc := contextx.FromEcho(c)

	itemID, err := strconv.ParseInt(c.Param("item_id"), 10, 64)
	if err != nil || itemID <= 0 {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid item_id"})
	}

	var req CartItemUpdateRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}
	req.UserID = rc.UserID

	resp, err := h.service.UpdateItem(c.Request().Context(), rc.CountryCode, itemID, req)
	if err != nil {
		return cartError(err)
	}
	return c.JSON(http.StatusOK, resp)
}

// RemoveItem handles DELETE /api/v1/cart/items/:item_id?user_id=<id>
func (h *Handler) RemoveItem(c echo.Context) error {
	rc := contextx.FromEcho(c)
	userID := rc.UserID

	itemID, err := strconv.ParseInt(c.Param("item_id"), 10, 64)
	if err != nil || itemID <= 0 {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid item_id"})
	}

	resp, err := h.service.RemoveItem(c.Request().Context(), rc.CountryCode, userID, itemID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "cart item not found"})
		}
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to remove cart item"})
	}
	return c.JSON(http.StatusOK, resp)
}

// ClearCart handles DELETE /api/v1/cart?user_id=<id>
func (h *Handler) ClearCart(c echo.Context) error {
	rc := contextx.FromEcho(c)
	userID := rc.UserID

	if err := h.service.ClearCart(c.Request().Context(), rc.CountryCode, userID); err != nil {
		if errors.Is(err, ErrUserRequired) {
			return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": err.Error()})
		}
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to clear cart"})
	}
	return c.JSON(http.StatusOK, map[string]string{"status": "cleared"})
}

func cartError(err error) error {
	switch {
	case errors.Is(err, ErrUserRequired),
		errors.Is(err, ErrStoreRequired),
		errors.Is(err, ErrInvalidItem),
		errors.Is(err, ErrInvalidItemID),
		errors.Is(err, ErrInvalidMethod):
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": err.Error()})
	case errors.Is(err, ErrNotFound):
		return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "cart item not found"})
	default:
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "cart operation failed"})
	}
}

// ── Consolidated mutation endpoint ──────────────────────────────────────────

// UpdateCart handles POST /api/v1/cart/update
//
// Accepts a single JSON body with a "method" discriminator:
//   - "upsert"  – add or merge an item
//   - "update"  – replace an existing line-item by item_id
//   - "remove"  – delete a line-item by item_id
//   - "clear"   – wipe the entire cart
//
// Always returns the full refreshed CartResponse.
func (h *Handler) UpdateCart(c echo.Context) error {
	rc := contextx.FromEcho(c)

	var req CartUpdateRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}
	req.UserID = rc.UserID

	resp, err := h.service.UpdateCart(c.Request().Context(), rc.CountryCode, req)
	if err != nil {
		return cartError(err)
	}
	return c.JSON(http.StatusOK, resp)
}
