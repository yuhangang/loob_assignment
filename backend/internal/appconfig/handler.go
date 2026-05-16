package appconfig

import (
	"net/http"
	"strings"

	"github.com/labstack/echo/v4"
)

type Handler struct {
	publicBaseURL string
}

func NewHandler(publicBaseURL string) *Handler {
	return &Handler{publicBaseURL: strings.TrimRight(publicBaseURL, "/")}
}

func Register(g *echo.Group, publicBaseURL string) {
	h := NewHandler(publicBaseURL)
	app := g.Group("/app")
	app.GET("/config", h.getConfig)
	app.GET("/feed", h.getFeed)
}

func (h *Handler) getConfig(c echo.Context) error {
	config := AppConfig{
		AppName: "Loob",
		AppIcon: h.assetURL("/cdn/app_icon.png"),
		SplashScreen: SplashScreen{
			ImageURL:        h.assetURL("/cdn/splash_screen.png"),
			BackgroundColor: "#ffffff",
			DurationMs:      2000,
		},
		SupportEmail: "support@loob.com",
		Version:      "1.0.0",
	}
	return c.JSON(http.StatusOK, config)
}

func (h *Handler) getFeed(c echo.Context) error {
	resp := FeedResponse{
		Items: []FeedItem{
			{
				ID:          "1",
				Type:        "NEWS",
				Title:       "Welcome to Loob!",
				Description: "Discover the best tea and coffee in town with our unified experience.",
				ImageURL:    h.assetURL("/cdn/welcome.png"),
				Link:        "loob://news/1",
			},
			{
				ID:          "2",
				Type:        "PROMOTION",
				Title:       "Buy 1 Free 1 Tealive",
				Description: "Enjoy our signature Pearl Milk Tea. Buy 1 Free 1 for all sizes today!",
				ImageURL:    h.assetURL("/cdn/promo_tealive.png"),
				Link:        "loob://promo/2",
			},
			{
				ID:          "3",
				Type:        "PROMOTION",
				Title:       "Bask Bear Coffee Break",
				Description: "Get 50% off your second cup of Aren Palm Sugar Latte.",
				ImageURL:    h.assetURL("/cdn/promo_baskbear.png"),
				Link:        "loob://promo/3",
			},
		},
	}
	return c.JSON(http.StatusOK, resp)
}

func (h *Handler) assetURL(path string) string {
	if h.publicBaseURL == "" {
		return path
	}
	return h.publicBaseURL + path
}
