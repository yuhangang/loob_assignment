package users

import (
	"context"
	"database/sql"
	"errors"
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
	CurrencyCode    string
	DefaultLanguage string
}

func (r *Repository) GetCountry(ctx context.Context, countryID string) (Country, error) {
	var country Country
	err := r.db.QueryRowContext(ctx, `
		SELECT id, currency_code, default_language
		FROM countries
		WHERE id = ? AND is_active = true
	`, countryID).Scan(&country.ID, &country.CurrencyCode, &country.DefaultLanguage)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Country{}, ErrNotFound
		}
		return Country{}, err
	}
	return country, nil
}

func (r *Repository) EnsureAccount(ctx context.Context, userID string, country Country) error {
	if _, err := r.db.ExecContext(ctx, `
		INSERT INTO users (id, display_name, preferred_language, registered_country_id)
		VALUES (?, 'Dev User', ?, ?)
		ON DUPLICATE KEY UPDATE
			registered_country_id = COALESCE(registered_country_id, VALUES(registered_country_id))
	`, userID, country.DefaultLanguage, country.ID); err != nil {
		return err
	}

	if _, err := r.db.ExecContext(ctx, `
		INSERT IGNORE INTO wallet_accounts (user_id, country_id, balance, currency_code)
		VALUES (?, ?, 0, ?)
	`, userID, country.ID, country.CurrencyCode); err != nil {
		return err
	}

	_, err := r.db.ExecContext(ctx, `
		INSERT IGNORE INTO loyalty_accounts (user_id, country_id, points, lifetime_points, tier)
		VALUES (?, ?, 0, 0, 'MEMBER')
	`, userID, country.ID)
	return err
}

func (r *Repository) GetProfile(ctx context.Context, userID, countryID string) (Profile, error) {
	var profile Profile
	var displayName, email, phone, avatar, registeredCountry sql.NullString
	var tier sql.NullString
	err := r.db.QueryRowContext(ctx, `
		SELECT u.id, u.display_name, u.email, u.phone_number, u.avatar_url,
		       u.preferred_language, u.registered_country_id, u.marketing_opt_in,
		       COALESCE(wa.balance, 0), COALESCE(wa.currency_code, c.currency_code),
		       COALESCE(la.points, 0), COALESCE(la.tier, 'MEMBER')
		FROM users u
		INNER JOIN countries c ON c.id = ?
		LEFT JOIN wallet_accounts wa ON wa.user_id = u.id AND wa.country_id = c.id
		LEFT JOIN loyalty_accounts la ON la.user_id = u.id AND la.country_id = c.id
		WHERE u.id = ?
	`, countryID, userID).Scan(
		&profile.UserID,
		&displayName,
		&email,
		&phone,
		&avatar,
		&profile.PreferredLanguage,
		&registeredCountry,
		&profile.MarketingOptIn,
		&profile.WalletBalance,
		&profile.CurrencyCode,
		&profile.LoyaltyPoints,
		&tier,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Profile{}, ErrNotFound
		}
		return Profile{}, err
	}

	profile.DisplayName = displayName.String
	profile.Email = email.String
	profile.PhoneNumber = phone.String
	profile.AvatarURL = avatar.String
	profile.RegisteredCountryID = registeredCountry.String
	profile.LoyaltyTier = tier.String
	return profile, nil
}

