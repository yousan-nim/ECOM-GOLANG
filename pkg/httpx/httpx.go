// Package httpx holds small HTTP helpers shared across services:
// a consistent JSON error envelope and a health endpoint.
package httpx

import (
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

// Health registers liveness (/healthz) and readiness (/readyz) endpoints.
// Readiness pings the database so orchestrators only route traffic when the
// service can actually serve.
func Health(r gin.IRouter, service string, sqlDB *sql.DB) {
	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"service": service, "status": "ok"})
	})
	r.GET("/readyz", func(c *gin.Context) {
		if err := sqlDB.PingContext(c.Request.Context()); err != nil {
			Fail(c, http.StatusServiceUnavailable, "db_unavailable", err.Error())
			return
		}
		c.JSON(http.StatusOK, gin.H{"service": service, "status": "ready"})
	})
}
