package main

import (
	"context"
	"log"
	"time"

	"github.com/loob/backend/internal/database"
	"github.com/loob/backend/internal/ordering"
	"github.com/loob/backend/internal/platform"
)

func main() {
	cfg := platform.Load()

	db, err := database.Open(cfg.DatabaseDSN)
	if err != nil {
		log.Fatalf("open database: %v", err)
	}
	defer db.Close()

	if cfg.AutoMigrate {
		if err := database.RunMigrations(db, cfg.MigrationsDir); err != nil {
			log.Fatalf("run migrations: %v", err)
		}
		log.Printf("database migrations applied from %s", cfg.MigrationsDir)
	}

	service := ordering.NewService(ordering.NewRepository(db))
	ticker := time.NewTicker(cfg.WorkerPollInterval)
	defer ticker.Stop()

	log.Printf("starting Loob ordering worker poll_interval=%s batch_size=%d", cfg.WorkerPollInterval, cfg.WorkerBatchSize)
	for {
		processed, err := service.ProcessBatch(context.Background(), cfg.WorkerBatchSize)
		if err != nil {
			log.Printf("ordering worker batch failed error=%v", err)
		} else if processed > 0 {
			log.Printf("ordering worker processed=%d", processed)
		}
		<-ticker.C
	}
}
