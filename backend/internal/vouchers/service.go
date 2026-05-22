package vouchers

import (
	"context"
	"errors"
	"fmt"
	"html"
	"math"
	"strings"

	"github.com/loob/backend/internal/timeutil"
)

type VoucherRepository interface {
	GetCountry(ctx context.Context, countryID string) (Country, error)
	ListWallet(ctx context.Context, countryID, userID string, brandID int) ([]VoucherRow, error)
	GetWalletSummary(ctx context.Context, country Country, userID string) (WalletSummary, error)
	AssignActiveVouchers(ctx context.Context, countryID, userID string) error
}

type Service struct {
	repo VoucherRepository
}

func NewService(repo VoucherRepository) *Service {
	return &Service{repo: repo}
}

func (s *Service) Wallet(ctx context.Context, countryID, language, userID string, brandID int) (Wallet, error) {
	country, err := s.repo.GetCountry(ctx, countryID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return Wallet{}, ErrUnsupportedCountry
		}
		return Wallet{}, err
	}

	if err := s.repo.AssignActiveVouchers(ctx, countryID, userID); err != nil {
		return Wallet{}, err
	}

	rows, err := s.repo.ListWallet(ctx, countryID, userID, brandID)
	if err != nil {
		return Wallet{}, err
	}
	summary, err := s.repo.GetWalletSummary(ctx, country, userID)
	if err != nil {
		return Wallet{}, err
	}

	resolved := resolveLanguage(language, country.DefaultLanguage)
	wallet := Wallet{
		CountryCode:   country.ID,
		Language:      resolved,
		UserID:        userID,
		CurrencyCode:  summary.CurrencyCode,
		WalletBalance: summary.Balance,
		LoyaltyPoints: summary.LoyaltyPoints,
		LoyaltyTier:   summary.LoyaltyTier,
		Vouchers:      []Voucher{},
	}
	for _, row := range rows {
		status := row.Status.String
		if status == "" {
			status = "AVAILABLE"
		}
		tncMarkdown := ""
		if row.TermsAndConditionsMarkdown.Valid && row.TermsAndConditionsMarkdown.String != "" {
			tncMarkdown = row.TermsAndConditionsMarkdown.String
		} else {
			tncMarkdown = termsMarkdown(row, summary.CurrencyCode)
		}

		tncHTML := ""
		if row.TermsAndConditionsHTML.Valid && row.TermsAndConditionsHTML.String != "" {
			tncHTML = row.TermsAndConditionsHTML.String
		} else {
			tncHTML = termsHTML(row, summary.CurrencyCode)
		}

		voucher := Voucher{
			ID:                         row.ID,
			Code:                       row.Code,
			Title:                      title(row.Code, row.DiscountType, row.DiscountValue, summary.CurrencyCode),
			Description:                description(row.DiscountType, row.DiscountValue, row.MinSpend, summary.CurrencyCode),
			TermsAndConditionsMarkdown: tncMarkdown,
			TermsAndConditionsHTML:     tncHTML,
			VoucherType:                row.VoucherType,
			DiscountType:               row.DiscountType,
			DiscountValue:              row.DiscountValue,
			MinSpend:                   row.MinSpend,
			Status:                     status,
			StartsAt:                   timeutil.FormatRFC3339UTC(row.StartsAt),
			ExpiresAt:                  timeutil.FormatRFC3339UTC(row.ExpiresAt),
		}
		if row.MaxDiscountCap.Valid {
			capValue := int(row.MaxDiscountCap.Int64)
			voucher.MaxDiscountCap = &capValue
		}
		if row.BrandID.Valid {
			brandID := int(row.BrandID.Int64)
			voucher.BrandID = &brandID
		}
		if row.ZoneID.Valid {
			voucher.ZoneID = row.ZoneID.String
		}
		wallet.Vouchers = append(wallet.Vouchers, voucher)
	}
	wallet.VoucherCount = len(wallet.Vouchers)
	return wallet, nil
}

var ErrUnsupportedCountry = errors.New("unsupported country")

func resolveLanguage(language, fallback string) string {
	if strings.TrimSpace(language) == "" {
		return fallback
	}
	return language
}

func title(code, discountType string, value int, currencyCode string) string {
	switch discountType {
	case "PERCENTAGE":
		return fmt.Sprintf("%d%% off", value)
	case "FIXED_AMOUNT":
		return fmt.Sprintf("%s off", formatMoney(value, currencyCode))
	default:
		return code
	}
}

func description(discountType string, value, minSpend int, currencyCode string) string {
	switch discountType {
	case "PERCENTAGE":
		return fmt.Sprintf("Save %d%% when you spend at least %s.", value, formatMoney(minSpend, currencyCode))
	case "FIXED_AMOUNT":
		return fmt.Sprintf("Save %s when you spend at least %s.", formatMoney(value, currencyCode), formatMoney(minSpend, currencyCode))
	default:
		return fmt.Sprintf("Minimum spend %s.", formatMoney(minSpend, currencyCode))
	}
}

func termsMarkdown(row VoucherRow, currencyCode string) string {
	lines := termsLines(row, currencyCode)
	for i, line := range lines {
		lines[i] = "- " + line
	}
	return strings.Join(lines, "\n")
}

func termsHTML(row VoucherRow, currencyCode string) string {
	lines := termsLines(row, currencyCode)
	var b strings.Builder
	b.WriteString("<ul>")
	for _, line := range lines {
		b.WriteString("<li>")
		b.WriteString(html.EscapeString(line))
		b.WriteString("</li>")
	}
	b.WriteString("</ul>")
	return b.String()
}

func termsLines(row VoucherRow, currencyCode string) []string {
	lines := []string{}
	if row.MinSpend > 0 {
		lines = append(lines, fmt.Sprintf("Minimum spend %s.", formatMoney(row.MinSpend, currencyCode)))
	} else {
		lines = append(lines, "No minimum spend required.")
	}
	if row.MaxDiscountCap.Valid {
		lines = append(lines, fmt.Sprintf("Discount capped at %s.", formatMoney(int(row.MaxDiscountCap.Int64), currencyCode)))
	}
	if row.BrandID.Valid {
		lines = append(lines, "Valid only for selected brand items.")
	}
	if row.ZoneID.Valid {
		lines = append(lines, "Valid only for selected stores or zones.")
	}
	if !row.ExpiresAt.IsZero() {
		lines = append(lines, fmt.Sprintf("Valid until %s.", row.ExpiresAt.Format("2 Jan 2006")))
	}
	lines = append(lines, "Cannot be exchanged for cash.")
	return lines
}

func formatMoney(amount int, currencyCode string) string {
	symbol := currencyCode
	switch strings.ToUpper(strings.TrimSpace(currencyCode)) {
	case "MYR":
		symbol = "RM"
	}
	major := float64(amount) / 100
	if math.Mod(major, 1) == 0 {
		return fmt.Sprintf("%s %.0f", symbol, major)
	}
	return fmt.Sprintf("%s %.2f", symbol, major)
}
