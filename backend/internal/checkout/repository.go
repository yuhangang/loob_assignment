package checkout

import (
	"context"
	"database/sql"
	"encoding/json"
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
	ID       string
	TaxRate  float64
	Currency string
}

type Store struct {
	ID                int
	CountryID         string
	ZoneID            string
	BrandID           int
	OperationalStatus string
}

func (s Store) AcceptsOrders() bool {
	return strings.EqualFold(strings.TrimSpace(s.OperationalStatus), "OPEN")
}

type PricedItem struct {
	MenuItemID   int
	CategoryID   int
	BasePrice    int
	TaxInclusive bool
	BrandID      int
	IsPromoItem  bool
}

type OptionPrice struct {
	ID              int
	MenuItemID      int
	GroupID         int
	PriceAdjustment int
	TaxInclusive    bool
}

type CustomizationGroupRule struct {
	ID            int
	MenuItemID    int
	SelectionType string
	MinSelections int
	IsRequired    bool
	MaxSelections int
}

type CustomizationOptionRule struct {
	ID         int
	GroupID    int
	MenuItemID int
}

type Voucher struct {
	Code                     string
	ZoneID                   sql.NullString
	BrandID                  sql.NullInt64
	DiscountType             string
	DiscountValue            int
	MinSpend                 int
	MaxDiscountCap           sql.NullInt64
	MaxRedemptions           sql.NullInt64
	MaxRedemptionsPerUser    sql.NullInt64
	AllowPromoItems          bool
	ApplicableStoreIDs       []int
	ApplicableCategoryIDs    []int
	ApplicableItemIDs        []int
	ApplicablePaymentMethods []string
	UserVoucherStatus        sql.NullString
	TotalRedemptions         int
	UserRedemptions          int
}

type ChargeDefinition struct {
	Code              string
	Name              string
	Scope             string
	CalculationType   string
	Amount            int
	Taxable           bool
	TaxInclusive      bool
	WaiverMinSubtotal sql.NullInt64
	WaiverReason      sql.NullString
}

type ChargeLine struct {
	Code          string `json:"code"`
	Name          string `json:"name"`
	Scope         string `json:"scope"`
	Amount        int    `json:"amount"`
	TaxableAmount int    `json:"taxable_amount"`
	TaxAmount     int    `json:"tax_amount"`
	TotalAmount   int    `json:"total_amount"`
	Taxable       bool   `json:"taxable"`
	TaxInclusive  bool   `json:"tax_inclusive"`
	Waived        bool   `json:"waived"`
	WaiverReason  string `json:"waiver_reason,omitempty"`
}

type Intent struct {
	TrackingID     string
	TraceID        string
	IdempotencyKey string
	UserID         string
	StoreID        int
	CountryID      string
	Fulfillment    string
	Status         string
	Subtotal       int
	Charges        []ChargeLine
	TaxAmount      int
	DiscountAmount int
	TotalAmount    int
	VoucherCode    string
	CartPayload    []byte
	ChargesPayload []byte
}

