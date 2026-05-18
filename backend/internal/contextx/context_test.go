package contextx

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v4"
)

func TestNormalizeLanguage(t *testing.T) {
	tests := []struct {
		header string
		want   string
	}{
		{"en-US,en;q=0.9", "en-US"},
		{"ms,en-US;q=0.9,en;q=0.8", "ms"},
		{"zh-CN,zh;q=0.9,en;q=0.8", "zh-CN"},
		{"*", "en-US"},
		{"", "en-US"},
		{"  ", "en-US"},
		{"en-US;q=1.0", "en-US"},
	}

	for _, tt := range tests {
		t.Run(tt.header, func(t *testing.T) {
			got := normalizeLanguage(tt.header)
			if got != tt.want {
				t.Errorf("normalizeLanguage(%q) = %q, want %q", tt.header, got, tt.want)
			}
		})
	}
}

func TestFromEcho(t *testing.T) {
	e := echo.New()

	t.Run("existing context", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/", nil)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)

		expected := RequestContext{
			TraceID:     "test-trace",
			CountryCode: "TH",
			Language:    "th",
		}
		c.Set(requestContextKey, expected)

		got := FromEcho(c)
		if got != expected {
			t.Errorf("FromEcho() = %+v, want %+v", got, expected)
		}
	})

	t.Run("missing context returns default", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/", nil)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)

		got := FromEcho(c)
		if got.TraceID == "" {
			t.Error("FromEcho() TraceID is empty")
		}
		if got.CountryCode != "MY" {
			t.Errorf("FromEcho() CountryCode = %q, want %q", got.CountryCode, "MY")
		}
		if got.Language != "en-US" {
			t.Errorf("FromEcho() Language = %q, want %q", got.Language, "en-US")
		}
	})
}

func TestRequireCountryHeader(t *testing.T) {
	e := echo.New()

	t.Run("missing header", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/", nil)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)

		err := RequireCountryHeader(c)
		if err == nil {
			t.Fatal("expected error, got nil")
		}
		he, ok := err.(*echo.HTTPError)
		if !ok {
			t.Fatalf("expected echo.HTTPError, got %T", err)
		}
		if he.Code != http.StatusBadRequest {
			t.Errorf("expected status 400, got %d", he.Code)
		}
	})

	t.Run("present header", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/", nil)
		req.Header.Set("X-Country-Code", "MY")
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)

		err := RequireCountryHeader(c)
		if err != nil {
			t.Errorf("expected no error, got %v", err)
		}
	})
}

func TestMiddleware(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("X-Country-Code", "TH")
	req.Header.Set("Accept-Language", "th,en-US;q=0.9")
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	mw := Middleware()
	h := mw(func(c echo.Context) error {
		rc := FromEcho(c)
		if rc.CountryCode != "TH" {
			t.Errorf("expected country TH, got %s", rc.CountryCode)
		}
		if rc.Language != "th" {
			t.Errorf("expected language th, got %s", rc.Language)
		}
		if rc.TraceID == "" {
			t.Error("trace ID is empty")
		}
		return c.String(http.StatusOK, "ok")
	})

	err := h(c)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}
	if rec.Header().Get("X-Trace-Id") == "" {
		t.Error("X-Trace-Id header is missing")
	}
}
