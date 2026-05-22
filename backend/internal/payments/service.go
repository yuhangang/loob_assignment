package payments

import (
	"context"
	"crypto/subtle"
	"errors"
	"strings"

	"github.com/loob/backend/internal/platform"
	"github.com/loob/backend/internal/timeutil"
)

type PaymentRepository interface {
	ApplyCallback(ctx context.Context, update CallbackUpdate) (TransactionRow, error)
	Get(ctx context.Context, countryID, transactionID string) (TransactionRow, error)
	GetForUser(ctx context.Context, countryID, userID, transactionID string) (TransactionRow, error)
	ResolvePaymentMethod(ctx context.Context, countryID string, brandID int, methodCode string, amount int) (PaymentMethod, error)
	CreatePendingTransaction(ctx context.Context, tx PendingTransaction) (TransactionRow, error)
	ListProviders(ctx context.Context, includeInactive bool) ([]ProviderRow, error)
	ListMethods(ctx context.Context, countryID string, brandID int, includeInactive bool) ([]MethodRow, error)
}

type Service struct {
	repo              PaymentRepository
	mockGatewaySecret string
}

func NewService(repo PaymentRepository, mockGatewaySecret string) *Service {
	return &Service{repo: repo, mockGatewaySecret: mockGatewaySecret}
}

func (s *Service) AuthorizeMockGateway(secret string) bool {
	if s.mockGatewaySecret == "" {
		return false
	}
	if len(secret) != len(s.mockGatewaySecret) {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(secret), []byte(s.mockGatewaySecret)) == 1
}

func (s *Service) ApplyMockGatewayCallback(ctx context.Context, req MockGatewayCallbackRequest) (Transaction, error) {
	transactionID := strings.TrimSpace(req.TransactionID)
	if transactionID == "" {
		return Transaction{}, ErrTransactionRequired
	}

	paymentStatus, orderStatus, err := mapGatewayStatus(req.Status)
	if err != nil {
		return Transaction{}, err
	}

	payload := req.Payload
	if payload == nil {
		payload = map[string]any{}
	}
	if req.FailureReason != "" {
		payload["failure_reason"] = req.FailureReason
	}

	row, err := s.repo.ApplyCallback(ctx, CallbackUpdate{
		TransactionID:    transactionID,
		GatewayReference: strings.TrimSpace(req.GatewayReference),
		GatewayEventID:   strings.TrimSpace(req.GatewayEventID),
		PaymentStatus:    paymentStatus,
		OrderStatus:      orderStatus,
		EventType:        "mock_gateway.callback",
		Payload:          payload,
	})
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return Transaction{}, ErrTransactionNotFound
		}
		if errors.Is(err, ErrInsufficientWalletBalance) {
			return Transaction{}, ErrInsufficientWalletBalance
		}
		if errors.Is(err, ErrVoucherRedemptionLimitExceeded) {
			return Transaction{}, ErrVoucherRedemptionLimitExceeded
		}
		return Transaction{}, err
	}
	return toDomain(row), nil
}

func (s *Service) Get(ctx context.Context, countryID, transactionID string) (Transaction, error) {
	row, err := s.repo.Get(ctx, countryID, transactionID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return Transaction{}, ErrTransactionNotFound
		}
		return Transaction{}, err
	}
	return toDomain(row), nil
}

func (s *Service) GetForUser(ctx context.Context, countryID, userID, transactionID string) (Transaction, error) {
	row, err := s.repo.GetForUser(ctx, countryID, userID, transactionID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return Transaction{}, ErrTransactionNotFound
		}
		return Transaction{}, err
	}
	return toDomain(row), nil
}

func (s *Service) ValidateMethod(ctx context.Context, req StartPaymentRequest) (MethodSelection, error) {
	method, err := s.repo.ResolvePaymentMethod(ctx, req.CountryID, req.BrandID, normalizeMethod(req.MethodCode), req.Amount)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return MethodSelection{}, ErrPaymentMethodUnavailable
		}
		return MethodSelection{}, err
	}
	if method.CurrencyCode != req.CurrencyCode {
		return MethodSelection{}, ErrPaymentMethodUnavailable
	}
	return MethodSelection{
		Code:         method.Code,
		ProviderCode: method.ProviderCode,
		CurrencyCode: method.CurrencyCode,
	}, nil
}

