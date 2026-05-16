package platform

import (
	"os"
	"strconv"
	"strings"
)

type Config struct {
	HTTPAddr          string
	DatabaseDSN       string
	MigrationsDir     string
	AutoMigrate       bool
	PublicBaseURL     string
	MockGatewaySecret string
}

func Load() Config {
	return Config{
		HTTPAddr:          getEnv("HTTP_ADDR", ":8080"),
		DatabaseDSN:       databaseDSN(),
		MigrationsDir:     getEnv("MIGRATIONS_DIR", "sql/migrations"),
		AutoMigrate:       getBoolEnv("AUTO_MIGRATE", true),
		PublicBaseURL:     strings.TrimRight(getEnv("PUBLIC_BASE_URL", "http://localhost:8080"), "/"),
		MockGatewaySecret: os.Getenv("MOCK_GATEWAY_SECRET"),
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
