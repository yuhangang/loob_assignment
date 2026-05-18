package auth

import (
	"encoding/base64"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v4"
)

func TestRequiredRejectsMissingBearerToken(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	err := New(Config{}).Required()(func(c echo.Context) error {
		return c.NoContent(http.StatusNoContent)
	})(c)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	he, ok := err.(*echo.HTTPError)
	if !ok {
		t.Fatalf("expected echo.HTTPError, got %T", err)
	}
	if he.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d", he.Code)
	}
}

func TestVerifyRequiresFirebaseProject(t *testing.T) {
	_, err := New(Config{}).Verify(t.Context(), "header.payload.signature")
	if err != ErrFirebaseProjectRequired {
		t.Fatalf("expected ErrFirebaseProjectRequired, got %v", err)
	}
}

func TestVerifyMockToken(t *testing.T) {
	a := New(Config{FirebaseProjectID: "mock-project-id"})

	// Construct a mock token: header + payload + signature
	// Header: {"alg":"none"} => base64: eyJhbGciOiJub25lIn0
	headerStr := "eyJhbGciOiJub25lIn0"
	payloadJSON := `{"aud":"mock-project-id","iss":"https://securetoken.google.com/mock-project-id","sub":"mock_user_001","exp":2900000000,"iat":1500000000,"phone_number":"+60123456789"}`
	payloadStr := base64.RawURLEncoding.EncodeToString([]byte(payloadJSON))
	token := headerStr + "." + payloadStr + ".mock-signature"

	claims, err := a.Verify(t.Context(), token)
	if err != nil {
		t.Fatalf("unexpected error verifying mock token: %v", err)
	}

	if claims.UserID != "mock_user_001" {
		t.Fatalf("expected UserID 'mock_user_001', got %q", claims.UserID)
	}
	if claims.PhoneNumber != "+60123456789" {
		t.Fatalf("expected PhoneNumber '+60123456789', got %q", claims.PhoneNumber)
	}
}