func (s *Service) StartPayment(ctx context.Context, req StartPaymentRequest) (Transaction, error) {
	method, err := s.ValidateMethod(ctx, req)
	if err != nil {
		return Transaction{}, err
	}
	row, err := s.repo.CreatePendingTransaction(ctx, PendingTransaction{
		ID:              platform.NewPaymentID(req.CountryID),
		OrderTrackingID: req.OrderTrackingID,
		CountryID:       req.CountryID,
		UserID:          req.UserID,
		Provider:        method.ProviderCode,
		MethodCode:      method.Code,
		Status:          "PENDING",
		CurrencyCode:    method.CurrencyCode,
		Amount:          req.Amount,
	})
	if err != nil {
		return Transaction{}, err
	}
	return toDomain(row), nil
}

func (s *Service) ListProviders(ctx context.Context, includeInactive bool) ([]Provider, error) {
	rows, err := s.repo.ListProviders(ctx, includeInactive)
	if err != nil {
		return nil, err
	}
	providers := make([]Provider, 0, len(rows))
	for _, row := range rows {
		providers = append(providers, Provider{
			Code:        row.Code,
			DisplayName: row.DisplayName,
			Type:        row.Type,
			CallbackURL: row.CallbackURL,
			IsMock:      row.IsMock,
			IsActive:    row.IsActive,
			Config:      row.Config,
		})
	}
	return providers, nil
}

func (s *Service) ListMethods(ctx context.Context, countryID string, brandID int, includeInactive bool) ([]Method, error) {
	rows, err := s.repo.ListMethods(ctx, countryID, brandID, includeInactive)
	if err != nil {
		return nil, err
	}
	methods := make([]Method, 0, len(rows))
	for _, row := range rows {
		method := Method{
			ID:           row.ID,
			Code:         row.Code,
			ProviderCode: row.ProviderCode,
			CountryID:    row.CountryID,
			DisplayName:  row.DisplayName,
			Description:  row.Description,
			CurrencyCode: row.CurrencyCode,
			MinAmount:    row.MinAmount,
			DisplayOrder: row.DisplayOrder,
			Metadata:     row.Metadata,
		}
		if row.BrandID.Valid {
			brandID := int(row.BrandID.Int64)
			method.BrandID = &brandID
		}
		if row.MaxAmount.Valid {
			maxAmount := int(row.MaxAmount.Int64)
			method.MaxAmount = &maxAmount
		}
		methods = append(methods, method)
	}
	return methods, nil
}

func mapGatewayStatus(status string) (paymentStatus string, orderStatus string, err error) {
	switch strings.ToUpper(strings.TrimSpace(status)) {
	case "SUCCESS", "SUCCEEDED", "CAPTURED", "PAID":
		return "CAPTURED", "READY_TO_COLLECT", nil
	case "AUTHORIZED":
		return "AUTHORIZED", "PAYMENT_PENDING", nil
	case "FAILED", "DECLINED":
		return "FAILED", "PAYMENT_FAILED", nil
	case "CANCELLED", "CANCELED":
		return "CANCELLED", "PAYMENT_FAILED", nil
	default:
		return "", "", ErrUnsupportedStatus
	}
}

func normalizeMethod(method string) string {
	method = strings.ToUpper(strings.TrimSpace(method))
	switch method {
	case "WALLET":
		return "EWALLET"
	case "BANK", "ONLINE_BANKING":
		return "FPX"
	default:
		return method
	}
}

func toDomain(row TransactionRow) Transaction {
	return Transaction{
		ID:                row.ID,
		OrderTrackingID:   row.OrderTrackingID,
		Provider:          row.Provider,
		MethodCode:        row.MethodCode.String,
		ProviderReference: row.ProviderReference.String,
		Status:            row.Status,
		OrderStatus:       row.OrderStatus,
		CurrencyCode:      row.CurrencyCode,
		Amount:            row.Amount,
		UpdatedAt:         timeutil.FormatRFC3339UTC(row.UpdatedAt),
	}
}

var (
	ErrTransactionRequired      = errors.New("transaction_id is required")
	ErrUnsupportedStatus        = errors.New("unsupported payment status")
	ErrTransactionNotFound      = errors.New("payment transaction not found")
	ErrPaymentMethodUnavailable = errors.New("payment method unavailable")
)
