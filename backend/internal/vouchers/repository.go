package vouchers

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"
)

type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

type Country struct {
	ID              string
	DefaultLanguage string
}

type VoucherRow struct {
	ID             int
	Code           string
	ZoneID         sql.NullString
	BrandID        sql.NullInt64
	VoucherType    string
	DiscountType   string
	DiscountValue  int
	MinSpend       int
	MaxDiscountCap sql.NullInt64
	StartsAt       time.Time
	ExpiresAt      time.Time
	Status         sql.NullString
}

func (r *Repository) GetCountry(ctx context.Context, countryID string) (Country, error) {
	var country Country
	err := r.db.QueryRowContext(ctx, `
		SELECT id, default_language
		FROM countries
		WHERE id = ? AND is_active = true
	`, countryID).Scan(&country.ID, &country.DefaultLanguage)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Country{}, ErrNotFound
		}
		return Country{}, err
	}
	return country, nil
}

func (r *Repository) ListWallet(ctx context.Context, countryID, userID string, brandID int) ([]VoucherRow, error) {
	query := `
		SELECT v.id, v.code, v.zone_id, v.brand_id, v.voucher_type, v.discount_type,
		       v.discount_value, v.min_spend, v.max_discount_cap, v.starts_at, v.expires_at,
		       uv.status
		FROM vouchers v
		LEFT JOIN user_vouchers uv ON uv.voucher_id = v.id AND uv.user_id = ?
		WHERE v.country_id = ? AND v.is_active = true AND NOW() BETWEEN v.starts_at AND v.expires_at
	`
	args := []any{userID, countryID}
	if brandID > 0 {
		query += " AND (v.brand_id IS NULL OR v.brand_id = ?)"
		args = append(args, brandID)
	}
	query += " ORDER BY COALESCE(uv.assigned_at, v.starts_at) DESC, v.id"

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var vouchers []VoucherRow
	for rows.Next() {
		var row VoucherRow
		if err := rows.Scan(&row.ID, &row.Code, &row.ZoneID, &row.BrandID, &row.VoucherType, &row.DiscountType, &row.DiscountValue, &row.MinSpend, &row.MaxDiscountCap, &row.StartsAt, &row.ExpiresAt, &row.Status); err != nil {
			return nil, err
		}
		vouchers = append(vouchers, row)
	}
	return vouchers, rows.Err()
}

func (r *Repository) AssignActiveVouchers(ctx context.Context, countryID, userID string) error {
	if strings.TrimSpace(userID) == "" {
		return nil
	}
	if _, err := r.db.ExecContext(ctx, `
		INSERT INTO users (id, registered_country_id)
		VALUES (?, ?)
		ON DUPLICATE KEY UPDATE registered_country_id = COALESCE(registered_country_id, VALUES(registered_country_id))
	`, userID, countryID); err != nil {
		return err
	}
	_, err := r.db.ExecContext(ctx, `
		INSERT IGNORE INTO user_vouchers (user_id, voucher_id, status)
		SELECT ?, id, 'AVAILABLE'
		FROM vouchers
		WHERE country_id = ? AND is_active = true AND NOW() BETWEEN starts_at AND expires_at
	`, userID, countryID)
	return err
}

var ErrNotFound = errors.New("not found")
