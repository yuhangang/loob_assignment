package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/loob/backend/internal/apierrors"
	"github.com/loob/backend/internal/appconfig"
	"github.com/loob/backend/internal/auth"
	"github.com/loob/backend/internal/campaigns"
	"github.com/loob/backend/internal/cart"
	"github.com/loob/backend/internal/catalog"
	"github.com/loob/backend/internal/checkout"
	"github.com/loob/backend/internal/contextx"
	"github.com/loob/backend/internal/database"
	"github.com/loob/backend/internal/payments"
	"github.com/loob/backend/internal/platform"
	"github.com/loob/backend/internal/users"
	"github.com/loob/backend/internal/vouchers"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

func main() {
	cfg := platform.Load()

	db, err := database.Open(cfg.DatabaseDSN)
	if err != nil {
		log.Fatalf("open database: %v", err)
	}
	defer db.Close()

	if cfg.AutoMigrate {
		if err := database.RunMigrations(db, cfg.MigrationsDir); err != nil {
			log.Fatalf("run migrations: %v", err)
		}
		log.Printf("database migrations applied from %s", cfg.MigrationsDir)
	}

	database.InitRedis()
	if database.RedisClientInstance != nil {
		defer database.RedisClientInstance.Close()
	}

	e := echo.New()
	e.HideBanner = true
	e.HTTPErrorHandler = apierrors.Handler
	e.Use(middleware.Recover())
	e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: cfg.AllowedOrigins,
		AllowMethods: []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete, http.MethodOptions},
		AllowHeaders: []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAccept, echo.HeaderAuthorization, "X-Country-Code", "X-Trace-Id", "X-Internal-Secret", "X-Mock-Gateway-Secret"},
	}))
	e.Use(newIPRateLimiter(cfg.RateLimitRPS, cfg.RateLimitBurst))
	e.Use(contextx.Middleware())
	e.Use(middleware.RequestLoggerWithConfig(middleware.RequestLoggerConfig{
		LogStatus:  true,
		LogURI:     true,
		LogMethod:  true,
		LogLatency: true,
		LogValuesFunc: func(c echo.Context, values middleware.RequestLoggerValues) error {
			rc := contextx.FromEcho(c)
			log.Printf("trace_id=%s country=%s method=%s uri=%s status=%d latency=%s", rc.TraceID, rc.CountryCode, values.Method, values.URI, values.Status, values.Latency)
			return nil
		},
	}))

	// Initialize repositories, services, and handlers
	authenticator := auth.New(auth.Config{
		FirebaseProjectID: cfg.FirebaseProjectID,
		AuthMode:          cfg.AuthMode,
	})
	if cfg.AuthMode == "mock" {
		log.Printf("auth mode is mock; use AUTH_MODE=firebase and FIREBASE_PROJECT_ID for Firebase token verification")
	}
	requireAuth := authenticator.Required()
	ps := payments.Init(db, cfg.MockGatewaySecret)

	paymentHandler := payments.NewHandler(ps)
	catalogHandler := catalog.NewHandler(catalog.NewService(catalog.NewRepository(db), cfg.PublicBaseURL))

	checkoutService := checkout.NewService(checkout.NewRepository(db), ps)
	checkoutHandler := checkout.NewHandler(checkoutService)

	cartHandler := cart.NewHandler(cart.NewService(cart.NewRepository(db), cfg.PublicBaseURL))
	campaignsHandler := campaigns.NewHandler(campaigns.NewService(campaigns.NewRepository(db), cfg.PublicBaseURL))

	voucherHandler := vouchers.NewHandler(vouchers.NewService(vouchers.NewRepository(db)), checkoutService)
	usersHandler := users.NewHandler(users.NewService(users.NewRepository(db), ps, cfg.PublicBaseURL))
	appconfigHandler := appconfig.NewHandler(cfg.PublicBaseURL)

	// Register routes
	registerRoutes(routesConfig{
		e:                e,
		requireAuth:      requireAuth,
		mockGateway:      cfg.MockGatewayEnabled,
		paymentHandler:   paymentHandler,
		catalogHandler:   catalogHandler,
		checkoutHandler:  checkoutHandler,
		cartHandler:      cartHandler,
		campaignsHandler: campaignsHandler,
		voucherHandler:   voucherHandler,
		usersHandler:     usersHandler,
		appconfigHandler: appconfigHandler,
	})

	log.Printf("starting Loob API on %s", cfg.HTTPAddr)
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	errCh := make(chan error, 1)
	go func() {
		errCh <- e.Start(cfg.HTTPAddr)
	}()

	select {
	case err := <-errCh:
		if err != nil && err != http.ErrServerClosed {
			log.Fatalf("server failed: %v", err)
		}
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := e.Shutdown(shutdownCtx); err != nil {
			log.Printf("server shutdown failed: %v", err)
		}
	}
}
