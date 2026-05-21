package main

import "testing"

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

func TestChooseSeedDisplayPriceUsesBeautifulIncrementsForMY(t *testing.T) {
	for i := 0; i < 200; i++ {
		price := chooseSeedDisplayPrice("MY", 800, 1200)
		if price < 800 || price > 1200 {
			t.Fatalf("price out of range: %d", price)
		}
		if price%10 != 0 {
			t.Fatalf("price not aligned to MY step: %d", price)
		}
	}
}

func TestChooseSeedDisplayPriceUsesBeautifulIncrementsForTH(t *testing.T) {
	for i := 0; i < 200; i++ {
		price := chooseSeedDisplayPrice("TH", 6500, 8500)
		if price < 6500 || price > 8500 {
			t.Fatalf("price out of range: %d", price)
		}
		if price%100 != 0 {
			t.Fatalf("price not aligned to TH step: %d", price)
		}
	}
}

func TestChooseSeedDisplayPriceKeepsSingleValue(t *testing.T) {
	price := chooseSeedDisplayPrice("MY", 150, 150)
	if price != 150 {
		t.Fatalf("price = %d, want 150", price)
	}
}

func TestChooseSeedDisplayPriceFallsBackWhenRangeHasNoAlignedStep(t *testing.T) {
	price := chooseSeedDisplayPrice("TH", 6510, 6590)
	if price != 6510 {
		t.Fatalf("price = %d, want 6510", price)
	}
}
