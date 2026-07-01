package promotion

import "embed"

// MigrationsFS embeds the SQL migrations so the binary is self-contained.
// The embed directive must live in this package (sibling of migrations/);
// embed cannot reach into a parent directory from cmd/.
//
//go:embed migrations/*.sql
var MigrationsFS embed.FS
