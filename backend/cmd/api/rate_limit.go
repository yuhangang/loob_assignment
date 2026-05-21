package main

import (
	"net/http"
	"sync"
	"time"

	"github.com/labstack/echo/v4"
)

type clientBucket struct {
	tokens     float64
	lastSeen   time.Time
	lastRefill time.Time
}

func newIPRateLimiter(rps, burst int) echo.MiddlewareFunc {
	if rps <= 0 || burst <= 0 {
		return func(next echo.HandlerFunc) echo.HandlerFunc {
			return next
		}
	}

	var mu sync.Mutex
	buckets := map[string]*clientBucket{}

	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			now := time.Now()
			key := c.RealIP()
			if key == "" {
				key = c.Request().RemoteAddr
			}

			mu.Lock()
			bucket := buckets[key]
			if bucket == nil {
				bucket = &clientBucket{tokens: float64(burst), lastRefill: now}
				buckets[key] = bucket
			}
			elapsed := now.Sub(bucket.lastRefill).Seconds()
			if elapsed > 0 {
				bucket.tokens += elapsed * float64(rps)
				if bucket.tokens > float64(burst) {
					bucket.tokens = float64(burst)
				}
				bucket.lastRefill = now
			}
			bucket.lastSeen = now
			allowed := bucket.tokens >= 1
			if allowed {
				bucket.tokens--
			}
			if len(buckets) > 1024 {
				for ip, candidate := range buckets {
					if now.Sub(candidate.lastSeen) > 5*time.Minute {
						delete(buckets, ip)
					}
				}
			}
			mu.Unlock()

			if !allowed {
				return echo.NewHTTPError(http.StatusTooManyRequests, map[string]string{"error": "rate limit exceeded"})
			}
			return next(c)
		}
	}
}