type PaymentTransaction struct {
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

type Status struct {
	TrackingID     string
	Status         string
	PaymentStatus  sql.NullString
	TransactionID  sql.NullString
	Subtotal       int
	Charges        []ChargeLine
	TaxAmount      int
	DiscountAmount int
	TotalAmount    int
	CreatedAt      time.Time
	UpdatedAt      time.Time
	CartPayload    []byte
	StoreID        int
}

func (r *Repository) ListChargeDefinitions(ctx context.Context, countryID string, store Store, fulfillment string) ([]ChargeDefinition, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT code, name, scope, calculation_type, amount, taxable, tax_inclusive,
		       waiver_min_subtotal, waiver_reason
		FROM checkout_charge_definitions
		WHERE is_active = true
		  AND (country_id IS NULL OR country_id = ?)
		  AND (zone_id IS NULL OR zone_id = ?)
		  AND (brand_id IS NULL OR brand_id = ?)
		  AND (fulfillment_type IS NULL OR fulfillment_type = ?)
		  AND NOW() BETWEEN starts_at AND COALESCE(expires_at, '9999-12-31 23:59:59')
		ORDER BY
		  CASE WHEN country_id IS NULL THEN 0 ELSE 1 END DESC,
		  CASE WHEN zone_id IS NULL THEN 0 ELSE 1 END DESC,
		  CASE WHEN brand_id IS NULL THEN 0 ELSE 1 END DESC,
		  CASE WHEN fulfillment_type IS NULL THEN 0 ELSE 1 END DESC,
		  display_order ASC,
		  id ASC
	`, countryID, store.ZoneID, store.BrandID, fulfillment)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	seen := map[string]bool{}
	definitions := []ChargeDefinition{}
	for rows.Next() {
		var definition ChargeDefinition
		if err := rows.Scan(
			&definition.Code,
			&definition.Name,
			&definition.Scope,
			&definition.CalculationType,
			&definition.Amount,
			&definition.Taxable,
			&definition.TaxInclusive,
			&definition.WaiverMinSubtotal,
			&definition.WaiverReason,
		); err != nil {
			return nil, err
		}
		if seen[definition.Code] {
			continue
		}
		seen[definition.Code] = true
		definitions = append(definitions, definition)
	}
	return definitions, rows.Err()
}

func (r *Repository) GetCountry(ctx context.Context, countryID string) (Country, error) {
	var country Country
	err := r.db.QueryRowContext(ctx, `
		SELECT id, tax_rate, currency_code
		FROM countries
		WHERE id = ? AND is_active = true
	`, countryID).Scan(&country.ID, &country.TaxRate, &country.Currency)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Country{}, ErrNotFound
		}
		return Country{}, err
	}
	return country, nil
}

func (r *Repository) GetStore(ctx context.Context, countryID string, storeID int) (Store, error) {
	var store Store
	err := r.db.QueryRowContext(ctx, `
		SELECT id, country_id, zone_id, brand_id, operational_status
		FROM stores
		WHERE id = ? AND country_id = ? AND is_active = true
	`, storeID, countryID).Scan(&store.ID, &store.CountryID, &store.ZoneID, &store.BrandID, &store.OperationalStatus)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Store{}, ErrNotFound
		}
		return Store{}, err
	}
	return store, nil
}

func (r *Repository) UpsertUser(ctx context.Context, userID, countryID string) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO users (id, registered_country_id)
		VALUES (?, ?)
		ON DUPLICATE KEY UPDATE registered_country_id = COALESCE(registered_country_id, VALUES(registered_country_id))
	`, userID, countryID)
	return err
}

func (r *Repository) GetPricedItems(ctx context.Context, storeID int, zoneID string, itemIDs []int) (map[int]PricedItem, error) {
	if len(itemIDs) == 0 {
		return map[int]PricedItem{}, nil
	}
	query, args := inQuery(`
		SELECT mi.id, mi.category_id, mip.base_price, mip.tax_inclusive, mi.brand_id, COALESCE(mi.is_promo, false)
		FROM menu_items mi
		INNER JOIN menu_item_pricing mip ON mip.menu_item_id = mi.id AND mip.zone_id = ?
		LEFT JOIN store_menu_item_status smis ON smis.store_id = ? AND smis.menu_item_id = mi.id
		LEFT JOIN stores s ON s.id = ?
		WHERE mi.id IN (%s)
		  AND mi.item_type = 'MAIN'
		  AND mi.is_active = true
		  AND mi.deleted_at IS NULL
		  AND mi.brand_id = s.brand_id
		  AND COALESCE(smis.is_listed, true) = true
		  AND COALESCE(smis.is_available, true) = true
	`, itemIDs)
	args = append([]any{zoneID, storeID, storeID}, args...)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := map[int]PricedItem{}
	for rows.Next() {
		var item PricedItem
		if err := rows.Scan(&item.MenuItemID, &item.CategoryID, &item.BasePrice, &item.TaxInclusive, &item.BrandID, &item.IsPromoItem); err != nil {
			return nil, err
		}
		items[item.MenuItemID] = item
	}
	return items, rows.Err()
}

