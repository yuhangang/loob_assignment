package ordering

import (
	"context"
	"errors"
	"log"
)

type OrderRepository interface {
	ClaimQueued(ctx context.Context, limit int) ([]Intent, error)
	Complete(ctx context.Context, intent Intent) error
	Fail(ctx context.Context, intent Intent) error
}

type Service struct {
	repo OrderRepository
}

func NewService(repo OrderRepository) *Service {
	return &Service{repo: repo}
}

func (s *Service) ProcessBatch(ctx context.Context, limit int) (int, error) {
	intents, err := s.repo.ClaimQueued(ctx, limit)
	if err != nil {
		if errors.Is(err, ErrNoQueuedIntents) {
			return 0, nil
		}
		return 0, err
	}

	processed := 0
	for _, intent := range intents {
		if err := s.repo.Complete(ctx, intent); err != nil {
			log.Printf("ordering complete failed country=%s tracking_id=%s error=%v", intent.CountryID, intent.TrackingID, err)
			if failErr := s.repo.Fail(ctx, intent); failErr != nil {
				log.Printf("ordering fail mark failed country=%s tracking_id=%s error=%v", intent.CountryID, intent.TrackingID, failErr)
			}
			continue
		}
		processed++
		log.Printf("ordering completed country=%s tracking_id=%s", intent.CountryID, intent.TrackingID)
	}
	return processed, nil
}
