package appconfig

import (
	"net/http"
	"strings"

	"github.com/labstack/echo/v4"
	"github.com/loob/backend/internal/contextx"
)

type Handler struct {
	publicBaseURL string
}

func NewHandler(publicBaseURL string) *Handler {
	return &Handler{publicBaseURL: strings.TrimRight(publicBaseURL, "/")}
}

func (h *Handler) GetConfig(c echo.Context) error {
	rc := contextx.FromEcho(c)
	isMalay := strings.HasPrefix(rc.Language, "ms")

	title := "Mega Boba Fiesta!"
	desc := "Join us this weekend for 2x points on all Tealive orders!"
	btnText := "Claim Now"

	if isMalay {
		title = "Mega Boba Fiesta!"
		desc = "Sertai kami hujung minggu ini untuk 2x mata ganjaran bagi semua pesanan Tealive!"
		btnText = "Tuntut Sekarang"
	}

	config := AppConfig{
		AppName: "Loob",
		AppIcon: h.assetURL("/cdn/app_icon.png"),
		SplashScreen: SplashScreen{
			ImageURL:        h.assetURL("/cdn/splash_screen.png"),
			BackgroundColor: "#F5ECF7",
			DurationMs:      2000,
		},
		SupportEmail: "support@loob.com",
		Version:      "1.0.0",
		FeatureToggles: FeatureToggles{
			DeliveryEnabled: true,
			PickupEnabled:   true,
			RewardsEnabled:  true,
		},
		MarketingPopup: MarketingPopup{
			Active:      true,
			Title:       title,
			Description: desc,
			ImageURL:    h.assetURL("/cdn/fiesta.png"),
			ButtonText:  btnText,
			Link:        "loob://promo/fiesta",
		},
		ThemeConfig: ThemeConfig{
			PrimaryColor:   "#4C1D40",
			AccentColor:    "#FFFFC107",
			SecondaryColor: "#7A3369",
		},
	}
	return c.JSON(http.StatusOK, config)
}

func (h *Handler) GetFeed(c echo.Context) error {
	rc := contextx.FromEcho(c)
	items := h.feedItems(rc.CountryCode, rc.Language)

	resp := FeedResponse{
		Items: items,
	}
	return c.JSON(http.StatusOK, resp)
}

func (h *Handler) feedItems(countryCode, language string) []FeedItem {
	switch strings.ToUpper(strings.TrimSpace(countryCode)) {
	case "TH":
		return h.thailandFeedItems(language)
	default:
		return h.malaysiaFeedItems(language)
	}
}

func (h *Handler) malaysiaFeedItems(language string) []FeedItem {
	items := []FeedItem{
		{
			ID:          "my-news-welcome",
			Type:        "NEWS",
			Title:       "Welcome to Loob Malaysia!",
			Description: "Discover Tealive and Baskbear favourites across Malaysia.",
			ImageURL:    h.assetURL("/cdn/my/welcome.png"),
			Link:        "loob://news/my-welcome",
		},
		{
			ID:          "my-promo-tealive-bogo",
			Type:        "PROMOTION",
			Title:       "Buy 1 Free 1 Tealive",
			Description: "Enjoy our signature Pearl Milk Tea. Buy 1 Free 1 for all sizes today!",
			ImageURL:    h.assetURL("/cdn/my/promo_tealive.png"),
			Link:        "loob://promo/my-tealive-bogo",
		},
		{
			ID:          "my-promo-baskbear-coffee",
			Type:        "PROMOTION",
			Title:       "Baskbear Coffee Break",
			Description: "Get 50% off your second cup of Aren Palm Sugar Latte.",
			ImageURL:    h.assetURL("/cdn/my/promo_baskbear.png"),
			Link:        "loob://promo/my-baskbear-coffee",
		},
	}

	if strings.HasPrefix(language, "ms") {
		items[0].Title = "Selamat Datang ke Loob Malaysia!"
		items[0].Description = "Temui pilihan Tealive dan Baskbear di seluruh Malaysia."
		items[1].Title = "Beli 1 Percuma 1 Tealive"
		items[1].Description = "Nikmati Pearl Milk Tea istimewa kami. Beli 1 Percuma 1 untuk semua saiz hari ini!"
		items[2].Title = "Rehat Kopi Baskbear"
		items[2].Description = "Dapatkan diskaun 50% untuk cawan kedua Aren Palm Sugar Latte anda."
	}

	return items
}

func (h *Handler) thailandFeedItems(language string) []FeedItem {
	items := []FeedItem{
		{
			ID:          "th-news-welcome",
			Type:        "NEWS",
			Title:       "Welcome to Loob Thailand!",
			Description: "Explore Tealive and Baskbear picks curated for Thailand.",
			ImageURL:    h.assetURL("/cdn/th/welcome.png"),
			Link:        "loob://news/th-welcome",
		},
		{
			ID:          "th-promo-tealive-thai-tea",
			Type:        "PROMOTION",
			Title:       "Tealive Thai Tea Picks",
			Description: "Try the Thai Tea Series and local boba favourites near you.",
			ImageURL:    h.assetURL("/cdn/th/promo_tealive.png"),
			Link:        "loob://promo/th-tealive-thai-tea",
		},
		{
			ID:          "th-promo-baskbear-toast",
			Type:        "PROMOTION",
			Title:       "Baskbear Bangkok Coffee Set",
			Description: "Pair your premium coffee with golden toast for a better morning.",
			ImageURL:    h.assetURL("/cdn/th/promo_baskbear.png"),
			Link:        "loob://promo/th-baskbear-coffee-set",
		},
	}

	if strings.HasPrefix(language, "th") {
		items[0].Title = "Loob Thailand welcomes you"
		items[0].Description = "Local Tealive and Baskbear picks are ready in Thailand."
		items[1].Title = "Tealive Thai Tea Series"
		items[1].Description = "Order Thai tea and boba favourites from nearby outlets."
		items[2].Title = "Baskbear coffee and toast"
		items[2].Description = "Start the day with premium coffee and golden toast."
	}

	return items
}

func (h *Handler) assetURL(path string) string {
	if h.publicBaseURL == "" {
		return path
	}
	return h.publicBaseURL + path
}
