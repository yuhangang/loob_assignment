package timeutil

import "time"

func FormatRFC3339UTC(value time.Time) string {
	return value.UTC().Format(time.RFC3339)
}
