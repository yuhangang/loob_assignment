package platform

import (
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	HTTPAddr           string
	DatabaseDSN        string
	MigrationsDir      string
	AutoMigrate        bool
	PublicBaseURL      string
	MockGatewaySecret  string
	FirebaseProjectID  string
	AuthMode           string
	WorkerPollInterval time.Duration
	WorkerBatchSize    int
}

func Load() Config {
	firebaseProjectID := strings.TrimSpace(os.Getenv("FIREBASE_PROJECT_ID"))
	return Config{
		HTTPAddr:           getEnv("HTTP_ADDR", ":8080"),
		DatabaseDSN:        databaseDSN(),
		MigrationsDir:      getEnv("MIGRATIONS_DIR", "sql/migrations"),
		AutoMigrate:        getBoolEnv("AUTO_MIGRATE", true),
		PublicBaseURL:      strings.TrimRight(getEnv("PUBLIC_BASE_URL", "http://localhost:8080"), "/"),
		MockGatewaySecret:  getEnv("MOCK_GATEWAY_SECRET", "change-me-local-only"),
		FirebaseProjectID:  firebaseProjectID,
		AuthMode:           authMode(firebaseProjectID),
		WorkerPollInterval: getDurationEnv("WORKER_POLL_INTERVAL", 2*time.Second),
		WorkerBatchSize:    getIntEnv("WORKER_BATCH_SIZE", 25),
	}
}

func authMode(firebaseProjectID string) string {
	mode := strings.ToLower(strings.TrimSpace(os.Getenv("AUTH_MODE")))
	switch mode {
	case "firebase", "mock":
		return mode
	case "":
		if strings.TrimSpace(firebaseProjectID) != "" {
			return "firebase"
		}
		return "mock"
	default:
		return "firebase"
	}
}

func databaseDSN() string {
	if dsn := os.Getenv("DATABASE_DSN"); dsn != "" {
		return dsn
	}

	user := getEnv("DB_USER", "root")
	pass := getEnv("DB_PASSWORD", "password")
	host := getEnv("DB_HOST", "127.0.0.1")
	port := getEnv("DB_PORT", "3306")
	name := getEnv("DB_NAME", "loob_unified")

	return user + ":" + pass + "@tcp(" + host + ":" + port + ")/" + name + "?charset=utf8mb4&parseTime=True&loc=Local&multiStatements=true"
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func getBoolEnv(key string, fallback bool) bool {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func getIntEnv(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed <= 0 {
		return fallback
	}
	return parsed
}

func getDurationEnv(key string, fallback time.Duration) time.Duration {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	parsed, err := time.ParseDuration(value)
	if err != nil || parsed <= 0 {
		return fallback
	}
	return parsed
}