func (r *Repository) GetOptionPrices(ctx context.Context, storeID int, zoneID string, optionIDs []int) (map[int]OptionPrice, error) {
	if len(optionIDs) == 0 {
		return map[int]OptionPrice{}, nil
	}
	query, args := inQuery(`
		SELECT co.id, cg.menu_item_id, cg.id, co.price_adjustment + COALESCE(mip.base_price, 0),
		       COALESCE(mip.tax_inclusive, true)
		FROM customization_options co
		INNER JOIN customization_groups cg ON cg.id = co.group_id
		LEFT JOIN stores s ON s.id = ?
		LEFT JOIN menu_items linked ON linked.id = co.linked_menu_item_id
		     AND linked.is_active = true
		     AND linked.deleted_at IS NULL
		     AND linked.item_type = 'ADDON'
		     AND linked.brand_id = s.brand_id
		LEFT JOIN menu_item_pricing mip ON mip.menu_item_id = co.linked_menu_item_id AND mip.zone_id = ?
		LEFT JOIN store_menu_item_status smis ON smis.store_id = ? AND smis.menu_item_id = co.linked_menu_item_id
		WHERE co.id IN (%s)
		  AND (
		    co.linked_menu_item_id IS NULL
		    OR (
		      linked.id IS NOT NULL
		      AND COALESCE(smis.is_listed, true) = true
		      AND COALESCE(smis.is_available, true) = true
		    )
		  )
	`, optionIDs)
	args = append([]any{storeID, zoneID, storeID}, args...)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	options := map[int]OptionPrice{}
	for rows.Next() {
		var option OptionPrice
		if err := rows.Scan(&option.ID, &option.MenuItemID, &option.GroupID, &option.PriceAdjustment, &option.TaxInclusive); err != nil {
			return nil, err
		}
		options[option.ID] = option
	}
	return options, rows.Err()
}

func (r *Repository) GetCustomizationRules(ctx context.Context, menuItemIDs []int) ([]CustomizationGroupRule, map[int]CustomizationOptionRule, error) {
	if len(menuItemIDs) == 0 {
		return nil, map[int]CustomizationOptionRule{}, nil
	}
	groupQuery, groupArgs := inQuery(`
		SELECT id, menu_item_id, selection_type, min_selections, is_required, max_selections
		FROM customization_groups
		WHERE menu_item_id IN (%s)
	`, menuItemIDs)

	groupRows, err := r.db.QueryContext(ctx, groupQuery, groupArgs...)
	if err != nil {
		return nil, nil, err
	}
	defer groupRows.Close()

	var groups []CustomizationGroupRule
	var groupIDs []int
	for groupRows.Next() {
		var group CustomizationGroupRule
		if err := groupRows.Scan(&group.ID, &group.MenuItemID, &group.SelectionType, &group.MinSelections, &group.IsRequired, &group.MaxSelections); err != nil {
			return nil, nil, err
		}
		groups = append(groups, group)
		groupIDs = append(groupIDs, group.ID)
	}
	if err := groupRows.Err(); err != nil {
		return nil, nil, err
	}
	if len(groupIDs) == 0 {
		return groups, map[int]CustomizationOptionRule{}, nil
	}

	optionQuery, optionArgs := inQuery(`
		SELECT co.id, co.group_id, cg.menu_item_id
		FROM customization_options co
		INNER JOIN customization_groups cg ON cg.id = co.group_id
		WHERE co.group_id IN (%s)
	`, groupIDs)
	optionRows, err := r.db.QueryContext(ctx, optionQuery, optionArgs...)
	if err != nil {
		return nil, nil, err
	}
	defer optionRows.Close()

	options := map[int]CustomizationOptionRule{}
	for optionRows.Next() {
		var option CustomizationOptionRule
		if err := optionRows.Scan(&option.ID, &option.GroupID, &option.MenuItemID); err != nil {
			return nil, nil, err
		}
		options[option.ID] = option
	}
	return groups, options, optionRows.Err()
}

