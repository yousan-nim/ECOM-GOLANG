-- ┌───────────────────────────────────────────────────────────┐
-- │ V16: exchange rates — historical, time-bounded.           │
-- │  Used to compute base-currency totals on orders.          │
-- │  Populated by a daily/hourly job that pulls from an FX    │
-- │  provider (OXR, ECB, etc.).                               │
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE exchange_rates (
    id              BIGSERIAL    PRIMARY KEY,

    base_currency   CHAR(3)      NOT NULL,                 -- e.g. 'THB' (platform's reporting currency)
    quote_currency  CHAR(3)      NOT NULL,                 -- e.g. 'USD'
    rate            NUMERIC(18,8) NOT NULL CHECK (rate > 0),
                    -- meaning: 1 unit of base = `rate` units of quote

    source          TEXT         NOT NULL,                 -- 'OXR','ECB','MANUAL'
    valid_from      TIMESTAMPTZ  NOT NULL,
    valid_until     TIMESTAMPTZ,                           -- NULL = currently active

    fetched_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT exchange_rates_period_chk CHECK (valid_until IS NULL OR valid_until > valid_from),
    CONSTRAINT exchange_rates_diff_chk   CHECK (base_currency <> quote_currency)
);

CREATE UNIQUE INDEX uq_exchange_rates_active
    ON exchange_rates (base_currency, quote_currency)
    WHERE valid_until IS NULL;

CREATE INDEX idx_exchange_rates_pair_time
    ON exchange_rates (base_currency, quote_currency, valid_from DESC);
