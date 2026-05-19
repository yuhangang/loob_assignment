package catalog

// CountryConfigMap is our static in-memory cache of country settings,
// eliminating the need to query the `countries` database table for simple configuration lookups.
var CountryConfigMap = map[string]Country{
	"MY": {
		ID:              "MY",
		CurrencyCode:    "MYR",
		TaxRate:         0.06,
		DefaultLanguage: "en-US",
	},
	"TH": {
		ID:              "TH",
		CurrencyCode:    "THB",
		TaxRate:         0.07,
		DefaultLanguage: "th-TH",
	},
}
