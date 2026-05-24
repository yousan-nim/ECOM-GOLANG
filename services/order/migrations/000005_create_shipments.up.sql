CREATE TABLE shipments (
    id                  BIGSERIAL    PRIMARY KEY,
    public_id           UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    sub_order_id        BIGINT       NOT NULL REFERENCES sub_orders(id) ON DELETE CASCADE,

    -- Soft ref → catalog.warehouses
    warehouse_public_id UUID,
    warehouse_name      TEXT,                                  -- snapshot for display

    carrier             TEXT         NOT NULL,
    service_level       TEXT,
    tracking_number     TEXT,
    tracking_url        TEXT,

    status              TEXT         NOT NULL DEFAULT 'PENDING'
                        CHECK (status IN (
                            'PENDING','LABEL_CREATED','PICKED_UP','IN_TRANSIT',
                            'OUT_FOR_DELIVERY','DELIVERED','RETURNED','LOST','FAILED'
                        )),

    shipping_cost       BIGINT       NOT NULL DEFAULT 0,
    currency            CHAR(3)      NOT NULL,
    weight_g            INTEGER,

    shipped_at          TIMESTAMPTZ,
    estimated_delivery_at TIMESTAMPTZ,
    delivered_at        TIMESTAMPTZ,

    proof_of_delivery_url TEXT,

    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version             BIGINT       NOT NULL DEFAULT 0
);

CREATE INDEX idx_shipments_sub_order ON shipments (sub_order_id);
CREATE INDEX idx_shipments_status    ON shipments (status, updated_at DESC);
CREATE INDEX idx_shipments_tracking  ON shipments (carrier, tracking_number)
    WHERE tracking_number IS NOT NULL;

CREATE TABLE shipment_events (
    id              BIGSERIAL    PRIMARY KEY,
    shipment_id     BIGINT       NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
    status          TEXT         NOT NULL,
    description     TEXT,
    location        TEXT,
    occurred_at     TIMESTAMPTZ  NOT NULL,
    source          TEXT         NOT NULL DEFAULT 'CARRIER_WEBHOOK',
    raw_payload     JSONB,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_shipment_events_shipment ON shipment_events (shipment_id, occurred_at DESC);

CREATE TABLE shipment_items (
    shipment_id     BIGINT NOT NULL REFERENCES shipments(id)   ON DELETE CASCADE,
    order_item_id   BIGINT NOT NULL REFERENCES order_items(id) ON DELETE RESTRICT,
    quantity        INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (shipment_id, order_item_id)
);

SELECT attach_standard_triggers('shipments');
