package queue

import (
	"context"
	"log"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
)

var SQSClient *sqs.Client

// InitSQS initializes the AWS SQS client.
func InitSQS() {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Printf("Failed to load AWS config for SQS (mocking fallback): %v", err)
		// For local development without AWS credentials, we might not want to panic immediately
		// but log it so the developer knows SQS isn't fully wired up.
		return
	}

	SQSClient = sqs.NewFromConfig(cfg)
	log.Println("Successfully initialized AWS SQS Client")
}
