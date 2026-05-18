package apierrors

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v4"
	"github.com/loob/backend/internal/contextx"
)

func TestHandlerPreservesDomainCodeAndAddsTraceID(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/users/profile", nil)
	req.Header.Set("X-Trace-Id", "tr_test")
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	err := contextx.Middleware()(func(c echo.Context) error {
		return New(http.StatusBadRequest, "USR_UNSUPPORTED_COUNTRY", "unsupported country")
	})(c)
	if err == nil {
		t.Fatal("expected middleware handler to return error")
	}

	Handler(err, c)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}

	var body Response
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("unmarshal response: %v", err)
	}
	if body.Error != "unsupported country" {
		t.Fatalf("error = %q", body.Error)
	}
	if body.ErrorCode != "USR_UNSUPPORTED_COUNTRY" {
		t.Fatalf("error_code = %q", body.ErrorCode)
	}
	if body.TraceID != "tr_test" {
		t.Fatalf("trace_id = %q", body.TraceID)
	}
}

func TestHandlerUsesFallbackCodeForLegacyErrors(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/catalog/items/1", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	err := contextx.Middleware()(func(c echo.Context) error {
		return echo.NewHTTPError(http.StatusNotFound, map[string]string{"error": "item not found"})
	})(c)
	if err == nil {
		t.Fatal("expected middleware handler to return error")
	}

	Handler(err, c)

	var body Response
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("unmarshal response: %v", err)
	}
	if body.ErrorCode != CodeNotFound {
		t.Fatalf("error_code = %q, want %q", body.ErrorCode, CodeNotFound)
	}
	if body.TraceID == "" {
		t.Fatal("trace_id should be populated")
	}
}
