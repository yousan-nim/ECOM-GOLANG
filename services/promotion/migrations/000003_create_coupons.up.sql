-- ┌───────────────────────────────────────────────────────────┐
-- │ V3: coupons + coupon_usages (promotion service).           │
-- │  Platform-wide or vendor-scoped discount codes.            │
-- │  used_count is denormalized; coupon_usages is the ledger.  │
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE coupons (
    id                    BIGSERIAL   PRIMARY KEY,
    public_id             UUID        NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    code                  CITEXT      NOT NULL UNIQUE,          -- case-insensitive
    description           TEXT,

    type                  TEXT        NOT NULL
                          CHECK (type IN ('PERCENT','FIXED_AMOUNT','FREE_SHIPPING')),
    -- PERCENT: value = basis points (1000 = 10%). FIXED_AMOUNT: value = minor units.
    value                 BIGINT      NOT NULL CHECK (value >= 0),
    currency              CHAR(3),                              -- required for FIXED_AMOUNT

    min_order_amount      BIGINT      NOT NULL DEFAULT 0 CHECK (min_order_amount >= 0),
    max_discount_amount   BIGINT      CHECK (max_discount_amount IS NULL OR max_discount_amount >= 0), -- cap for PERCENT

    usage_limit           INTEGER     CHECK (usage_limit IS NULL OR usage_limit >= 0),  -- total redemptions
    usage_limit_per_user  INTEGER     CHECK (usage_limit_per_user IS NULL OR usage_limit_per_user >= 0),
    used_count            INTEGER     NOT NULL DEFAULT 0 CHECK (used_count >= 0),

    vendor_public_id      UUID,                                 -- NULL = platform-wide; else vendor-scoped
    starts_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at               TIMESTAMPTZ,

    status                TEXT        NOT NULL DEFAULT 'ACTIVE'
                          CHECK (status IN ('ACTIVE','PAUSED','EXPIRED')),

    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version               BIGINT      NOT NULL DEFAULT 0,

    CHECK (type <> 'FIXED_AMOUNT' OR currency IS NOT NULL)
);

CREATE INDEX idx_coupons_status ON coupons (status, ends_at);
CREATE INDEX idx_coupons_vendor ON coupons (vendor_public_id) WHERE vendor_public_id IS NOT NULL;

CREATE TABLE coupon_usages (
    id                BIGSERIAL   PRIMARY KEY,
    public_id         UUID        NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    coupon_id         BIGINT      NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,

    user_public_id    UUID        NOT NULL,                  -- → auth.users
    order_public_id   UUID        NOT NULL,                  -- → order.orders
    discount_amount   BIGINT      NOT NULL CHECK (discount_amount >= 0),
    currency          CHAR(3)     NOT NULL,

    used_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- A coupon is applied at most once per order.
    UNIQUE (coupon_id, order_public_id)
);

CREATE INDEX idx_coupon_usages_user ON coupon_usages (coupon_id, user_public_id);

SELECT attach_standard_triggers('coupons');
SELECT attach_standard_triggers('coupon_usages');