func (r *Repository) GetVoucher(ctx context.Context, countryID, userID, code string) (Voucher, error) {
	var voucher Voucher
	var applicableStoreIDs, applicableCategoryIDs, applicableItemIDs, applicablePaymentMethods []byte
	err := r.db.QueryRowContext(ctx, `
		SELECT v.code, v.zone_id, v.brand_id, v.discount_type, v.discount_value, v.min_spend,
		       v.max_discount_cap, v.max_redemptions, v.max_redemptions_per_user,
		       v.allow_promo_items, COALESCE(v.applicable_store_ids, JSON_ARRAY()),
		       COALESCE(v.applicable_category_ids, JSON_ARRAY()),
		       COALESCE(v.applicable_item_ids, JSON_ARRAY()),
		       COALESCE(v.applicable_payment_methods, JSON_ARRAY()),
		       uv.status,
		       (
		         SELECT COUNT(*)
		         FROM order_intents oi
		         WHERE oi.country_id = v.country_id AND oi.voucher_code = v.code
		           AND oi.status IN ('QUEUED', 'PROCESSING', 'READY_TO_COLLECT', 'COMPLETED')
		       ) AS total_redemptions,
		       (
		         SELECT COUNT(*)
		         FROM order_intents user_oi
		         WHERE user_oi.country_id = v.country_id AND user_oi.voucher_code = v.code
		           AND user_oi.user_id = ? AND user_oi.status IN ('QUEUED', 'PROCESSING', 'READY_TO_COLLECT', 'COMPLETED')
		       ) AS user_redemptions
		FROM vouchers v
		LEFT JOIN user_vouchers uv ON uv.voucher_id = v.id AND uv.user_id = ?
		WHERE v.country_id = ? AND v.code = ? AND v.is_active = true
		  AND v.voided_at IS NULL
		  AND NOW() BETWEEN v.starts_at AND v.expires_at
	`, userID, userID, countryID, code).Scan(
		&voucher.Code, &voucher.ZoneID, &voucher.BrandID, &voucher.DiscountType,
		&voucher.DiscountValue, &voucher.MinSpend, &voucher.MaxDiscountCap,
		&voucher.MaxRedemptions, &voucher.MaxRedemptionsPerUser, &voucher.AllowPromoItems,
		&applicableStoreIDs, &applicableCategoryIDs, &applicableItemIDs,
		&applicablePaymentMethods, &voucher.UserVoucherStatus,
		&voucher.TotalRedemptions, &voucher.UserRedemptions,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Voucher{}, ErrNotFound
		}
		return Voucher{}, err
	}
	voucher.ApplicableStoreIDs = decodeIntList(applicableStoreIDs)
	voucher.ApplicableCategoryIDs = decodeIntList(applicableCategoryIDs)
	voucher.ApplicableItemIDs = decodeIntList(applicableItemIDs)
	voucher.ApplicablePaymentMethods = decodeStringList(applicablePaymentMethods)
	return voucher, nil
}

type IntentWithPayment struct {
	Intent  Intent
	Payment PaymentTransaction
}

func (r *Repository) FindIntentByIdempotency(ctx context.Context, countryID, userID, key string) (IntentWithPayment, error) {
	var intent Intent
	var payment PaymentTransaction
	var voucher sql.NullString
	var chargesPayload []byte
	var paymentID, paymentProvider, paymentMethodCode, paymentStatus, currencyCode sql.NullString
	var paymentAmount sql.NullInt64
	err := r.db.QueryRowContext(ctx, `
		SELECT oi.tracking_id, oi.trace_id, oi.idempotency_key, oi.user_id, oi.store_id, oi.country_id, oi.fulfillment_type,
		       oi.status, oi.subtotal, COALESCE(oi.charges_payload, JSON_ARRAY()), oi.tax_amount, oi.discount_amount,
		       oi.total_amount, oi.voucher_code, oi.cart_payload,
		       pt.id, pt.provider, pt.payment_method_code, pt.status, pt.currency_code, pt.amount
		FROM order_intents oi
		LEFT JOIN payment_transactions pt ON pt.order_tracking_id = oi.tracking_id
		WHERE oi.country_id = ? AND oi.user_id = ? AND oi.idempotency_key = ?
	`, countryID, userID, key).Scan(&intent.TrackingID, &intent.TraceID, &intent.IdempotencyKey, &intent.UserID, &intent.StoreID, &intent.CountryID, &intent.Fulfillment, &intent.Status, &intent.Subtotal, &chargesPayload, &intent.TaxAmount, &intent.DiscountAmount, &intent.TotalAmount, &voucher, &intent.CartPayload, &paymentID, &paymentProvider, &paymentMethodCode, &paymentStatus, &currencyCode, &paymentAmount)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return IntentWithPayment{}, ErrNotFound
		}
		return IntentWithPayment{}, err
	}
	intent.VoucherCode = voucher.String
	intent.ChargesPayload = chargesPayload
	intent.Charges = decodeChargeLines(chargesPayload)
	if paymentID.Valid {
		payment.ID = paymentID.String
		payment.OrderTrackingID = intent.TrackingID
		payment.CountryID = intent.CountryID
		payment.UserID = intent.UserID
		payment.Provider = paymentProvider.String
		payment.MethodCode = paymentMethodCode.String
		payment.Status = paymentStatus.String
		payment.CurrencyCode = currencyCode.String
		payment.Amount = int(paymentAmount.Int64)
	}
	return IntentWithPayment{Intent: intent, Payment: payment}, nil
}

