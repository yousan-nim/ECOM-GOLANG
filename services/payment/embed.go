package payment

import "embed"

// MigrationsFS embeds the SQL migrations so the binary is self-contained.
//
//go:embed migrations/*.sql
var MigrationsFS embed.FS
