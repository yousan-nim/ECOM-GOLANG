// Package httpx holds small HTTP helpers shared across services:
// a consistent JSON error envelope and a health endpoint.
package httpx

import (
	"context"
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
)

// Error is the standard error envelope returned to clients.
type Error struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// Fail writes a JSON error envelope with the given status.
func Fail(c *gin.Context, status int, code, msg string) {
	c.JSON(status, gin.H{"error": Error{Code: code, Message: msg}})
}

// ReadyCheck is one optional dependency probed by /readyz (e.g. Redis).
// Name appears in the failure envelope; Ping should be cheap and context-aware.
type ReadyCheck struct {
	Name string
	Ping func(context.Context) error
}

// Health registers liveness (/healthz) and readiness (/readyz) endpoints.
//
// Liveness is a pure process check (am I up?) used to decide restarts.
// Readiness pings the database — plus any extra checks — so the load balancer
// only routes traffic when the service can actually serve. Keep extra checks to
// dependencies the service cannot function without; a degraded but optional
// dependency (like a best-effort cache) should NOT fail readiness.
func Health(r gin.IRouter, service string, sqlDB *sql.DB, extra ...ReadyCheck) {
	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"service": service, "status": "ok"})
	})
	r.GET("/readyz", func(c *gin.Context) {
		ctx := c.Request.Context()
		if err := sqlDB.PingContext(ctx); err != nil {
			Fail(c, http.StatusServiceUnavailable, "db_unavailable", err.Error())
			return
		}
		for _, chk := range extra {
			if chk.Ping == nil {
				continue
			}
			if err := chk.Ping(ctx); err != nil {
				Fail(c, http.StatusServiceUnavailable, chk.Name+"_unavailable", err.Error())
				return
			}
		}
		c.JSON(http.StatusOK, gin.H{"service": service, "status": "ready"})
	})
}
