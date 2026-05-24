-- ┌───────────────────────────────────────────────────────────┐
-- │ V4: addresses — used by users (shipping/billing) and      │
-- │     vendors (warehouse, return).                          │
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE addresses (
    id            BIGSERIAL    PRIMARY KEY,
    public_id     UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,

    -- Polymorphic owner: exactly one of (user_id, vendor_id) is set.
    -- vendor_id FK is added in V5 (after vendors table exists).
    user_id       BIGINT       REFERENCES users(id) ON DELETE CASCADE,
    vendor_id    BIGINT,

    label         TEXT,                       -- "Home", "Office", "Warehouse A"
    recipient     TEXT         NOT NULL,
    phone         TEXT         NOT NULL,

    line1         TEXT         NOT NULL,
    line2         TEXT,
    subdistrict   TEXT,                       -- ตำบล / แขวง
    district      TEXT         NOT NULL,      -- อำเภอ / เขต
    province      TEXT         NOT NULL,      -- จังหวัด
    postal_code   TEXT         NOT NULL,
    country_code  CHAR(2)      NOT NULL DEFAULT 'TH',  -- ISO 3166-1 alpha-2

    is_default    BOOLEAN      NOT NULL DEFAULT FALSE,
    address_type  TEXT         NOT NULL DEFAULT 'SHIPPING'
                  CHECK (address_type IN ('SHIPPING','BILLING','WAREHOUSE','RETURN')),

    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by    BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    updated_by    BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    version       BIGINT       NOT NULL DEFAULT 0,
    deleted_at    TIMESTAMPTZ,

    CONSTRAINT addresses_owner_chk
        CHECK ((user_id IS NOT NULL)::int + (vendor_id IS NOT NULL)::int = 1)
);

CREATE INDEX idx_addresses_user            ON addresses (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_addresses_vendor          ON addresses (vendor_id) WHERE vendor_id IS NOT NULL;
CREATE UNIQUE INDEX uq_addresses_user_default
    ON addresses (user_id, address_type)
    WHERE is_default AND user_id IS NOT NULL AND deleted_at IS NULL;

SELECT attach_standard_triggers('addresses');
