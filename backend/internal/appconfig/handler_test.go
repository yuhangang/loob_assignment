package appconfig

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v4"
)

func TestAssetURLUsesConfiguredPublicBaseURL(t *testing.T) {
	h := NewHandler("https://api.example.com/")
	if got := h.assetURL("/cdn/app_icon.png"); got != "https://api.example.com/cdn/app_icon.png" {
		t.Fatalf("assetURL() = %q", got)
	}
}

func TestAssetURLFallsBackToRelativePath(t *testing.T) {
	h := NewHandler("")
	if got := h.assetURL("/cdn/app_icon.png"); got != "/cdn/app_icon.png" {
		t.Fatalf("assetURL() = %q", got)
	}
}

func TestGetConfig(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/app/config", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	h := NewHandler("https://cdn.example.com")
	if err := h.getConfig(c); err != nil {
		t.Fatal(err)
	}

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var resp AppConfig
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}

	if resp.AppName != "Loob" {
		t.Errorf("expected AppName Loob, got %s", resp.AppName)
	}
	if resp.AppIcon != "https://cdn.example.com/cdn/app_icon.png" {
		t.Errorf("expected full URL for AppIcon, got %s", resp.AppIcon)
	}
}

func TestGetFeed(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/app/feed", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	h := NewHandler("")
	if err := h.getFeed(c); err != nil {
		t.Fatal(err)
	}

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var resp FeedResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}

	if len(resp.Items) == 0 {
		t.Error("expected non-empty feed items")
	}
}

