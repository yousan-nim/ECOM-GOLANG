// Package config loads service configuration from the environment.
// Values are read once at startup; missing required values fail fast.
package config

import (
	"fmt"
	"net/url"
	"os"
	"strconv"
	"strings"
)

// Config holds everything a service needs to boot.
type Config struct {
	ServiceName  string
	HTTPPort     string
	DB           DBConfig
	Redis        RedisConfig
	KafkaBrokers []string
	JWTSecret    string
}

// RedisConfig describes the shared cache. An empty Addr disables caching, so
// services run correctly (just slower) without Redis. See pkg/cache.
type RedisConfig struct {
	Addr     string
	Password string
	DB       int
}

// DBConfig describes a single Postgres instance (one per service).
type DBConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	Name     string
	SSLMode  string
}

// DSN returns a pgx/lib-pq compatible URL, e.g.
// postgres://user:pass@host:5432/dbname?sslmode=disable
func (d DBConfig) DSN() string {
	u := url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(d.User, d.Password),
		Host:   fmt.Sprintf("%s:%s", d.Host, d.Port),
		Path:   d.Name,
	}
	q := u.Query()
	q.Set("sslmode", d.SSLMode)
	u.RawQuery = q.Encode()
	return u.String()
}

// Load reads configuration for the named service.
func Load(serviceName string) Config {
	return Config{
		ServiceName: serviceName,
		HTTPPort:    env("HTTP_PORT", "8080"),
		DB: DBConfig{
			Host:     env("DB_HOST", "localhost"),
			Port:     env("DB_PORT", "5432"),
			User:     env("DB_USER", serviceName),
			Password: env("DB_PASSWORD", serviceName),
			Name:     env("DB_NAME", serviceName+"_db"),
			SSLMode:  env("DB_SSLMODE", "disable"),
		},
		Redis: RedisConfig{
			Addr:     env("REDIS_ADDR", ""), // empty = caching disabled
			Password: env("REDIS_PASSWORD", ""),
			DB:       atoiDefault(env("REDIS_DB", "0"), 0),
		},
		KafkaBrokers: splitNonEmpty(env("KAFKA_BROKERS", "localhost:9092")),
		JWTSecret:    env("JWT_SECRET", "dev-secret-change-me"),
	}
}

func atoiDefault(s string, def int) int {
	n, err := strconv.Atoi(s)
	if err != nil {
		return def
	}
	return n
}

func env(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return def
}

func splitNonEmpty(s string) []string {
	var out []string
	for _, p := range strings.Split(s, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}
