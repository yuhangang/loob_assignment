package queue

import (
	"os"
	"testing"
)

func TestInitSQS(t *testing.T) {
	// Forcing some AWS env vars to ensure LoadDefaultConfig doesn't hang or fail in certain CI environments
	// but mostly we just want to ensure it doesn't panic.
	os.Setenv("AWS_REGION", "us-east-1")
	defer os.Unsetenv("AWS_REGION")

	// We can't easily mock the AWS SDK config loader behavior without more complex wrapping,
	// but we can ensure the function runs and behaves predictably.
	InitSQS()
	
	// Since we are in a test environment, SQSClient might be nil if config load failed
	// or non-nil if it used defaults. Either way, we just want to ensure coverage and no panic.
}
