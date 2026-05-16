package payments

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"time"
)

type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

type TransactionRow struct {
	ID                string
	OrderTrackingID   string
	Provider          string
	MethodCode        sql.NullString
	ProviderReference sql.NullString
	Status            string
	OrderStatus       string
	CurrencyCode      string
	Amount            int
	UpdatedAt         time.Time
}

type ProviderRow struct {
	Code        string
	DisplayName string
	Type        string
	CallbackURL string
	IsMock      bool
	IsActive    bool
	Config      map[string]any
}

type MethodRow struct {
	ID           int
	Code         string
	ProviderCode string
	CountryID    string
	BrandID      sql.NullInt64
	DisplayName  string
	Description  string
	CurrencyCode string
	MinAmount    int
	MaxAmount    sql.NullInt64
	DisplayOrder int
	Metadata     map[string]any
}

type PaymentMethod struct {
	Code         string
	ProviderCode string
	CurrencyCode string
	MinAmount    int
	MaxAmount    sql.NullInt64
}

type PendingTransaction struct {
	ID              string
	OrderTrackingID string
	CountryID       string
	UserID          string
	Provider        string
	MethodCode      string
	Status          string
	CurrencyCode    string
	Amount          int
}

type CallbackUpdate struct {
	TransactionID    string
	GatewayReference string
	GatewayEventID   string
	PaymentStatus    string
	OrderStatus      string
	EventType        string
	Payload          map[string]any
}

func (r *Repository) ApplyCallback(ctx context.Context, update CallbackUpdate) (TransactionRow, error) {
	payload, err := json.Marshal(update.Payload)
	if err != nil {
		return TransactionRow{}, err
	}
	if update.GatewayEventID == "" {
		update.GatewayEventID = update.TransactionID + ":" + update.PaymentStatus
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return TransactionRow{}, err
	}
	defer tx.Rollback()

	var provider string
	if err := tx.QueryRowContext(ctx, `
		SELECT provider
		FROM payment_transactions
		WHERE id = ?
		FOR UPDATE
	`, update.TransactionID).Scan(&provider); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return TransactionRow{}, ErrNotFound
		}
		return TransactionRow{}, err
	}

	if _, err := tx.ExecContext(ctx, `
		INSERT IGNORE INTO payment_events (
			payment_transaction_id, provider, gateway_event_id, event_type, status, payload
		)
		VALUES (?, ?, ?, ?, ?, CAST(? AS JSON))
	`, update.TransactionID, provider, update.GatewayEventID, update.EventType, update.PaymentStatus, string(payload)); err != nil {
		return TransactionRow{}, err
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE payment_transactions
		SET provider_reference = COALESCE(NULLIF(?, ''), provider_reference),
		    status = ?,
		    gateway_payload = CAST(? AS JSON)
		WHERE id = ?
	`, update.GatewayReference, update.PaymentStatus, string(payload), update.TransactionID); err != nil {
		return TransactionRow{}, err
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE order_intents oi
		INNER JOIN payment_transactions pt ON pt.order_tracking_id = oi.tracking_id
		SET oi.status = ?
		WHERE pt.id = ?
	`, update.OrderStatus, update.TransactionID); err != nil {
		return TransactionRow{}, err
	}

	transaction, err := getTransactionTx(ctx, tx, update.TransactionID)
	if err != nil {
		return TransactionRow{}, err
	}
	if err := tx.Commit(); err != nil {
		return TransactionRow{}, err
	}
	return transaction, nil
}

func (r *Repository) Get(ctx context.Context, countryID, transactionID string) (TransactionRow, error) {
	transaction, err := getTransaction(ctx, r.db, countryID, transactionID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return TransactionRow{}, ErrNotFound
		}
		return TransactionRow{}, err
	}
	return transaction, nil
}

func (r *Repository) ResolvePaymentMethod(ctx context.Context, countryID string, brandID int, methodCode string, amount int) (PaymentMethod, error) {
	query := `
		SELECT code, provider_code, currency_code, min_amount, max_amount
		FROM payment_methods
		WHERE country_id = ?
		  AND is_active = true
		  AND (brand_id IS NULL OR brand_id = ?)
		  AND ? >= min_amount
		  AND (max_amount IS NULL OR ? <= max_amount)
	`
	args := []any{countryID, brandID, amount, amount}
	if methodCode != "" {
		query += " AND code = ?"
		args = append(args, methodCode)
	}
	query += " ORDER BY CASE WHEN brand_id = ? THEN 0 ELSE 1 END, display_order, id LIMIT 1"
	args = append(args, brandID)

	var method PaymentMethod
	err := r.db.QueryRowContext(ctx, query, args...).Scan(&method.Code, &method.ProviderCode, &method.CurrencyCode, &method.MinAmount, &method.MaxAmount)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return PaymentMethod{}, ErrNotFound
		}
		return PaymentMethod{}, err
	}
	return method, nil
}

