-- Orders + sub_orders + order_items.
-- All cross-service references are UUID + snapshot fields (no FK).

CREATE TABLE orders (
    id                  BIGSERIAL    PRIMARY KEY,
    public_id           UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    order_number        TEXT         NOT NULL UNIQUE,

    user_public_id      UUID,                                  -- soft ref → catalog.users
    guest_email         CITEXT,
    guest_phone         TEXT,

    status              TEXT         NOT NULL DEFAULT 'PENDING_PAYMENT'
                        CHECK (status IN (
                            'PENDING_PAYMENT','PAID','PARTIALLY_FULFILLED','FULFILLED',
                            'CANCELLED','REFUNDED','PARTIALLY_REFUNDED','FAILED'
                        )),

    currency            CHAR(3)      NOT NULL,
    subtotal_amount     BIGINT       NOT NULL CHECK (subtotal_amount >= 0),
    discount_amount     BIGINT       NOT NULL DEFAULT 0,
    shipping_amount     BIGINT       NOT NULL DEFAULT 0,
    tax_amount          BIGINT       NOT NULL DEFAULT 0,
    total_amount        BIGINT       NOT NULL CHECK (total_amount >= 0),

    -- Captured FX vs base currency at order-placement time.
    fx_rate_to_base     NUMERIC(18,8),
    base_currency       CHAR(3),
    base_total_amount   BIGINT,

    -- Denormalized customer snapshot.
    customer_email      CITEXT       NOT NULL,
    customer_phone      TEXT,
    customer_name       TEXT         NOT NULL,
    billing_address     JSONB        NOT NULL,
    shipping_address    JSONB        NOT NULL,

    coupon_code         TEXT,

    placed_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    paid_at             TIMESTAMPTZ,
    fulfilled_at        TIMESTAMPTZ,
    cancelled_at        TIMESTAMPTZ,
    cancelled_reason    TEXT,
    notes               TEXT,

    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version             BIGINT       NOT NULL DEFAULT 0
);

CREATE INDEX idx_orders_user_placed ON orders (user_public_id, placed_at DESC) WHERE user_public_id IS NOT NULL;
CREATE INDEX idx_orders_status      ON orders (status, placed_at DESC);
CREATE INDEX idx_orders_email       ON orders (customer_email);

CREATE TABLE sub_orders (
    id                    BIGSERIAL    PRIMARY KEY,
    public_id             UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    order_id              BIGINT       NOT NULL REFERENCES orders(id) ON DELETE CASCADE,

    -- Soft ref → catalog.vendors. Vendor display name is snapshotted.
    vendor_public_id      UUID         NOT NULL,
    vendor_name           TEXT         NOT NULL,

    sub_order_number      TEXT         NOT NULL UNIQUE,
    status                TEXT         NOT NULL DEFAULT 'PENDING'
                          CHECK (status IN (
                              'PENDING','CONFIRMED','PREPARING','SHIPPED','DELIVERED',
                              'COMPLETED','CANCELLED','REFUNDED','PARTIALLY_REFUNDED'
                          )),

    currency              CHAR(3)      NOT NULL,
    subtotal_amount       BIGINT       NOT NULL,
    discount_amount       BIGINT       NOT NULL DEFAULT 0,
    shipping_amount       BIGINT       NOT NULL DEFAULT 0,
    tax_amount            BIGINT       NOT NULL DEFAULT 0,
    total_amount          BIGINT       NOT NULL,

    commission_bps        INTEGER      NOT NULL CHECK (commission_bps BETWEEN 0 AND 10000),
    commission_amount     BIGINT       NOT NULL CHECK (commission_amount >= 0),
    vendor_net_amount     BIGINT       NOT NULL CHECK (vendor_net_amount >= 0),
    -- payout_public_id resolved by payment-service later (no FK).
    payout_public_id      UUID,

    confirmed_at          TIMESTAMPTZ,
    shipped_at            TIMESTAMPTZ,
    delivered_at          TIMESTAMPTZ,
    cancelled_at          TIMESTAMPTZ,
    cancelled_reason      TEXT,

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version               BIGINT       NOT NULL DEFAULT 0,

    CONSTRAINT uq_sub_orders_order_vendor UNIQUE (order_id, vendor_public_id)
);

CREATE INDEX idx_sub_orders_vendor_status ON sub_orders (vendor_public_id, status, created_at DESC);
CREATE INDEX idx_sub_orders_payout        ON sub_orders (payout_public_id) WHERE payout_public_id IS NOT NULL;

CREATE TABLE order_items (
    id                    BIGSERIAL    PRIMARY KEY,
    public_id             UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    sub_order_id          BIGINT       NOT NULL REFERENCES sub_orders(id) ON DELETE CASCADE,

    -- Soft ref + FULL snapshot — order history must survive product deletion/changes.
    variant_public_id     UUID         NOT NULL,
    product_public_id     UUID         NOT NULL,
    product_name          TEXT         NOT NULL,
    variant_label         TEXT,
    sku                   TEXT         NOT NULL,
    image_url             TEXT,
    snapshot              JSONB        NOT NULL,

    quantity              INTEGER      NOT NULL CHECK (quantity > 0),
    unit_price_amount     BIGINT       NOT NULL,
    unit_price_currency   CHAR(3)      NOT NULL,
    discount_amount       BIGINT       NOT NULL DEFAULT 0,
    tax_amount            BIGINT       NOT NULL DEFAULT 0,
    line_total_amount     BIGINT       NOT NULL,

    quantity_refunded     INTEGER      NOT NULL DEFAULT 0 CHECK (quantity_refunded >= 0),
    refunded_amount       BIGINT       NOT NULL DEFAULT 0 CHECK (refunded_amount >= 0),

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version               BIGINT       NOT NULL DEFAULT 0,

    CONSTRAINT order_items_refund_le_qty CHECK (quantity_refunded <= quantity)
);

CREATE INDEX idx_order_items_sub_order ON order_items (sub_order_id);
CREATE INDEX idx_order_items_variant   ON order_items (variant_public_id);
CREATE INDEX idx_order_items_sku       ON order_items (sku);

SELECT attach_standard_triggers('orders');
SELECT attach_standard_triggers('sub_orders');
SELECT attach_standard_triggers('order_items');
