package ordering

import (
	"context"
	"errors"
	"testing"
)

type mockRepository struct {
	claimed   []Intent
	claimErr  error
	completed []Intent
	failed    []Intent
}

func (m *mockRepository) ClaimQueued(ctx context.Context, limit int) ([]Intent, error) {
	if m.claimErr != nil {
		return nil, m.claimErr
	}
	return m.claimed, nil
}

func (m *mockRepository) Complete(ctx context.Context, intent Intent) error {
	m.completed = append(m.completed, intent)
	return nil
}

func (m *mockRepository) Fail(ctx context.Context, intent Intent) error {
	m.failed = append(m.failed, intent)
	return nil
}

func TestProcessBatchTreatsEmptyQueueAsIdle(t *testing.T) {
	repo := &mockRepository{claimErr: ErrNoQueuedIntents}
	processed, err := NewService(repo).ProcessBatch(context.Background(), 25)
	if err != nil {
		t.Fatalf("ProcessBatch() error = %v", err)
	}
	if processed != 0 {
		t.Fatalf("processed = %d, want 0", processed)
	}
}

func TestProcessBatchCompletesClaimedIntents(t *testing.T) {
	repo := &mockRepository{
		claimed: []Intent{
			{TrackingID: "MY-1", CountryID: "MY"},
			{TrackingID: "TH-1", CountryID: "TH"},
		},
	}

	processed, err := NewService(repo).ProcessBatch(context.Background(), 25)
	if err != nil {
		t.Fatalf("ProcessBatch() error = %v", err)
	}
	if processed != 2 {
		t.Fatalf("processed = %d, want 2", processed)
	}
	if len(repo.completed) != 2 {
		t.Fatalf("completed = %d, want 2", len(repo.completed))
	}
	if len(repo.failed) != 0 {
		t.Fatalf("failed = %d, want 0", len(repo.failed))
	}
}

func TestProcessBatchReturnsClaimError(t *testing.T) {
	want := errors.New("database unavailable")
	repo := &mockRepository{claimErr: want}

	_, err := NewService(repo).ProcessBatch(context.Background(), 25)
	if !errors.Is(err, want) {
		t.Fatalf("ProcessBatch() error = %v, want %v", err, want)
	}
}
