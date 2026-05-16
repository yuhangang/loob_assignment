package main

import (
	"log"
	"net/http"

	"github.com/loob/backend/internal/appconfig"
	"github.com/loob/backend/internal/campaigns"
	"github.com/loob/backend/internal/catalog"
	"github.com/loob/backend/internal/checkout"
	"github.com/loob/backend/internal/contextx"
	"github.com/loob/backend/internal/database"
	"github.com/loob/backend/internal/payments"
	"github.com/loob/backend/internal/platform"
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

	e := echo.New()
	e.HideBanner = true
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())
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

	e.GET("/health", func(c echo.Context) error {
		return c.JSON(http.StatusOK, map[string]string{
			"status":  "healthy",
			"service": "loob-api",
		})
	})

	e.Static("/cdn", "cdn")

	v1 := e.Group("/api/v1")

	// Initialize and register modules
	ps := payments.Init(db, cfg.MockGatewaySecret)

	payments.Register(v1, ps)
	catalog.Register(db, v1)
	checkout.Register(db, v1, ps)
	campaigns.Register(db, v1)
	vouchers.Register(db, v1)
	appconfig.Register(v1, cfg.PublicBaseURL)

	log.Printf("starting Loob API on %s", cfg.HTTPAddr)
	if err := e.Start(cfg.HTTPAddr); err != nil && err != http.ErrServerClosed {
		log.Fatalf("server failed: %v", err)
	}
}
