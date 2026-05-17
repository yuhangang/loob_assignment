package cart

import (
	"database/sql"
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

// Register mounts the cart routes on the given Echo group.
func Register(db *sql.DB, g *echo.Group) {
	h := NewHandler(NewService(NewRepository(db)))
	cart := g.Group("/cart")
	cart.GET("", h.getCart)
	cart.PUT("/items", h.upsertItem)
	cart.PATCH("/items/:item_id", h.updateItem)
	cart.DELETE("/items/:item_id", h.removeItem)
	cart.DELETE("", h.clearCart)
}

// getCart handles GET /api/v1/cart?user_id=<id>
func (h *Handler) getCart(c echo.Context) error {
	rc := contextx.FromEcho(c)
	userID := c.QueryParam("user_id")
	if userID == "" {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "user_id is required"})
	}

	resp, err := h.service.GetCart(c.Request().Context(), rc.CountryCode, userID)
	if err != nil {
		log.Printf("trace_id=%s country=%s get_cart user=%s error=%v", rc.TraceID, rc.CountryCode, userID, err)
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "failed to load cart"})
	}
	return c.JSON(http.StatusOK, resp)
}

// upsertItem handles PUT /api/v1/cart/items
func (h *Handler) upsertItem(c echo.Context) error {
	rc := contextx.FromEcho(c)

	var req CartItemRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	resp, err := h.service.UpsertItem(c.Request().Context(), rc.CountryCode, req)
	if err != nil {
		return cartError(err)
	}
	return c.JSON(http.StatusOK, resp)
}

// updateItem handles PATCH /api/v1/cart/items/:item_id
func (h *Handler) updateItem(c echo.Context) error {
	rc := contextx.FromEcho(c)

	itemID, err := strconv.ParseInt(c.Param("item_id"), 10, 64)
	if err != nil || itemID <= 0 {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid item_id"})
	}

	var req CartItemUpdateRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	resp, err := h.service.UpdateItem(c.Request().Context(), rc.CountryCode, itemID, req)
	if err != nil {
		return cartError(err)
	}
	return c.JSON(http.StatusOK, resp)
}

// removeItem handles DELETE /api/v1/cart/items/:item_id?user_id=<id>
func (h *Handler) removeItem(c echo.Context) error {
	rc := contextx.FromEcho(c)
	userID := c.QueryParam("user_id")
	if userID == "" {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "user_id is required"})
	}

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

// clearCart handles DELETE /api/v1/cart?user_id=<id>
func (h *Handler) clearCart(c echo.Context) error {
	rc := contextx.FromEcho(c)
	userID := c.QueryParam("user_id")
	if userID == "" {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": "user_id is required"})
	}

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
		errors.Is(err, ErrInvalidItemID):
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{"error": err.Error()})
	case errors.Is(err, ErrNotFound):
		return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "cart item not found"})
	default:
		return echo.NewHTTPError(http.StatusInternalServerError, map[string]string{"error": "cart operation failed"})
	}
}
