package contextx

import (
	"log"
	"net/http"
	"strings"

	"github.com/labstack/echo/v4"
	"github.com/loob/backend/internal/platform"
)

const requestContextKey = "request_context"

type RequestContext struct {
	TraceID     string
	CountryCode string
	Language    string
}

func Middleware() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			traceID := strings.TrimSpace(c.Request().Header.Get("X-Trace-Id"))
			if traceID == "" {
				traceID = platform.NewTraceID()
			}

			country := strings.ToUpper(strings.TrimSpace(c.Request().Header.Get("X-Country-Code")))
			if country == "" {
				country = "MY"
			}

			log.Printf("CONTEXT: trace_id=%s country=%s language=%s", traceID, country, normalizeLanguage(c.Request().Header.Get("Accept-Language")))

			rc := RequestContext{
				TraceID:     traceID,
				CountryCode: country,
				Language:    normalizeLanguage(c.Request().Header.Get("Accept-Language")),
			}

			c.Set(requestContextKey, rc)
			c.Response().Header().Set("X-Trace-Id", traceID)
			return next(c)
		}
	}
}

func FromEcho(c echo.Context) RequestContext {
	rc, ok := c.Get(requestContextKey).(RequestContext)
	if !ok {
		return RequestContext{
			TraceID:     platform.NewTraceID(),
			CountryCode: "MY",
			Language:    "en-US",
		}
	}
	return rc
}

func RequireCountryHeader(c echo.Context) error {
	if strings.TrimSpace(c.Request().Header.Get("X-Country-Code")) == "" {
		return echo.NewHTTPError(http.StatusBadRequest, map[string]string{
			"error": "X-Country-Code header is required for checkout",
		})
	}
	return nil
}

func normalizeLanguage(header string) string {
	header = strings.TrimSpace(header)
	if header == "" {
		return "en-US"
	}

	first := strings.Split(header, ",")[0]
	first = strings.TrimSpace(strings.Split(first, ";")[0])
	if first == "" || first == "*" {
		return "en-US"
	}
	return first
}