func (r *Repository) UpdateProfile(ctx context.Context, userID string, update ProfileUpdate) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE users
		SET display_name = ?,
		    email = NULLIF(?, ''),
		    phone_number = NULLIF(?, ''),
		    avatar_url = NULLIF(?, ''),
		    preferred_language = ?,
		    marketing_opt_in = ?
		WHERE id = ?
	`, update.DisplayName, update.Email, update.PhoneNumber, update.AvatarURL, update.PreferredLanguage, update.MarketingOptIn, userID)
	return err
}

func (r *Repository) ListWalletTransactions(ctx context.Context, userID, countryID string, limit int) (WalletHistory, error) {
	var history WalletHistory
	var currency string
	err := r.db.QueryRowContext(ctx, `
		SELECT COALESCE(wa.currency_code, c.currency_code), COALESCE(wa.balance, 0)
		FROM countries c
		LEFT JOIN wallet_accounts wa ON wa.country_id = c.id AND wa.user_id = ?
		WHERE c.id = ?
	`, userID, countryID).Scan(&currency, &history.Balance)
	if err != nil {
		return WalletHistory{}, err
	}
	history.UserID = userID
	history.CountryCode = countryID
	history.CurrencyCode = currency

	rows, err := r.db.QueryContext(ctx, `
		SELECT id, transaction_type, amount, balance_after, currency_code,
		       reference_type, reference_id, description, created_at
		FROM wallet_transactions
		WHERE user_id = ? AND country_id = ?
		ORDER BY created_at DESC, id DESC
		LIMIT ?
	`, userID, countryID, limit)
	if err != nil {
		return WalletHistory{}, err
	}
	defer rows.Close()

	for rows.Next() {
		var tx WalletTransaction
		var refType, refID, description sql.NullString
		var createdAt time.Time
		if err := rows.Scan(&tx.ID, &tx.TransactionType, &tx.Amount, &tx.BalanceAfter, &tx.CurrencyCode, &refType, &refID, &description, &createdAt); err != nil {
			return WalletHistory{}, err
		}
		tx.ReferenceType = refType.String
		tx.ReferenceID = refID.String
		tx.Description = description.String
		tx.CreatedAt = createdAt.Format("2006-01-02T15:04:05Z07:00")
		history.Transactions = append(history.Transactions, tx)
	}
	return history, rows.Err()
}

func (r *Repository) ListLoyaltyTransactions(ctx context.Context, userID, countryID string, limit int) (LoyaltyHistory, error) {
	var history LoyaltyHistory
	var tier sql.NullString
	err := r.db.QueryRowContext(ctx, `
		SELECT COALESCE(la.points, 0), COALESCE(la.tier, 'MEMBER')
		FROM countries c
		LEFT JOIN loyalty_accounts la ON la.country_id = c.id AND la.user_id = ?
		WHERE c.id = ?
	`, userID, countryID).Scan(&history.Points, &tier)
	if err != nil {
		return LoyaltyHistory{}, err
	}
	history.UserID = userID
	history.CountryCode = countryID
	history.Tier = tier.String
	if history.Tier == "" {
		history.Tier = "MEMBER"
	}

	rows, err := r.db.QueryContext(ctx, `
		SELECT id, transaction_type, points_delta, balance_after,
		       reference_type, reference_id, description, created_at
		FROM loyalty_transactions
		WHERE user_id = ? AND country_id = ?
		ORDER BY created_at DESC, id DESC
		LIMIT ?
	`, userID, countryID, limit)
	if err != nil {
		return LoyaltyHistory{}, err
	}
	defer rows.Close()

	for rows.Next() {
		var tx LoyaltyTransaction
		var refType, refID, description sql.NullString
		var createdAt time.Time
		if err := rows.Scan(&tx.ID, &tx.TransactionType, &tx.PointsDelta, &tx.BalanceAfter, &refType, &refID, &description, &createdAt); err != nil {
			return LoyaltyHistory{}, err
		}
		tx.ReferenceType = refType.String
		tx.ReferenceID = refID.String
		tx.Description = description.String
		tx.CreatedAt = createdAt.Format("2006-01-02T15:04:05Z07:00")
		history.Transactions = append(history.Transactions, tx)
	}
	return history, rows.Err()
}

func (r *Repository) TopUpWallet(ctx context.Context, userID string, country Country, amount int, description string) (WalletHistory, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return WalletHistory{}, err
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, `
		INSERT IGNORE INTO wallet_accounts (user_id, country_id, balance, currency_code)
		VALUES (?, ?, 0, ?)
	`, userID, country.ID, country.CurrencyCode); err != nil {
		return WalletHistory{}, err
	}

	var balance int
	if err := tx.QueryRowContext(ctx, `
		SELECT balance
		FROM wallet_accounts
		WHERE user_id = ? AND country_id = ?
		FOR UPDATE
	`, userID, country.ID).Scan(&balance); err != nil {
		return WalletHistory{}, err
	}
	balance += amount

	if _, err := tx.ExecContext(ctx, `
		UPDATE wallet_accounts
		SET balance = ?
		WHERE user_id = ? AND country_id = ?
	`, balance, userID, country.ID); err != nil {
		return WalletHistory{}, err
	}
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO wallet_transactions (
			user_id, country_id, transaction_type, amount, balance_after, currency_code, reference_type, description
		)
		VALUES (?, ?, 'TOPUP', ?, ?, ?, 'MANUAL', NULLIF(?, ''))
	`, userID, country.ID, amount, balance, country.CurrencyCode, description); err != nil {
		return WalletHistory{}, err
	}

	if err := tx.Commit(); err != nil {
		return WalletHistory{}, err
	}
	return r.ListWalletTransactions(ctx, userID, country.ID, defaultHistoryLimit)
}

var ErrNotFound = errors.New("not found")
