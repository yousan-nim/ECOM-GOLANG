-- ┌───────────────────────────────────────────────────────────┐
-- │ V1: Postgres extensions used across the schema.           │
-- └───────────────────────────────────────────────────────────┘

CREATE EXTENSION IF NOT EXISTS "pgcrypto";    -- gen_random_bytes, digest
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";   -- uuid_generate_v4 fallback
CREATE EXTENSION IF NOT EXISTS "pg_trgm";     -- trigram search (product name, fuzzy)
CREATE EXTENSION IF NOT EXISTS "citext";      -- case-insensitive text (emails, slugs)
CREATE EXTENSION IF NOT EXISTS "btree_gin";   -- composite GIN indexes
