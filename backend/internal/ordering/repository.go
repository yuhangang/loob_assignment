package ordering

import (
	"context"
	"database/sql"
)

type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) ClaimQueued(ctx context.Context, limit int) ([]Intent, error) {
	if limit <= 0 {
		limit = 25
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	rows, err := tx.QueryContext(ctx, `
		SELECT tracking_id, country_id
		FROM order_intents
		WHERE status = 'QUEUED'
		ORDER BY created_at, tracking_id
		LIMIT ?
		FOR UPDATE SKIP LOCKED
	`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	intents := []Intent{}
	for rows.Next() {
		var intent Intent
		if err := rows.Scan(&intent.TrackingID, &intent.CountryID); err != nil {
			return nil, err
		}
		intents = append(intents, intent)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if err := rows.Close(); err != nil {
		return nil, err
	}
	if len(intents) == 0 {
		return nil, ErrNoQueuedIntents
	}

	for _, intent := range intents {
		if _, err := tx.ExecContext(ctx, `
			UPDATE order_intents
			SET status = 'PROCESSING'
			WHERE tracking_id = ? AND country_id = ? AND status = 'QUEUED'
		`, intent.TrackingID, intent.CountryID); err != nil {
			return nil, err
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return intents, nil
}

func (r *Repository) Complete(ctx context.Context, intent Intent) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE order_intents
		SET status = 'COMPLETED'
		WHERE tracking_id = ? AND country_id = ? AND status IN ('PROCESSING', 'COMPLETED')
	`, intent.TrackingID, intent.CountryID)
	return err
}

func (r *Repository) Fail(ctx context.Context, intent Intent) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE order_intents
		SET status = 'FAILED'
		WHERE tracking_id = ? AND country_id = ? AND status = 'PROCESSING'
	`, intent.TrackingID, intent.CountryID)
	return err
}
