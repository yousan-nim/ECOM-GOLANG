// Command media-service is the entry point (composition root) for the
// media microservice: load config → open DB → run migrations → serve HTTP.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	media "github.com/yousan-nim/ecom/services/media"

	"github.com/yousan-nim/ecom/pkg/cache"
	"github.com/yousan-nim/ecom/pkg/config"
	"github.com/yousan-nim/ecom/pkg/db"
	"github.com/yousan-nim/ecom/pkg/httpx"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg := config.Load("media")

	gdb, sqlDB, err := db.Open(cfg.DB.DSN())
	if err != nil {
		log.Error("db open failed", "err", err)
		os.Exit(1)
	}
	defer sqlDB.Close()

	if err := db.Migrate(sqlDB, media.MigrationsFS); err != nil {
		log.Error("migrate failed", "err", err)
		os.Exit(1)
	}
	log.Info("migrations applied")

	// Cache is optional: an empty REDIS_ADDR disables it, and an unreachable
	// Redis degrades to no-cache rather than failing the service (Redis is a
	// performance layer, never required for correctness).
	cacheCtx, cacheCancel := context.WithTimeout(context.Background(), 5*time.Second)
	rc, err := cache.Open(cacheCtx, cache.Config(cfg.Redis), cfg.ServiceName)
	cacheCancel()
	switch {
	case err != nil:
		log.Warn("cache unavailable — running without cache", "err", err)
	case rc.Enabled():
		log.Info("cache connected", "addr", cfg.Redis.Addr)
	default:
		log.Info("cache disabled (no REDIS_ADDR)")
	}
	defer rc.Close()

	_ = gdb // handed to repositories as features are added
	_ = rc  // handed to repositories/handlers as features are added

	r := gin.New()
	r.Use(gin.Recovery())
	httpx.Health(r, cfg.ServiceName, sqlDB)

	srv := &http.Server{Addr: ":" + cfg.HTTPPort, Handler: r}

	// Graceful shutdown — drain in-flight requests on SIGINT/SIGTERM.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	go func() {
		log.Info("listening", "service", cfg.ServiceName, "port", cfg.HTTPPort)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("server error", "err", err)
			stop()
		}
	}()

	<-ctx.Done()
	log.Info("shutting down")
	shutCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutCtx); err != nil {
		log.Error("shutdown error", "err", err)
	}
}
