// Command catalog-service is the entry point (composition root) for the
// catalog microservice: load config → open DB → run migrations → serve HTTP.
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

	catalog "github.com/bpstech/ecom/services/catalog"

	"github.com/bpstech/ecom/pkg/config"
	"github.com/bpstech/ecom/pkg/db"
	"github.com/bpstech/ecom/pkg/httpx"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg := config.Load("catalog")

	gdb, sqlDB, err := db.Open(cfg.DB.DSN())
	if err != nil {
		log.Error("db open failed", "err", err)
		os.Exit(1)
	}
	defer sqlDB.Close()

	if err := db.Migrate(sqlDB, catalog.MigrationsFS); err != nil {
		log.Error("migrate failed", "err", err)
		os.Exit(1)
	}
	log.Info("migrations applied")
	_ = gdb // handed to repositories as features are added

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