func (r *Repository) CreateIntent(ctx context.Context, intent Intent) error {
	if !json.Valid(intent.CartPayload) {
		return errors.New("cart payload must be valid json")
	}
	chargesPayload, err := encodeChargeLines(intent.Charges)
	if err != nil {
		return err
	}
	var voucher any
	if intent.VoucherCode != "" {
		voucher = intent.VoucherCode
	}
	_, err = r.db.ExecContext(ctx, `
		INSERT INTO order_intents (
			tracking_id, trace_id, idempotency_key, user_id, store_id, country_id,
			fulfillment_type, status, subtotal, charges_payload, tax_amount, discount_amount,
			total_amount, voucher_code, cart_payload
		)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CAST(? AS JSON), ?, ?, ?, ?, CAST(? AS JSON))
	`, intent.TrackingID, intent.TraceID, intent.IdempotencyKey, intent.UserID, intent.StoreID, intent.CountryID, intent.Fulfillment, intent.Status, intent.Subtotal, string(chargesPayload), intent.TaxAmount, intent.DiscountAmount, intent.TotalAmount, voucher, string(intent.CartPayload))
	return err
}

func (r *Repository) CreateIntentWithPayment(ctx context.Context, intent Intent, payment PaymentTransaction) error {
	if !json.Valid(intent.CartPayload) {
		return errors.New("cart payload must be valid json")
	}
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := insertIntent(ctx, tx, intent); err != nil {
		return err
	}
	if err := insertPayment(ctx, tx, payment); err != nil {
		return err
	}
	return tx.Commit()
}

func (r *Repository) CreatePaymentIfMissing(ctx context.Context, payment PaymentTransaction) (PaymentTransaction, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return PaymentTransaction{}, err
	}
	defer tx.Rollback()

	existing, err := selectPaymentByOrderTx(ctx, tx, payment.OrderTrackingID)
	if err == nil {
		return existing, tx.Commit()
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return PaymentTransaction{}, err
	}
	if err := insertPayment(ctx, tx, payment); err != nil {
		existing, findErr := selectPaymentByOrderTx(ctx, tx, payment.OrderTrackingID)
		if findErr == nil {
			return existing, tx.Commit()
		}
		return PaymentTransaction{}, err
	}
	return payment, tx.Commit()
}

func selectPaymentByOrderTx(ctx context.Context, tx *sql.Tx, orderTrackingID string) (PaymentTransaction, error) {
	var payment PaymentTransaction
	err := tx.QueryRowContext(ctx, `
		SELECT id, order_tracking_id, country_id, user_id, provider, payment_method_code, status, currency_code, amount
		FROM payment_transactions
		WHERE order_tracking_id = ?
		LIMIT 1
		FOR UPDATE
	`, orderTrackingID).Scan(&payment.ID, &payment.OrderTrackingID, &payment.CountryID, &payment.UserID, &payment.Provider, &payment.MethodCode, &payment.Status, &payment.CurrencyCode, &payment.Amount)
	return payment, err
}

type txExecutor interface {
	ExecContext(context.Context, string, ...any) (sql.Result, error)
}

func insertIntent(ctx context.Context, exec txExecutor, intent Intent) error {
	chargesPayload, err := encodeChargeLines(intent.Charges)
	if err != nil {
		return err
	}
	var voucher any
	if intent.VoucherCode != "" {
		voucher = intent.VoucherCode
	}
	_, err = exec.ExecContext(ctx, `
		INSERT INTO order_intents (
			tracking_id, trace_id, idempotency_key, user_id, store_id, country_id,
			fulfillment_type, status, subtotal, charges_payload, tax_amount, discount_amount,
			total_amount, voucher_code, cart_payload
		)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CAST(? AS JSON), ?, ?, ?, ?, CAST(? AS JSON))
	`, intent.TrackingID, intent.TraceID, intent.IdempotencyKey, intent.UserID, intent.StoreID, intent.CountryID, intent.Fulfillment, intent.Status, intent.Subtotal, string(chargesPayload), intent.TaxAmount, intent.DiscountAmount, intent.TotalAmount, voucher, string(intent.CartPayload))
	return err
}

