-- ┌───────────────────────────────────────────────────────────┐
-- │ V6: hierarchical categories (parent_id self-reference).   │
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE categories (
    id            BIGSERIAL    PRIMARY KEY,
    public_id     UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    parent_id     BIGINT       REFERENCES categories(id) ON DELETE RESTRICT,

    name          TEXT         NOT NULL,
    slug          CITEXT       NOT NULL,
    description   TEXT,
    image_url     TEXT,
    icon_url      TEXT,

    position      INTEGER      NOT NULL DEFAULT 0,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,

    -- Materialized path (e.g. '/electronics/phones/smartphones/') for fast subtree queries.
    -- Recomputed by trigger / application code on parent change.
    path          TEXT         NOT NULL DEFAULT '/',
    depth         INTEGER      NOT NULL DEFAULT 0,

    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by    BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    updated_by    BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    version       BIGINT       NOT NULL DEFAULT 0,
    deleted_at    TIMESTAMPTZ,

    -- A slug is unique within a parent (so /shoes and /clothing/shoes can both exist).
    CONSTRAINT uq_categories_parent_slug UNIQUE (parent_id, slug)
);

CREATE INDEX idx_categories_parent       ON categories (parent_id);
CREATE INDEX idx_categories_active       ON categories (is_active) WHERE deleted_at IS NULL;
CREATE INDEX idx_categories_path_prefix  ON categories (path text_pattern_ops);
CREATE INDEX idx_categories_name_trgm    ON categories USING GIN (name gin_trgm_ops);

-- Wire up commission_rates → categories FK now that the table exists.
ALTER TABLE commission_rates
    ADD CONSTRAINT fk_commission_category
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE;

SELECT attach_standard_triggers('categories');
