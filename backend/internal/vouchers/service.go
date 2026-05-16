package vouchers

import (
	"context"
	"errors"
	"fmt"
	"strings"
)

type VoucherRepository interface {
	GetCountry(ctx context.Context, countryID string) (Country, error)
	ListWallet(ctx context.Context, countryID, userID string, brandID int) ([]VoucherRow, error)
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

	resolved := resolveLanguage(language, country.DefaultLanguage)
	wallet := Wallet{
		CountryCode: country.ID,
		Language:    resolved,
		UserID:      userID,
		Vouchers:    []Voucher{},
	}
	for _, row := range rows {
		status := row.Status.String
		if status == "" {
			status = "AVAILABLE"
		}
		voucher := Voucher{
			ID:            row.ID,
			Code:          row.Code,
			Title:         title(row.Code, row.DiscountType, row.DiscountValue),
			Description:   description(row.DiscountType, row.DiscountValue, row.MinSpend),
			VoucherType:   row.VoucherType,
			DiscountType:  row.DiscountType,
			DiscountValue: row.DiscountValue,
			MinSpend:      row.MinSpend,
			Status:        status,
			StartsAt:      row.StartsAt.Format("2006-01-02T15:04:05Z07:00"),
			ExpiresAt:     row.ExpiresAt.Format("2006-01-02T15:04:05Z07:00"),
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
	return wallet, nil
}

var ErrUnsupportedCountry = errors.New("unsupported country")

func resolveLanguage(language, fallback string) string {
	if strings.TrimSpace(language) == "" {
		return fallback
	}
	return language
}

func title(code, discountType string, value int) string {
	switch discountType {
	case "PERCENTAGE":
		return fmt.Sprintf("%d%% off", value)
	case "FIXED_AMOUNT":
		return fmt.Sprintf("%s reward", code)
	default:
		return code
	}
}

func description(discountType string, value, minSpend int) string {
	switch discountType {
	case "PERCENTAGE":
		return fmt.Sprintf("Save %d%% when you spend at least %d.", value, minSpend)
	case "FIXED_AMOUNT":
		return fmt.Sprintf("Save %d when you spend at least %d.", value, minSpend)
	default:
		return fmt.Sprintf("Minimum spend %d.", minSpend)
	}
}
