-- ┌───────────────────────────────────────────────────────────┐
-- │ V8: product variants (SKUs).                              │
-- │  Model:                                                   │
-- │   products ─── product_options (Size, Color, …)           │
-- │              └─ option_values  (S, M, L, Red, Blue, …)    │
-- │   products ─── product_variants (one SKU per combo)       │
-- │              └─ variant_option_values (variant ↔ value)   │
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE product_options (
    id           BIGSERIAL    PRIMARY KEY,
    product_id   BIGINT       NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    name         TEXT         NOT NULL,                -- "Size", "Color"
    position     INTEGER      NOT NULL DEFAULT 0,

    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version      BIGINT       NOT NULL DEFAULT 0,

    CONSTRAINT uq_product_options UNIQUE (product_id, name)
);

CREATE TABLE option_values (
    id             BIGSERIAL    PRIMARY KEY,
    option_id      BIGINT       NOT NULL REFERENCES product_options(id) ON DELETE CASCADE,
    value          TEXT         NOT NULL,              -- "M", "Red", "#FF0000"
    display_label  TEXT,                               -- shown to customer if value is technical
    swatch_hex     CHAR(7),                            -- "#RRGGBB" for color swatches
    position       INTEGER      NOT NULL DEFAULT 0,

    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version        BIGINT       NOT NULL DEFAULT 0,

    CONSTRAINT uq_option_values UNIQUE (option_id, value)
);

CREATE INDEX idx_option_values_option ON option_values (option_id, position);

-- ─── Variants (the actual SKUs that get sold) ────────────────
CREATE TABLE product_variants (
    id              BIGSERIAL    PRIMARY KEY,
    public_id       UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    product_id      BIGINT       NOT NULL REFERENCES products(id) ON DELETE CASCADE,

    sku             TEXT         NOT NULL UNIQUE,      -- vendor-scoped SKU code
    barcode         TEXT,                              -- UPC/EAN
    name_suffix     TEXT,                              -- "Red / M" — denormalized for display

    -- Authoritative price (overrides product.price_*).
    price_amount    BIGINT       NOT NULL CHECK (price_amount >= 0),
    price_currency  CHAR(3)      NOT NULL,
    compare_at_amount BIGINT     CHECK (compare_at_amount IS NULL OR compare_at_amount >= 0),
    cost_amount     BIGINT       CHECK (cost_amount IS NULL OR cost_amount >= 0),  -- COGS

    weight_g        INTEGER      CHECK (weight_g IS NULL OR weight_g >= 0),

    image_url       TEXT,                              -- variant-specific image (overrides product image)

    status          TEXT         NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE','INACTIVE','OUT_OF_STOCK','DISCONTINUED')),

    position        INTEGER      NOT NULL DEFAULT 0,

    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by      BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    updated_by      BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    version         BIGINT       NOT NULL DEFAULT 0,
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX idx_variants_product       ON product_variants (product_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_variants_status        ON product_variants (status) WHERE deleted_at IS NULL;
CREATE INDEX idx_variants_barcode       ON product_variants (barcode) WHERE barcode IS NOT NULL;

-- ─── Link table: variant ↔ option value ──────────────────────
CREATE TABLE variant_option_values (
    variant_id        BIGINT NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
    option_value_id   BIGINT NOT NULL REFERENCES option_values(id)    ON DELETE RESTRICT,
    PRIMARY KEY (variant_id, option_value_id)
);

CREATE INDEX idx_variant_option_values_value ON variant_option_values (option_value_id);

SELECT attach_standard_triggers('product_variants');
