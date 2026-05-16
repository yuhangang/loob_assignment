package platform

import (
	"crypto/rand"
	"encoding/hex"
	"strings"
)

func NewTraceID() string {
	return "trc_" + randomHex(16)
}

func NewTrackingID(country string) string {
	return "ORD-" + strings.ToUpper(country) + "-" + randomHex(8)
}

func NewPaymentID(country string) string {
	return "PAY-" + strings.ToUpper(country) + "-" + randomHex(8)
}

func randomHex(bytes int) string {
	buf := make([]byte, bytes)
	if _, err := rand.Read(buf); err != nil {
		panic(err)
	}
	return strings.ToUpper(hex.EncodeToString(buf))
}
