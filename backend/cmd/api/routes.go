package main

import (
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/loob/backend/internal/appconfig"
	"github.com/loob/backend/internal/campaigns"
	"github.com/loob/backend/internal/cart"
	"github.com/loob/backend/internal/catalog"
	"github.com/loob/backend/internal/checkout"
	"github.com/loob/backend/internal/payments"
	"github.com/loob/backend/internal/users"
	"github.com/loob/backend/internal/vouchers"
)

// routesConfig holds all route handlers and dependencies needed to register API routes.
type routesConfig struct {
	e                *echo.Echo
	requireAuth      echo.MiddlewareFunc
	paymentHandler   *payments.Handler
	catalogHandler   *catalog.Handler
	checkoutHandler  *checkout.Handler
	cartHandler      *cart.Handler
	campaignsHandler *campaigns.Handler
	voucherHandler   *vouchers.Handler
	usersHandler     *users.Handler
	appconfigHandler *appconfig.Handler
}

// registerRoutes registers all the HTTP routes for the web service.
func registerRoutes(cfg routesConfig) {
	// Health check route
	cfg.e.GET("/health", func(c echo.Context) error {
		return c.JSON(http.StatusOK, map[string]string{
			"status":  "healthy",
			"service": "loob-api",
		})
	})

	// Static assets route
	cfg.e.Static("/cdn", "cdn")

	// API Version 1 Group
	v1 := cfg.e.Group("/api/v1")

	// Payments routes
	paymentsGroup := v1.Group("/payments")
	paymentsGroup.GET("/providers", cfg.paymentHandler.ListProviders)
	paymentsGroup.GET("/methods", cfg.paymentHandler.ListMethods)
	paymentsGroup.GET("/:transaction_id", cfg.paymentHandler.Get)
	paymentsGroup.POST("/mock-gateway/callback", cfg.paymentHandler.MockGatewayCallback)

	// Catalog routes
	catalogGroup := v1.Group("/catalog")
	catalogGroup.GET("/categories", cfg.catalogHandler.ListCategories)
	catalogGroup.GET("/categories/:category_id/items", cfg.catalogHandler.ListCategoryItems)
	catalogGroup.GET("/items/:item_id", cfg.catalogHandler.GetItem)
	catalogGroup.GET("/brands", cfg.catalogHandler.ListBrands)
	catalogGroup.GET("/stores", cfg.catalogHandler.ListStores)

	// Checkout / Orders routes (Requires Authentication)
	ordersGroup := v1.Group("/orders", cfg.requireAuth)
	ordersGroup.GET("", cfg.checkoutHandler.List)
	ordersGroup.POST("/checkout", cfg.checkoutHandler.Checkout)
	ordersGroup.GET("/:tracking_id/status", cfg.checkoutHandler.Status)

	// Cart routes (Requires Authentication)
	cartGroup := v1.Group("/cart", cfg.requireAuth)
	cartGroup.GET("", cfg.cartHandler.GetCart)
	cartGroup.POST("/update", cfg.cartHandler.UpdateCart)
	cartGroup.PUT("/items", cfg.cartHandler.UpsertItem)
	cartGroup.PATCH("/items/:item_id", cfg.cartHandler.UpdateItem)
	cartGroup.DELETE("/items/:item_id", cfg.cartHandler.RemoveItem)
	cartGroup.DELETE("", cfg.cartHandler.ClearCart)

	// Campaigns routes
	campaignsGroup := v1.Group("/campaigns")
	campaignsGroup.GET("/home", cfg.campaignsHandler.Home)

	// Vouchers routes (Requires Authentication)
	vouchersGroup := v1.Group("/vouchers", cfg.requireAuth)
	vouchersGroup.GET("/wallet", cfg.voucherHandler.Wallet)
	vouchersGroup.POST("/validate", cfg.voucherHandler.Validate)

	// Users routes (Requires Authentication)
	usersGroup := v1.Group("/users", cfg.requireAuth)
	usersGroup.GET("/profile", cfg.usersHandler.Profile)
	usersGroup.PATCH("/profile", cfg.usersHandler.UpdateProfile)
	usersGroup.GET("/wallet/history", cfg.usersHandler.WalletHistory)
	usersGroup.POST("/wallet/topups", cfg.usersHandler.TopUpWallet)
	usersGroup.GET("/loyalty/history", cfg.usersHandler.LoyaltyHistory)

	// App config / App routes
	appGroup := v1.Group("/app")
	appGroup.GET("/config", cfg.appconfigHandler.GetConfig)
	appGroup.GET("/feed", cfg.appconfigHandler.GetFeed)
}