func (r *Repository) CreatePendingTransaction(ctx context.Context, payment PendingTransaction) (TransactionRow, error) {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO payment_transactions (
			id, order_tracking_id, country_id, user_id, provider, payment_method_code, status, currency_code, amount
		)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
	`, payment.ID, payment.OrderTrackingID, payment.CountryID, payment.UserID, payment.Provider, payment.MethodCode, payment.Status, payment.CurrencyCode, payment.Amount)
	if err != nil {
		return TransactionRow{}, err
	}
	return r.Get(ctx, payment.CountryID, payment.ID)
}

func (r *Repository) ListProviders(ctx context.Context, includeInactive bool) ([]ProviderRow, error) {
	query := `
		SELECT code, display_name, provider_type, callback_url, is_mock, is_active, COALESCE(config, JSON_OBJECT())
		FROM payment_providers
	`
	if !includeInactive {
		query += " WHERE is_active = true"
	}
	query += " ORDER BY id"

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var providers []ProviderRow
	for rows.Next() {
		var row ProviderRow
		var configJSON []byte
		if err := rows.Scan(&row.Code, &row.DisplayName, &row.Type, &row.CallbackURL, &row.IsMock, &row.IsActive, &configJSON); err != nil {
			return nil, err
		}
		row.Config = decodeAnyMap(configJSON)
		providers = append(providers, row)
	}
	return providers, rows.Err()
}

func (r *Repository) ListMethods(ctx context.Context, countryID string, brandID int, includeInactive bool) ([]MethodRow, error) {
	query := `
		SELECT id, code, provider_code, country_id, brand_id, display_name,
		       COALESCE(description, ''), currency_code, min_amount, max_amount,
		       display_order, COALESCE(metadata, JSON_OBJECT())
		FROM payment_methods
		WHERE country_id = ?
	`
	args := []any{countryID}
	if brandID > 0 {
		query += " AND (brand_id IS NULL OR brand_id = ?)"
		args = append(args, brandID)
	}
	if !includeInactive {
		query += " AND is_active = true"
	}
	query += " ORDER BY CASE WHEN brand_id = ? THEN 0 ELSE 1 END, display_order, id"
	args = append(args, brandID)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var methods []MethodRow
	for rows.Next() {
		var row MethodRow
		var metadataJSON []byte
		if err := rows.Scan(&row.ID, &row.Code, &row.ProviderCode, &row.CountryID, &row.BrandID, &row.DisplayName, &row.Description, &row.CurrencyCode, &row.MinAmount, &row.MaxAmount, &row.DisplayOrder, &metadataJSON); err != nil {
			return nil, err
		}
		row.Metadata = decodeAnyMap(metadataJSON)
		methods = append(methods, row)
	}
	return methods, rows.Err()
}

func getTransactionTx(ctx context.Context, tx *sql.Tx, transactionID string) (TransactionRow, error) {
	var transaction TransactionRow
	err := tx.QueryRowContext(ctx, transactionQuery(), transactionID).Scan(
		&transaction.ID,
		&transaction.OrderTrackingID,
		&transaction.Provider,
		&transaction.MethodCode,
		&transaction.ProviderReference,
		&transaction.Status,
		&transaction.OrderStatus,
		&transaction.CurrencyCode,
		&transaction.Amount,
		&transaction.UpdatedAt,
	)
	return transaction, err
}

func getTransaction(ctx context.Context, db *sql.DB, countryID, transactionID string) (TransactionRow, error) {
	var transaction TransactionRow
	err := db.QueryRowContext(ctx, transactionQuery()+` AND pt.country_id = ?`, transactionID, countryID).Scan(
		&transaction.ID,
		&transaction.OrderTrackingID,
		&transaction.Provider,
		&transaction.MethodCode,
		&transaction.ProviderReference,
		&transaction.Status,
		&transaction.OrderStatus,
		&transaction.CurrencyCode,
		&transaction.Amount,
		&transaction.UpdatedAt,
	)
	return transaction, err
}

func transactionQuery() string {
	return `
		SELECT pt.id, pt.order_tracking_id, pt.provider, pt.payment_method_code, pt.provider_reference,
		       pt.status, oi.status, pt.currency_code, pt.amount, pt.updated_at
		FROM payment_transactions pt
		INNER JOIN order_intents oi ON oi.tracking_id = pt.order_tracking_id
		WHERE pt.id = ?
	`
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

var ErrNotFound = errors.New("not found")
