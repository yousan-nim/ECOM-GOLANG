-- ┌───────────────────────────────────────────────────────────┐
-- │ V3: carts + cart_items (cart service).                     │
-- │  All cross-service references are UUID + snapshot (no FK).  │
-- │  A cart is ephemeral until checkout converts it to an order.│
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE carts (
    id              BIGSERIAL    PRIMARY KEY,
    public_id       UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,

    -- Exactly one of user_public_id / session_id identifies the owner.
    user_public_id  UUID,                                  -- soft ref → auth.users (logged-in)
    session_id      TEXT,                                  -- anonymous/guest cart

    currency        CHAR(3)      NOT NULL,
    status          TEXT         NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE','CONVERTED','ABANDONED')),

    expires_at      TIMESTAMPTZ,                           -- TTL for guest carts
    converted_at    TIMESTAMPTZ,                           -- when it became an order
    order_public_id UUID,                                  -- soft ref → order.orders

    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version         BIGINT       NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX idx_carts_user_active
    ON carts (user_public_id) WHERE status = 'ACTIVE' AND user_public_id IS NOT NULL;
CREATE UNIQUE INDEX idx_carts_session_active
    ON carts (session_id) WHERE status = 'ACTIVE' AND session_id IS NOT NULL;
CREATE INDEX idx_carts_status ON carts (status, updated_at DESC);

CREATE TABLE cart_items (
    id                 BIGSERIAL   PRIMARY KEY,
    public_id          UUID        NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    cart_id            BIGINT      NOT NULL REFERENCES carts(id) ON DELETE CASCADE,

    -- Soft refs → catalog. Snapshots capture price/name at add-to-cart time;
    -- the real price is re-validated at checkout by the order service.
    product_public_id  UUID        NOT NULL,
    variant_public_id  UUID        NOT NULL,
    vendor_public_id   UUID        NOT NULL,
    sku                TEXT        NOT NULL,
    name_snapshot      TEXT        NOT NULL,
    image_url          TEXT,

    unit_price         BIGINT      NOT NULL CHECK (unit_price >= 0),  -- minor units
    currency           CHAR(3)     NOT NULL,
    quantity           INTEGER     NOT NULL CHECK (quantity > 0),

    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (cart_id, variant_public_id)                    -- one row per variant; bump quantity
);

CREATE INDEX idx_cart_items_cart ON cart_items (cart_id);

SELECT attach_standard_triggers('carts');
SELECT attach_standard_triggers('cart_items');
