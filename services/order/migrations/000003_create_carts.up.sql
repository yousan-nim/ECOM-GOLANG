-- Carts live in order-service. References to catalog (user, variant) use UUIDs only — no FK.

CREATE TABLE carts (
    id                BIGSERIAL    PRIMARY KEY,
    public_id         UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,

    user_public_id    UUID,                          -- soft ref → catalog.users.public_id
    anonymous_token   TEXT,
    currency          CHAR(3)      NOT NULL,

    status            TEXT         NOT NULL DEFAULT 'ACTIVE'
                      CHECK (status IN ('ACTIVE','CHECKED_OUT','ABANDONED','MERGED','EXPIRED')),
    expires_at        TIMESTAMPTZ,

    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version           BIGINT       NOT NULL DEFAULT 0,

    CONSTRAINT carts_owner_chk CHECK (user_public_id IS NOT NULL OR anonymous_token IS NOT NULL)
);

CREATE UNIQUE INDEX uq_carts_active_user
    ON carts (user_public_id) WHERE user_public_id IS NOT NULL AND status = 'ACTIVE';
CREATE INDEX idx_carts_anon_token ON carts (anonymous_token) WHERE anonymous_token IS NOT NULL;

CREATE TABLE cart_items (
    id                    BIGSERIAL    PRIMARY KEY,
    cart_id               BIGINT       NOT NULL REFERENCES carts(id) ON DELETE CASCADE,

    -- Soft ref to catalog. Snapshot fields cached on add — refresh on view if needed.
    variant_public_id     UUID         NOT NULL,
    product_public_id     UUID         NOT NULL,
    product_name          TEXT         NOT NULL,
    variant_label         TEXT,
    sku                   TEXT         NOT NULL,
    image_url             TEXT,

    quantity              INTEGER      NOT NULL CHECK (quantity > 0),
    unit_price_amount     BIGINT       NOT NULL CHECK (unit_price_amount >= 0),
    unit_price_currency   CHAR(3)      NOT NULL,

    added_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version               BIGINT       NOT NULL DEFAULT 0,

    CONSTRAINT uq_cart_item_variant UNIQUE (cart_id, variant_public_id)
);

SELECT attach_standard_triggers('carts');
SELECT attach_standard_triggers('cart_items');
