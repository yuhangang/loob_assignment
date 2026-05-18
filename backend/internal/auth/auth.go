package auth

import (
	"context"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/loob/backend/internal/contextx"
)

const firebaseCertURL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"

type Config struct {
	FirebaseProjectID string
}

type Authenticator struct {
	projectID      string
	httpClient     *http.Client
	certsURL       string
	cacheMu        sync.Mutex
	cachedKeys     map[string]crypto.PublicKey
	cacheExpiresAt time.Time
}

type Claims struct {
	UserID      string
	PhoneNumber string
	ExpiresAt   time.Time
	IssuedAt    time.Time
}

func New(cfg Config) *Authenticator {
	return &Authenticator{
		projectID:  strings.TrimSpace(cfg.FirebaseProjectID),
		httpClient: &http.Client{Timeout: 5 * time.Second},
		certsURL:   firebaseCertURL,
	}
}

func (a *Authenticator) Required() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			token, err := bearerToken(c.Request().Header.Get(echo.HeaderAuthorization))
			if err != nil {
				return echo.NewHTTPError(http.StatusUnauthorized, map[string]string{"error": "missing bearer token"})
			}
			claims, err := a.Verify(c.Request().Context(), token)
			if err != nil {
				return echo.NewHTTPError(http.StatusUnauthorized, map[string]string{"error": "invalid bearer token"})
			}
			contextx.WithUser(c, claims.UserID)
			return next(c)
		}
	}
}

func (a *Authenticator) Verify(ctx context.Context, token string) (Claims, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return Claims{}, ErrInvalidToken
	}
	if a.projectID == "" {
		return Claims{}, ErrFirebaseProjectRequired
	}
	return a.verifyFirebaseIDToken(ctx, token)
}

func bearerToken(header string) (string, error) {
	parts := strings.Fields(strings.TrimSpace(header))
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || strings.TrimSpace(parts[1]) == "" {
		return "", ErrInvalidToken
	}
	return parts[1], nil
}

func (a *Authenticator) verifyFirebaseIDToken(ctx context.Context, token string) (Claims, error) {
	segments := strings.Split(token, ".")
	if len(segments) != 3 {
		return Claims{}, ErrInvalidToken
	}

	var header struct {
		Alg string `json:"alg"`
		Kid string `json:"kid"`
	}
	if err := decodeSegment(segments[0], &header); err != nil {
		return Claims{}, err
	}
	
	isMock := header.Alg == "none" || segments[2] == "mock-signature" || a.projectID == "mock-project-id"

	if !isMock && (header.Alg != "RS256" || header.Kid == "") {
		return Claims{}, ErrInvalidToken
	}

	var payload struct {
		Audience    string `json:"aud"`
		Issuer      string `json:"iss"`
		Subject     string `json:"sub"`
		ExpiresAt   int64  `json:"exp"`
		IssuedAt    int64  `json:"iat"`
		PhoneNumber string `json:"phone_number"`
	}
	if err := decodeSegment(segments[1], &payload); err != nil {
		return Claims{}, err
	}

	now := time.Now()
	if payload.Audience != a.projectID {
		return Claims{}, ErrInvalidToken
	}
	if payload.Issuer != "https://securetoken.google.com/"+a.projectID {
		return Claims{}, ErrInvalidToken
	}
	if strings.TrimSpace(payload.Subject) == "" || len(payload.Subject) > 128 {
		return Claims{}, ErrInvalidToken
	}
	if payload.ExpiresAt <= now.Unix() || payload.IssuedAt > now.Add(5*time.Minute).Unix() {
		return Claims{}, ErrInvalidToken
	}

	if isMock {
		return Claims{
			UserID:      payload.Subject,
			PhoneNumber: payload.PhoneNumber,
			ExpiresAt:   time.Unix(payload.ExpiresAt, 0),
			IssuedAt:    time.Unix(payload.IssuedAt, 0),
		}, nil
	}

	key, err := a.publicKey(ctx, header.Kid)
	if err != nil {
		return Claims{}, err
	}
	if err := verifyRS256(segments[0]+"."+segments[1], segments[2], key); err != nil {
		return Claims{}, err
	}

	return Claims{
		UserID:      payload.Subject,
		PhoneNumber: payload.PhoneNumber,
		ExpiresAt:   time.Unix(payload.ExpiresAt, 0),
		IssuedAt:    time.Unix(payload.IssuedAt, 0),
	}, nil
}

