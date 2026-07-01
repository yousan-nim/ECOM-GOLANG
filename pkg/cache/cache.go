// Package cache is a thin wrapper over a Redis client that all services share.
//
// It provides:
//   - Open: build a *redis.Client from config and verify connectivity.
//   - Cache: a small cache-aside helper (GetOrSet) with JSON (de)serialization,
//     so handlers can wrap an expensive read (DB query, cross-service call) in
//     one line without repeating marshal/unmarshal/TTL boilerplate.
//
// Caching is OPTIONAL: when Redis is not configured (empty addr) Open returns a
// nil *Cache and every method degrades to calling the loader directly. This
// keeps Redis a performance layer, never a hard dependency for correctness.
//
// See docs/SCALING.md ("Caching") for where to use this and the
// cache-invalidation rules.
package cache

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// Config describes how to reach Redis. An empty Addr disables caching.
type Config struct {
	Addr     string // host:port, e.g. "redis:6379"; empty = caching disabled
	Password string
	DB       int
}

// Cache is a cache-aside helper around a Redis client. A nil *Cache is valid
// and behaves as a pass-through (no caching), so callers never need nil checks.
type Cache struct {
	rdb       *redis.Client
	keyPrefix string // namespaces keys per service, e.g. "catalog:"
}

// ErrMiss is returned by Get when the key is absent.
var ErrMiss = errors.New("cache: miss")

// Open connects to Redis and pings it. When cfg.Addr is empty it returns
// (nil, nil): caching is disabled and the helper degrades gracefully.
// keyPrefix should be the service name so keys never collide across services
// that may share a Redis instance.
func Open(ctx context.Context, cfg Config, keyPrefix string) (*Cache, error) {
	if cfg.Addr == "" {
		return nil, nil
	}
	rdb := redis.NewClient(&redis.Options{
		Addr:         cfg.Addr,
		Password:     cfg.Password,
		DB:           cfg.DB,
		DialTimeout:  3 * time.Second,
		ReadTimeout:  2 * time.Second,
		WriteTimeout: 2 * time.Second,
		PoolSize:     20,
	})
	pingCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	if err := rdb.Ping(pingCtx).Err(); err != nil {
		_ = rdb.Close()
		return nil, fmt.Errorf("cache ping: %w", err)
	}
	return &Cache{rdb: rdb, keyPrefix: keyPrefix + ":"}, nil
}

// Enabled reports whether a live Redis connection is backing this cache.
func (c *Cache) Enabled() bool { return c != nil && c.rdb != nil }

// Client exposes the underlying client (e.g. for the readiness probe). May be nil.
func (c *Cache) Client() *redis.Client {
	if !c.Enabled() {
		return nil
	}
	return c.rdb
}

// Close releases the connection pool. Safe to call on a nil/disabled cache.
func (c *Cache) Close() error {
	if !c.Enabled() {
		return nil
	}
	return c.rdb.Close()
}

// GetOrSet implements the cache-aside pattern:
//  1. try to read key from Redis and unmarshal into dst;
//  2. on a miss (or when caching is disabled), call load(), store the result
//     with ttl, and unmarshal it into dst.
//
// A Redis error never fails the request: it falls through to load() so the DB
// remains the source of truth. dst must be a non-nil pointer.
func GetOrSet[T any](ctx context.Context, c *Cache, key string, ttl time.Duration, load func(context.Context) (T, error)) (T, error) {
	var zero T
	if !c.Enabled() {
		return load(ctx)
	}
	full := c.keyPrefix + key

	// 1. read-through
	if b, err := c.rdb.Get(ctx, full).Bytes(); err == nil {
		var v T
		if jerr := json.Unmarshal(b, &v); jerr == nil {
			return v, nil
		}
		// corrupt entry — drop it and fall through to reload.
		_ = c.rdb.Del(ctx, full).Err()
	}

	// 2. load from source of truth
	v, err := load(ctx)
	if err != nil {
		return zero, err
	}

	// 3. populate cache (best-effort; ignore write errors).
	if b, mErr := json.Marshal(v); mErr == nil {
		_ = c.rdb.Set(ctx, full, b, ttl).Err()
	}
	return v, nil
}

// Delete evicts one or more keys. Use it on writes to invalidate stale entries
// (write-through invalidation). No-op when caching is disabled.
func (c *Cache) Delete(ctx context.Context, keys ...string) error {
	if !c.Enabled() || len(keys) == 0 {
		return nil
	}
	full := make([]string, len(keys))
	for i, k := range keys {
		full[i] = c.keyPrefix + k
	}
	return c.rdb.Del(ctx, full...).Err()
}
