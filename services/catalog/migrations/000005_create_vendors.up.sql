-- ┌───────────────────────────────────────────────────────────┐
-- │ V5: vendors (marketplace shops) + payouts + commissions.  │
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE vendors (
    id                       BIGSERIAL    PRIMARY KEY,
    public_id                UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    owner_user_id            BIGINT       NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    name                     TEXT         NOT NULL,
    slug                     CITEXT       NOT NULL UNIQUE,
    description              TEXT,
    logo_url                 TEXT,
    cover_url                TEXT,

    contact_email            CITEXT       NOT NULL,
    contact_phone            TEXT         NOT NULL,
    tax_id                   TEXT,                                    -- เลขผู้เสียภาษี
    status                   TEXT         NOT NULL DEFAULT 'PENDING'
                              CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','BANNED','CLOSED')),

    -- Default commission % the platform takes from each sub_order total.
    -- Can be overridden per (vendor, category) via commission_rates.
    default_commission_bps   INTEGER      NOT NULL DEFAULT 1000
                              CHECK (default_commission_bps BETWEEN 0 AND 10000),
                              -- bps = basis points; 1000 = 10.00%

    payout_currency          CHAR(3)      NOT NULL DEFAULT 'THB',
    onboarded_at             TIMESTAMPTZ,
    suspended_at             TIMESTAMPTZ,
    suspended_reason         TEXT,

    -- rating cache (recomputed by job)
    rating_avg               NUMERIC(3,2),
    rating_count             INTEGER      NOT NULL DEFAULT 0,

    created_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by               BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    updated_by               BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    version                  BIGINT       NOT NULL DEFAULT 0,
    deleted_at               TIMESTAMPTZ
);

CREATE INDEX idx_vendors_owner   ON vendors (owner_user_id);
CREATE INDEX idx_vendors_status  ON vendors (status) WHERE deleted_at IS NULL;
CREATE INDEX idx_vendors_name_trgm ON vendors USING GIN (name gin_trgm_ops);

-- Now wire addresses → vendors FK
ALTER TABLE addresses
    ADD CONSTRAINT fk_addresses_vendor
    FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE;

-- ─── Vendor bank accounts (for payouts) ──────────────────────
CREATE TABLE vendor_bank_accounts (
    id              BIGSERIAL    PRIMARY KEY,
    public_id       UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    vendor_id       BIGINT       NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,

    bank_code       TEXT         NOT NULL,         -- e.g. 'SCB', 'KBANK'
    account_number_enc TEXT      NOT NULL,         -- encrypted at app layer
    account_number_last4 TEXT    NOT NULL,         -- for display
    account_name    TEXT         NOT NULL,
    is_default      BOOLEAN      NOT NULL DEFAULT FALSE,
    verified_at     TIMESTAMPTZ,

    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by      BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    updated_by      BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    version         BIGINT       NOT NULL DEFAULT 0,
    deleted_at      TIMESTAMPTZ
);

CREATE UNIQUE INDEX uq_vendor_bank_default
    ON vendor_bank_accounts (vendor_id)
    WHERE is_default AND deleted_at IS NULL;

-- ─── Commission overrides (per vendor, per category) ─────────
-- category_id FK added in V6.
CREATE TABLE commission_rates (
    id              BIGSERIAL    PRIMARY KEY,
    vendor_id       BIGINT       NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    category_id     BIGINT,                                 -- NULL = applies to all categories
    rate_bps        INTEGER      NOT NULL
                    CHECK (rate_bps BETWEEN 0 AND 10000),
    valid_from      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    valid_to        TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by      BIGINT       REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX idx_commission_lookup
    ON commission_rates (vendor_id, category_id, valid_from DESC);

-- Note: `vendor_payouts` is owned by payment-service (settlement = payment-domain concern).
-- payment-service references vendors via UUID (vendor_public_id) — no cross-service FK.

SELECT attach_standard_triggers('vendors');
SELECT attach_standard_triggers('vendor_bank_accounts');