func insertPayment(ctx context.Context, exec txExecutor, payment PaymentTransaction) error {
	_, err := exec.ExecContext(ctx, `
		INSERT INTO payment_transactions (
			id, order_tracking_id, country_id, user_id, provider, payment_method_code, status, currency_code, amount
		)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
	`, payment.ID, payment.OrderTrackingID, payment.CountryID, payment.UserID, payment.Provider, payment.MethodCode, payment.Status, payment.CurrencyCode, payment.Amount)
	return err
}

func (r *Repository) GetStatus(ctx context.Context, countryID, trackingID string) (Status, error) {
	var status Status
	var chargesPayload []byte
	err := r.db.QueryRowContext(ctx, `
		SELECT oi.tracking_id, oi.status, pt.status, oi.subtotal, oi.tax_amount,
		       oi.discount_amount, oi.total_amount, COALESCE(oi.charges_payload, JSON_ARRAY()),
		       oi.created_at, oi.updated_at, oi.cart_payload, oi.store_id
		FROM order_intents oi
		LEFT JOIN payment_transactions pt ON pt.order_tracking_id = oi.tracking_id
		WHERE oi.country_id = ? AND oi.tracking_id = ?
	`, countryID, trackingID).Scan(&status.TrackingID, &status.Status, &status.PaymentStatus, &status.Subtotal, &status.TaxAmount, &status.DiscountAmount, &status.TotalAmount, &chargesPayload, &status.CreatedAt, &status.UpdatedAt, &status.CartPayload, &status.StoreID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Status{}, ErrNotFound
		}
		return Status{}, err
	}
	status.Charges = decodeChargeLines(chargesPayload)
	return status, nil
}

func (r *Repository) GetStatusForUser(ctx context.Context, countryID, userID, trackingID string) (Status, error) {
	var status Status
	var chargesPayload []byte
	err := r.db.QueryRowContext(ctx, `
		SELECT oi.tracking_id, oi.status, pt.status, oi.subtotal, oi.tax_amount,
		       oi.discount_amount, oi.total_amount, COALESCE(oi.charges_payload, JSON_ARRAY()),
		       oi.created_at, oi.updated_at, oi.cart_payload, oi.store_id, pt.id
		FROM order_intents oi
		LEFT JOIN payment_transactions pt ON pt.order_tracking_id = oi.tracking_id
		WHERE oi.country_id = ? AND oi.user_id = ? AND oi.tracking_id = ?
	`, countryID, userID, trackingID).Scan(&status.TrackingID, &status.Status, &status.PaymentStatus, &status.Subtotal, &status.TaxAmount, &status.DiscountAmount, &status.TotalAmount, &chargesPayload, &status.CreatedAt, &status.UpdatedAt, &status.CartPayload, &status.StoreID, &status.TransactionID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Status{}, ErrNotFound
		}
		return Status{}, err
	}
	status.Charges = decodeChargeLines(chargesPayload)
	return status, nil
}

