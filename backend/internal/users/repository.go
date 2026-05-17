package users

import (
	"context"
	"database/sql"
	"errors"
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

var ErrNotFound = errors.New("not found")
