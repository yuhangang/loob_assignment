package platform

import (
	"strings"
	"testing"
)

func TestNewTraceID(t *testing.T) {
	id := NewTraceID()
	if !strings.HasPrefix(id, "trc_") {
		t.Errorf("expected prefix trc_, got %s", id)
	}
	if len(id) != 4+32 { // trc_ + 16 bytes hex (32 chars)
		t.Errorf("expected length 36, got %d", len(id))
	}
}

func TestNewTrackingID(t *testing.T) {
	id := NewTrackingID("MY")
	if !strings.HasPrefix(id, "ORD-MY-") {
		t.Errorf("expected prefix ORD-MY-, got %s", id)
	}
}