func (r *Repository) ListStatusesByUser(ctx context.Context, countryID, userID string, statuses []string, limit, offset int) ([]Status, error) {
	statusClause := ""
	args := []any{countryID, userID}
	if len(statuses) > 0 {
		placeholders := strings.TrimRight(strings.Repeat("?,", len(statuses)), ",")
		statusClause = " AND oi.status IN (" + placeholders + ")"
		for _, status := range statuses {
			args = append(args, status)
		}
	}
	args = append(args, limit, offset)

	rows, err := r.db.QueryContext(ctx, `
		SELECT oi.tracking_id, oi.status, pt.status, oi.subtotal, oi.tax_amount,
		       oi.discount_amount, oi.total_amount, COALESCE(oi.charges_payload, JSON_ARRAY()),
		       oi.created_at, oi.updated_at, oi.cart_payload, oi.store_id, pt.id
		FROM order_intents oi
		LEFT JOIN payment_transactions pt ON pt.order_tracking_id = oi.tracking_id
		WHERE oi.country_id = ? AND oi.user_id = ?`+statusClause+`
		ORDER BY oi.created_at DESC
		LIMIT ? OFFSET ?
	`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	rowsStatuses := []Status{}
	for rows.Next() {
		var status Status
		var chargesPayload []byte
		if err := rows.Scan(&status.TrackingID, &status.Status, &status.PaymentStatus, &status.Subtotal, &status.TaxAmount, &status.DiscountAmount, &status.TotalAmount, &chargesPayload, &status.CreatedAt, &status.UpdatedAt, &status.CartPayload, &status.StoreID, &status.TransactionID); err != nil {
			return nil, err
		}
		status.Charges = decodeChargeLines(chargesPayload)
		rowsStatuses = append(rowsStatuses, status)
	}
	return rowsStatuses, rows.Err()
}

func (r *Repository) MarkOrderCollected(ctx context.Context, countryID, userID, trackingID string) error {
	result, err := r.db.ExecContext(ctx, `
		UPDATE order_intents
		SET status = 'COMPLETED', updated_at = NOW()
		WHERE country_id = ? AND user_id = ? AND tracking_id = ? AND status = 'READY_TO_COLLECT'
	`, countryID, userID, trackingID)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repository) GetMenuItemNames(ctx context.Context, itemIDs []int) (map[int]string, error) {
	if len(itemIDs) == 0 {
		return map[int]string{}, nil
	}
	query, args := inQuery(`
		SELECT id, name_translations
		FROM menu_items
		WHERE id IN (%s)
	`, itemIDs)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	names := map[int]string{}
	for rows.Next() {
		var id int
		var nameBytes []byte
		if err := rows.Scan(&id, &nameBytes); err != nil {
			return nil, err
		}
		translations := map[string]string{}
		if err := json.Unmarshal(nameBytes, &translations); err == nil {
			if name, ok := translations["en-US"]; ok {
				names[id] = name
			} else {
				for _, v := range translations {
					names[id] = v
					break
				}
			}
		}
	}
	return names, rows.Err()
}

func (r *Repository) GetOptionNames(ctx context.Context, optionIDs []int) (map[int]string, error) {
	if len(optionIDs) == 0 {
		return map[int]string{}, nil
	}
	query, args := inQuery(`
		SELECT id, name_translations
		FROM customization_options
		WHERE id IN (%s)
	`, optionIDs)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	names := map[int]string{}
	for rows.Next() {
		var id int
		var nameBytes []byte
		if err := rows.Scan(&id, &nameBytes); err != nil {
			return nil, err
		}
		translations := map[string]string{}
		if err := json.Unmarshal(nameBytes, &translations); err == nil {
			if name, ok := translations["en-US"]; ok {
				names[id] = name
			} else {
				for _, v := range translations {
					names[id] = v
					break
				}
			}
		}
	}
	return names, rows.Err()
}

var ErrNotFound = errors.New("not found")

func inQuery(format string, ids []int) (string, []any) {
	placeholders := ""
	args := make([]any, len(ids))
	for i, id := range ids {
		if i > 0 {
			placeholders += ","
		}
		placeholders += "?"
		args[i] = id
	}
	return sprintf(format, placeholders), args
}

func sprintf(format, value string) string {
	for i := 0; i < len(format)-1; i++ {
		if format[i] == '%' && format[i+1] == 's' {
			return format[:i] + value + format[i+2:]
		}
	}
	return format
}

func decodeIntList(raw []byte) []int {
	if len(raw) == 0 {
		return nil
	}
	var values []int
	if err := json.Unmarshal(raw, &values); err == nil {
		return values
	}
	return nil
}

func decodeStringList(raw []byte) []string {
	if len(raw) == 0 {
		return nil
	}
	var values []string
	if err := json.Unmarshal(raw, &values); err == nil {
		return values
	}
	return nil
}

func encodeChargeLines(charges []ChargeLine) ([]byte, error) {
	if charges == nil {
		charges = []ChargeLine{}
	}
	return json.Marshal(charges)
}

func decodeChargeLines(raw []byte) []ChargeLine {
	if len(raw) == 0 {
		return []ChargeLine{}
	}
	var values []ChargeLine
	if err := json.Unmarshal(raw, &values); err == nil {
		return values
	}
	return []ChargeLine{}
}
