-- ┌───────────────────────────────────────────────────────────┐
-- │ V9: warehouses + inventory.                               │
-- │     Inventory tracked per (variant, warehouse).           │
-- │     reserved_qty handles the in-flight checkout window.   │
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE warehouses (
    id            BIGSERIAL    PRIMARY KEY,
    public_id     UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    vendor_id     BIGINT       NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,

    name          TEXT         NOT NULL,
    address_id    BIGINT       REFERENCES addresses(id) ON DELETE SET NULL,
    is_default    BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,

    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by    BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    updated_by    BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    version       BIGINT       NOT NULL DEFAULT 0
);

CREATE INDEX idx_warehouses_vendor ON warehouses (vendor_id) WHERE is_active;
CREATE UNIQUE INDEX uq_warehouses_default_per_vendor
    ON warehouses (vendor_id) WHERE is_default AND is_active;

-- ─── Inventory (variant × warehouse) ─────────────────────────
CREATE TABLE inventory (
    id                BIGSERIAL    PRIMARY KEY,
    variant_id        BIGINT       NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
    warehouse_id      BIGINT       NOT NULL REFERENCES warehouses(id)       ON DELETE RESTRICT,

    on_hand_qty       INTEGER      NOT NULL DEFAULT 0  CHECK (on_hand_qty  >= 0),
    reserved_qty      INTEGER      NOT NULL DEFAULT 0  CHECK (reserved_qty >= 0),
    safety_stock      INTEGER      NOT NULL DEFAULT 0  CHECK (safety_stock >= 0),
    -- available = on_hand - reserved - safety_stock (computed in query)

    reorder_point     INTEGER,
    reorder_qty       INTEGER,

    last_counted_at   TIMESTAMPTZ,

    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version           BIGINT       NOT NULL DEFAULT 0,

    CONSTRAINT uq_inventory_variant_warehouse UNIQUE (variant_id, warehouse_id),
    CONSTRAINT inventory_reserved_le_on_hand CHECK (reserved_qty <= on_hand_qty)
);

CREATE INDEX idx_inventory_variant       ON inventory (variant_id);
CREATE INDEX idx_inventory_low_stock     ON inventory (warehouse_id)
    WHERE reorder_point IS NOT NULL AND on_hand_qty - reserved_qty < reorder_point;

-- ─── Inventory movement log (audit + reconciliation) ─────────
CREATE TABLE inventory_movements (
    id              BIGSERIAL    PRIMARY KEY,
    inventory_id    BIGINT       NOT NULL REFERENCES inventory(id) ON DELETE CASCADE,

    movement_type   TEXT         NOT NULL
                    CHECK (movement_type IN (
                        'RECEIPT','SHIPMENT','RESERVATION','RELEASE','ADJUSTMENT','RETURN','TRANSFER_IN','TRANSFER_OUT'
                    )),
    quantity_delta  INTEGER      NOT NULL,           -- can be negative
    reason          TEXT,

    -- Source reference (polymorphic, e.g. order_id or transfer_id).
    reference_type  TEXT,
    reference_id    BIGINT,

    occurred_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by      BIGINT       REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX idx_inventory_movements_inv  ON inventory_movements (inventory_id, occurred_at DESC);
CREATE INDEX idx_inventory_movements_ref  ON inventory_movements (reference_type, reference_id)
    WHERE reference_id IS NOT NULL;

SELECT attach_standard_triggers('warehouses');
SELECT attach_standard_triggers('inventory');
