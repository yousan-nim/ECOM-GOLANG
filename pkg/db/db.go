// Package db opens a Postgres connection (shared by GORM and golang-migrate)
// and runs embedded SQL migrations.
//
// The schema is owned by the SQL migration files (golang-migrate) — NOT by
// GORM AutoMigrate. The migrations contain triggers, partitioned tables and
// plpgsql functions that AutoMigrate cannot reproduce. GORM is used only to
// map queries onto the existing schema.
package db

import (
	"database/sql"
	"errors"
	"fmt"
	"io/fs"
	"time"

	"github.com/golang-migrate/migrate/v4"
	migratepgx "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	_ "github.com/jackc/pgx/v5/stdlib" // register the "pgx" database/sql driver
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Open creates one *sql.DB (pgx stdlib) and wraps it with GORM so both GORM
// and the migrator share a single connection pool.
func Open(dsn string) (*gorm.DB, *sql.DB, error) {
	sqlDB, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, nil, fmt.Errorf("open sql: %w", err)
	}
	sqlDB.SetMaxOpenConns(20)
	sqlDB.SetMaxIdleConns(5)
	sqlDB.SetConnMaxLifetime(30 * time.Minute)

	gdb, err := gorm.Open(postgres.New(postgres.Config{Conn: sqlDB}), &gorm.Config{
		Logger:                 logger.Default.LogMode(logger.Warn),
		SkipDefaultTransaction: true,
	})
	if err != nil {
		return nil, nil, fmt.Errorf("open gorm: %w", err)
	}
	return gdb, sqlDB, nil
}

// Migrate applies all up migrations embedded under the "migrations" directory
// of the given filesystem. It is a no-op when the schema is already current.
func Migrate(sqlDB *sql.DB, fsys fs.FS) error {
	src, err := iofs.New(fsys, "migrations")
	if err != nil {
		return fmt.Errorf("migrate source: %w", err)
	}
	drv, err := migratepgx.WithInstance(sqlDB, &migratepgx.Config{})
	if err != nil {
		return fmt.Errorf("migrate driver: %w", err)
	}
	m, err := migrate.NewWithInstance("iofs", src, "pgx5", drv)
	if err != nil {
		return fmt.Errorf("migrate init: %w", err)
	}
	if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("migrate up: %w", err)
	}
	return nil
}
