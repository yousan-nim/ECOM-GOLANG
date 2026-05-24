CREATE TABLE coupons (
    id                       BIGSERIAL    PRIMARY KEY,
    public_id                UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    code                     CITEXT       NOT NULL UNIQUE,
    name                     TEXT         NOT NULL,
    description              TEXT,

    discount_type            TEXT         NOT NULL
                             CHECK (discount_type IN ('PERCENT','FIXED_AMOUNT','FREE_SHIPPING')),
    discount_value           BIGINT       NOT NULL CHECK (discount_value >= 0),
    discount_currency        CHAR(3),

    min_order_amount         BIGINT,
    max_discount_amount      BIGINT,

    -- Soft refs (no FK across services).
    vendor_public_id         UUID,
    category_public_id       UUID,

    valid_from               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    valid_until              TIMESTAMPTZ,

    usage_limit_total        INTEGER,
    usage_limit_per_user     INTEGER,
    used_count               INTEGER      NOT NULL DEFAULT 0,

    funded_by                TEXT         NOT NULL DEFAULT 'PLATFORM'
                             CHECK (funded_by IN ('PLATFORM','VENDOR','SHARED')),
    is_active                BOOLEAN      NOT NULL DEFAULT TRUE,

    created_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version                  BIGINT       NOT NULL DEFAULT 0,

    CONSTRAINT coupons_validity_chk CHECK (valid_until IS NULL OR valid_until > valid_from),
    CONSTRAINT coupons_currency_chk CHECK (discount_type <> 'FIXED_AMOUNT' OR discount_currency IS NOT NULL)
);

CREATE INDEX idx_coupons_active_window ON coupons (valid_from, valid_until) WHERE is_active;
CREATE INDEX idx_coupons_vendor   ON coupons (vendor_public_id)   WHERE vendor_public_id   IS NOT NULL;
CREATE INDEX idx_coupons_category ON coupons (category_public_id) WHERE category_public_id IS NOT NULL;

CREATE TABLE coupon_usages (
    id                  BIGSERIAL    PRIMARY KEY,
    coupon_id           BIGINT       NOT NULL REFERENCES coupons(id) ON DELETE RESTRICT,
    user_public_id      UUID,                                  -- soft ref
    order_id            BIGINT       NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    discount_amount     BIGINT       NOT NULL,
    currency            CHAR(3)      NOT NULL,
    used_at             TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_coupon_per_order UNIQUE (coupon_id, order_id)
);

CREATE INDEX idx_coupon_usages_coupon ON coupon_usages (coupon_id, used_at DESC);

SELECT attach_standard_triggers('coupons');
