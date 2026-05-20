package main

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v4"
)

func TestMainCompiles(t *testing.T) {
	// This test simply ensures the package can be compiled and the test suite can run.
	// Since the actual main() function initiates server startup and blocking calls,
	// we don't invoke it here.
}

func TestPaymentTransactionRouteRequiresAuth(t *testing.T) {
	e := echo.New()
	requireAuth := func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			return echo.NewHTTPError(http.StatusUnauthorized, "authentication required")
		}
	}
	registerRoutes(routesConfig{
		e:           e,
		requireAuth: requireAuth,
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/payments/PAY-MY-1", nil)
	rec := httptest.NewRecorder()
	e.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}
