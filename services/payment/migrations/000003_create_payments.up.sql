-- Payments + Refunds. All cross-service refs are UUID + snapshot — no FK out.

CREATE TABLE payments (
    id                  BIGSERIAL    PRIMARY KEY,
    public_id           UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,

    -- Soft ref to order-service.
    order_public_id     UUID         NOT NULL,
    order_number        TEXT         NOT NULL,                  -- snapshot for reconciliation

    provider            TEXT         NOT NULL
                        CHECK (provider IN ('STRIPE','OMISE','PROMPTPAY','TRUEMONEY','2C2P','COD','BANK_TRANSFER')),
    provider_payment_id TEXT,
    provider_intent_id  TEXT,

    method              TEXT         NOT NULL
                        CHECK (method IN ('CARD','PROMPTPAY','BANK_TRANSFER','WALLET','COD','INSTALLMENT')),

    amount              BIGINT       NOT NULL CHECK (amount >= 0),
    currency            CHAR(3)      NOT NULL,
    fee_amount          BIGINT       NOT NULL DEFAULT 0,
    net_amount          BIGINT       NOT NULL CHECK (net_amount >= 0),

    status              TEXT         NOT NULL DEFAULT 'PENDING'
                        CHECK (status IN (
                            'PENDING','AUTHORIZED','REQUIRES_ACTION','CAPTURED','FAILED','CANCELLED','REFUNDED','PARTIALLY_REFUNDED'
                        )),
    failure_code        TEXT,
    failure_message     TEXT,

    card_brand          TEXT,
    card_last4          CHAR(4),
    card_exp_month      SMALLINT  CHECK (card_exp_month BETWEEN 1 AND 12),
    card_exp_year       SMALLINT,

    attempted_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    authorized_at       TIMESTAMPTZ,
    captured_at         TIMESTAMPTZ,
    failed_at           TIMESTAMPTZ,
    raw_response        JSONB,

    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version             BIGINT       NOT NULL DEFAULT 0
);

CREATE INDEX idx_payments_order       ON payments (order_public_id, attempted_at DESC);
CREATE INDEX idx_payments_provider_id ON payments (provider, provider_payment_id) WHERE provider_payment_id IS NOT NULL;
CREATE INDEX idx_payments_status      ON payments (status, attempted_at DESC);

CREATE TABLE refunds (
    id                  BIGSERIAL    PRIMARY KEY,
    public_id           UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    payment_id          BIGINT       NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
    order_public_id     UUID         NOT NULL,
    order_number        TEXT         NOT NULL,

    amount              BIGINT       NOT NULL CHECK (amount > 0),
    currency            CHAR(3)      NOT NULL,
    reason              TEXT         NOT NULL
                        CHECK (reason IN ('CUSTOMER_REQUEST','OUT_OF_STOCK','FRAUD','DUPLICATE','OTHER')),
    notes               TEXT,

    status              TEXT         NOT NULL DEFAULT 'PENDING'
                        CHECK (status IN ('PENDING','SUCCEEDED','FAILED','CANCELLED')),
    provider_refund_id  TEXT,
    initiated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    completed_at        TIMESTAMPTZ,
    raw_response        JSONB,

    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version             BIGINT       NOT NULL DEFAULT 0
);

CREATE INDEX idx_refunds_payment ON refunds (payment_id);
CREATE INDEX idx_refunds_order   ON refunds (order_public_id);

-- ─── Idempotency keys ────────────────────────────────────────
CREATE TABLE payment_idempotency_keys (
    key             TEXT         PRIMARY KEY,
    request_hash    TEXT         NOT NULL,
    response_status SMALLINT,
    response_body   JSONB,
    payment_id      BIGINT       REFERENCES payments(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ  NOT NULL
);

CREATE INDEX idx_idempotency_expires ON payment_idempotency_keys (expires_at);

-- ─── Webhook inbox ───────────────────────────────────────────
CREATE TABLE payment_webhook_events (
    id                BIGSERIAL    PRIMARY KEY,
    provider          TEXT         NOT NULL,
    provider_event_id TEXT         NOT NULL,
    event_type        TEXT         NOT NULL,
    signature         TEXT,
    payload           JSONB        NOT NULL,
    received_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    processed_at      TIMESTAMPTZ,
    processing_error  TEXT,

    CONSTRAINT uq_webhook_event UNIQUE (provider, provider_event_id)
);

CREATE INDEX idx_webhook_unprocessed ON payment_webhook_events (received_at)
    WHERE processed_at IS NULL;

SELECT attach_standard_triggers('payments');
SELECT attach_standard_triggers('refunds');
