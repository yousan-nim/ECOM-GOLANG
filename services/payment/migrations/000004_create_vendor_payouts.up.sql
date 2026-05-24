-- Vendor settlement batches. Vendor + bank account are soft refs to catalog (UUID).

CREATE TABLE vendor_payouts (
    id                       BIGSERIAL    PRIMARY KEY,
    public_id                UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,

    vendor_public_id         UUID         NOT NULL,
    vendor_name              TEXT         NOT NULL,             -- snapshot

    period_start             TIMESTAMPTZ  NOT NULL,
    period_end               TIMESTAMPTZ  NOT NULL,

    gross_amount             BIGINT       NOT NULL,
    commission_amount        BIGINT       NOT NULL,
    refund_amount            BIGINT       NOT NULL DEFAULT 0,
    adjustment_amount        BIGINT       NOT NULL DEFAULT 0,
    net_amount               BIGINT       NOT NULL,
    currency                 CHAR(3)      NOT NULL,

    status                   TEXT         NOT NULL DEFAULT 'PENDING'
                             CHECK (status IN ('PENDING','PROCESSING','PAID','FAILED','CANCELLED')),
    paid_at                  TIMESTAMPTZ,
    payout_reference         TEXT,
    failure_reason           TEXT,

    bank_account_public_id   UUID,                              -- snapshot of which bank acct
    bank_account_last4       TEXT,

    created_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version                  BIGINT       NOT NULL DEFAULT 0,

    CONSTRAINT vendor_payouts_period_chk CHECK (period_end > period_start)
);

CREATE INDEX idx_payouts_vendor ON vendor_payouts (vendor_public_id, period_end DESC);
CREATE INDEX idx_payouts_status ON vendor_payouts (status, period_end);

SELECT attach_standard_triggers('vendor_payouts');
