package appconfig

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v4"
	"github.com/loob/backend/internal/contextx"
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
	if err := h.GetConfig(c); err != nil {
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
	resp := requestFeed(t, "", "", "")

	if len(resp.Items) == 0 {
		t.Error("expected non-empty feed items")
	}
}

func TestGetFeedUsesCountrySpecificContent(t *testing.T) {
	my := requestFeed(t, "MY", "en-US", "https://cdn.example.com")
	th := requestFeed(t, "TH", "en-US", "https://cdn.example.com")

	if len(my.Items) == 0 || len(th.Items) == 0 {
		t.Fatal("expected non-empty feed items")
	}
	if my.Items[0].ID == th.Items[0].ID {
		t.Fatalf("expected different first feed item per country, both got %q", my.Items[0].ID)
	}
	if my.Items[0].ID != "my-news-welcome" {
		t.Fatalf("expected Malaysia feed item, got %q", my.Items[0].ID)
	}
	if th.Items[0].ID != "th-news-welcome" {
		t.Fatalf("expected Thailand feed item, got %q", th.Items[0].ID)
	}
	if th.Items[0].ImageURL != "https://cdn.example.com/cdn/th/welcome.png" {
		t.Fatalf("expected Thailand CDN asset URL, got %q", th.Items[0].ImageURL)
	}
}

func TestGetFeedLocalizesMalaysiaMalayContent(t *testing.T) {
	resp := requestFeed(t, "MY", "ms-MY", "")

	if got := resp.Items[0].Title; got != "Selamat Datang ke Loob Malaysia!" {
		t.Fatalf("expected Malay title, got %q", got)
	}
}

func TestGetFeedDefaultsUnknownCountryToMalaysiaContent(t *testing.T) {
	resp := requestFeed(t, "SG", "en-US", "")

	if len(resp.Items) == 0 {
		t.Fatal("expected non-empty feed items")
	}
	if got := resp.Items[0].ID; got != "my-news-welcome" {
		t.Fatalf("expected fallback Malaysia feed item, got %q", got)
	}
}

func requestFeed(t *testing.T, countryCode, language, publicBaseURL string) FeedResponse {
	t.Helper()

	e := echo.New()
	h := NewHandler(publicBaseURL)
	e.Use(contextx.Middleware())
	e.GET("/app/feed", h.GetFeed)

	req := httptest.NewRequest(http.MethodGet, "/app/feed", nil)
	if countryCode != "" {
		req.Header.Set("X-Country-Code", countryCode)
	}
	if language != "" {
		req.Header.Set("Accept-Language", language)
	}
	rec := httptest.NewRecorder()
	e.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d body=%s", rec.Code, rec.Body.String())
	}

	var resp FeedResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	return resp
}
