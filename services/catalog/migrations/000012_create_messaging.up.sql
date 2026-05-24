-- ┌───────────────────────────────────────────────────────────┐
-- │ Eventing tables for the choreography saga (Go services).  │
-- │  outbox            : transactional outbox (atomic w/ writes)│
-- │  processed_events  : idempotent-consumer dedup log         │
-- │ See docs/patterns/04-outbox.md and 05-idempotent-consumer  │
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE outbox (
    id            UUID         PRIMARY KEY DEFAULT uuid_generate_v7(),
    aggregate     TEXT         NOT NULL,                 -- e.g. 'order','payment'
    aggregate_id  TEXT         NOT NULL,                 -- Kafka partition key (usually order public_id)
    topic         TEXT         NOT NULL,
    payload       JSONB        NOT NULL,
    headers       JSONB        NOT NULL DEFAULT '{}',    -- trace_id etc.
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    sent_at       TIMESTAMPTZ                            -- NULL = not yet published
);

-- relay polls unsent rows oldest-first; partial index keeps it tiny.
CREATE INDEX idx_outbox_unsent ON outbox (created_at) WHERE sent_at IS NULL;

CREATE TABLE processed_events (
    event_id    UUID         NOT NULL,
    consumer    TEXT         NOT NULL,                   -- which consumer handled it
    handled_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_id, consumer)
);
