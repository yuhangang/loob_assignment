package campaigns

import (
	"context"
	"database/sql"
	"encoding/json"
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
	DefaultLanguage string
}

type CampaignRow struct {
	ID                   int
	CountryID            string
	BrandID              sql.NullInt64
	CampaignType         string
	TitleTranslations    map[string]string
	SubtitleTranslations map[string]string
	ImageURL             string
	DeepLink             string
	WebviewURL           string
	Priority             int
	Metadata             map[string]any
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

func (r *Repository) ListActive(ctx context.Context, countryID string, brandID int) ([]CampaignRow, error) {
	query := `
		SELECT id, country_id, brand_id, campaign_type, title_translations,
		       COALESCE(subtitle_translations, JSON_OBJECT()), COALESCE(image_url, ''),
		       COALESCE(deep_link, ''), COALESCE(webview_url, ''), priority,
		       COALESCE(metadata, JSON_OBJECT())
		FROM campaigns
		WHERE country_id = ? AND is_active = true AND NOW() BETWEEN starts_at AND ends_at
	`
	args := []any{countryID}
	if brandID > 0 {
		query += " AND (brand_id IS NULL OR brand_id = ?)"
		args = append(args, brandID)
	}
	query += " ORDER BY priority DESC, id"

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var campaigns []CampaignRow
	for rows.Next() {
		var row CampaignRow
		var titleJSON, subtitleJSON, metadataJSON []byte
		if err := rows.Scan(&row.ID, &row.CountryID, &row.BrandID, &row.CampaignType, &titleJSON, &subtitleJSON, &row.ImageURL, &row.DeepLink, &row.WebviewURL, &row.Priority, &metadataJSON); err != nil {
			return nil, err
		}
		row.TitleTranslations = decodeStringMap(titleJSON)
		row.SubtitleTranslations = decodeStringMap(subtitleJSON)
		row.Metadata = decodeAnyMap(metadataJSON)
		campaigns = append(campaigns, row)
	}
	return campaigns, rows.Err()
}

var ErrNotFound = errors.New("not found")

func decodeStringMap(raw []byte) map[string]string {
	if len(raw) == 0 {
		return map[string]string{}
	}
	var out map[string]string
	if err := json.Unmarshal(raw, &out); err != nil {
		return map[string]string{}
	}
	return out
}

func decodeAnyMap(raw []byte) map[string]any {
	if len(raw) == 0 {
		return map[string]any{}
	}
	var out map[string]any
	if err := json.Unmarshal(raw, &out); err != nil {
		return map[string]any{}
	}
	return out
}
