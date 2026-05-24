-- ┌───────────────────────────────────────────────────────────┐
-- │ V7: products + product_images.                            │
-- │     Variants and inventory live in V8 / V9.               │
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE products (
    id              BIGSERIAL    PRIMARY KEY,
    public_id       UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    vendor_id       BIGINT       NOT NULL REFERENCES vendors(id) ON DELETE RESTRICT,
    category_id     BIGINT       NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,

    name            TEXT         NOT NULL,
    slug            CITEXT       NOT NULL,
    short_desc      TEXT,
    description     TEXT,                                       -- markdown / sanitized html
    brand           TEXT,

    status          TEXT         NOT NULL DEFAULT 'DRAFT'
                    CHECK (status IN ('DRAFT','PENDING_REVIEW','ACTIVE','INACTIVE','REJECTED')),

    -- Display price (for catalog / list view). Authoritative price lives on each variant.
    -- Useful for "from ฿199" displays without joining variants.
    price_min_amount   BIGINT,
    price_max_amount   BIGINT,
    price_currency     CHAR(3),

    weight_g        INTEGER      CHECK (weight_g >= 0),         -- shipping weight (grams)
    length_mm       INTEGER      CHECK (length_mm >= 0),
    width_mm        INTEGER      CHECK (width_mm  >= 0),
    height_mm       INTEGER      CHECK (height_mm >= 0),

    -- SEO
    meta_title      TEXT,
    meta_description TEXT,
    search_keywords TEXT,

    -- Denormalized counters (recomputed by job/trigger).
    rating_avg      NUMERIC(3,2),
    rating_count    INTEGER      NOT NULL DEFAULT 0,
    sold_count      INTEGER      NOT NULL DEFAULT 0,
    view_count      BIGINT       NOT NULL DEFAULT 0,

    published_at    TIMESTAMPTZ,

    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by      BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    updated_by      BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    version         BIGINT       NOT NULL DEFAULT 0,
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT uq_products_vendor_slug UNIQUE (vendor_id, slug)
);

CREATE INDEX idx_products_vendor          ON products (vendor_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_category        ON products (category_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_status          ON products (status) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_published       ON products (published_at DESC NULLS LAST)
    WHERE status = 'ACTIVE' AND deleted_at IS NULL;
CREATE INDEX idx_products_name_trgm       ON products USING GIN (name gin_trgm_ops);
CREATE INDEX idx_products_search_trgm     ON products USING GIN (search_keywords gin_trgm_ops);
CREATE INDEX idx_products_rating          ON products (rating_avg DESC NULLS LAST, rating_count DESC);

-- ─── Product images ──────────────────────────────────────────
CREATE TABLE product_images (
    id           BIGSERIAL    PRIMARY KEY,
    product_id   BIGINT       NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    url          TEXT         NOT NULL,
    alt_text     TEXT,
    position     INTEGER      NOT NULL DEFAULT 0,
    is_primary   BOOLEAN      NOT NULL DEFAULT FALSE,
    width        INTEGER,
    height       INTEGER,

    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by   BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    version      BIGINT       NOT NULL DEFAULT 0
);

CREATE INDEX idx_product_images_product
    ON product_images (product_id, position);
CREATE UNIQUE INDEX uq_product_images_primary
    ON product_images (product_id)
    WHERE is_primary;

SELECT attach_standard_triggers('products');
SELECT attach_standard_triggers('product_images');
