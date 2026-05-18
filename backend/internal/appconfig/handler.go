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
	isMalay := strings.HasPrefix(rc.Language, "ms")

	items := []FeedItem{
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
	}

	if isMalay {
		items[0].Title = "Selamat Datang ke Loob!"
		items[0].Description = "Temui teh dan kopi terbaik di bandar dengan pengalaman bersepadu kami."
		items[1].Title = "Beli 1 Percuma 1 Tealive"
		items[1].Description = "Nikmati Pearl Milk Tea istimewa kami. Beli 1 Percuma 1 untuk semua saiz hari ini!"
		items[2].Title = "Rehat Kopi Bask Bear"
		items[2].Description = "Dapatkan diskaun 50% untuk cawan kedua Aren Palm Sugar Latte anda."
	}

	resp := FeedResponse{
		Items: items,
	}
	return c.JSON(http.StatusOK, resp)
}

func (h *Handler) assetURL(path string) string {
	if h.publicBaseURL == "" {
		return path
	}
	return h.publicBaseURL + path
}