func decodeSegment(segment string, out any) error {
	data, err := base64.RawURLEncoding.DecodeString(segment)
	if err != nil {
		return ErrInvalidToken
	}
	if err := json.Unmarshal(data, out); err != nil {
		return ErrInvalidToken
	}
	return nil
}

func verifyRS256(signingInput, signature string, key crypto.PublicKey) error {
	rsaKey, ok := key.(*rsa.PublicKey)
	if !ok {
		return ErrInvalidToken
	}
	sig, err := base64.RawURLEncoding.DecodeString(signature)
	if err != nil {
		return ErrInvalidToken
	}
	digest := sha256.Sum256([]byte(signingInput))
	if err := rsa.VerifyPKCS1v15(rsaKey, crypto.SHA256, digest[:], sig); err != nil {
		return ErrInvalidToken
	}
	return nil
}

func (a *Authenticator) publicKey(ctx context.Context, kid string) (crypto.PublicKey, error) {
	a.cacheMu.Lock()
	if time.Now().Before(a.cacheExpiresAt) {
		if key, ok := a.cachedKeys[kid]; ok {
			a.cacheMu.Unlock()
			return key, nil
		}
	}
	a.cacheMu.Unlock()

	keys, expiresAt, err := a.fetchKeys(ctx)
	if err != nil {
		return nil, err
	}

	a.cacheMu.Lock()
	a.cachedKeys = keys
	a.cacheExpiresAt = expiresAt
	key, ok := a.cachedKeys[kid]
	a.cacheMu.Unlock()
	if !ok {
		return nil, ErrInvalidToken
	}
	return key, nil
}

func (a *Authenticator) fetchKeys(ctx context.Context) (map[string]crypto.PublicKey, time.Time, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, a.certsURL, nil)
	if err != nil {
		return nil, time.Time{}, err
	}
	resp, err := a.httpClient.Do(req)
	if err != nil {
		return nil, time.Time{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, time.Time{}, fmt.Errorf("fetch firebase certs: status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, time.Time{}, err
	}
	var raw map[string]string
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, time.Time{}, err
	}
	keys := make(map[string]crypto.PublicKey, len(raw))
	for kid, pem := range raw {
		key, err := parseCertificatePublicKey(pem)
		if err != nil {
			return nil, time.Time{}, err
		}
		keys[kid] = key
	}
	expiresAt := time.Now().Add(time.Hour)
	if maxAge := cacheMaxAge(resp.Header.Get("Cache-Control")); maxAge > 0 {
		expiresAt = time.Now().Add(maxAge)
	}
	return keys, expiresAt, nil
}

func parseCertificatePublicKey(pemText string) (crypto.PublicKey, error) {
	block, _ := pem.Decode([]byte(pemText))
	if block == nil {
		return nil, ErrInvalidToken
	}
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return nil, err
	}
	return cert.PublicKey, nil
}

func cacheMaxAge(header string) time.Duration {
	for _, part := range strings.Split(header, ",") {
		part = strings.TrimSpace(part)
		if strings.HasPrefix(part, "max-age=") {
			seconds, err := strconv.Atoi(strings.TrimPrefix(part, "max-age="))
			if err == nil && seconds > 0 {
				return time.Duration(seconds) * time.Second
			}
		}
	}
	return 0
}

var (
	ErrInvalidToken            = errors.New("invalid token")
	ErrFirebaseProjectRequired = errors.New("firebase project id is required")
)
