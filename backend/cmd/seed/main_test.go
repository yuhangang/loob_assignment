package main

import (
	"testing"
)

func TestGetCountryLabel(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"", "ALL countries"},
		{"MY", "MY"},
		{"TH", "TH"},
		{"SG", "SG"},
	}

	for _, tt := range tests {
		got := getCountryLabel(tt.input)
		if got != tt.want {
			t.Errorf("getCountryLabel(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}
