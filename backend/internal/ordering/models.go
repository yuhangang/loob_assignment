package ordering

import "errors"

type Intent struct {
	TrackingID string
	CountryID  string
}

var ErrNoQueuedIntents = errors.New("no queued order intents")
