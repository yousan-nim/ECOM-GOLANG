CREATE TABLE audit_log (
    id            BIGSERIAL,
    entity_table  TEXT         NOT NULL,
    entity_id     BIGINT       NOT NULL,
    action        TEXT         NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
    actor_id      BIGINT,
    old_data      JSONB,
    new_data      JSONB,
    changed_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, changed_at)
) PARTITION BY RANGE (changed_at);

CREATE INDEX idx_audit_log_entity ON audit_log (entity_table, entity_id, changed_at DESC);
CREATE INDEX idx_audit_log_actor  ON audit_log (actor_id, changed_at DESC) WHERE actor_id IS NOT NULL;

CREATE TABLE audit_log_default PARTITION OF audit_log DEFAULT;

DO $$
DECLARE
    cur_start  DATE := date_trunc('month', NOW())::DATE;
    nxt_start  DATE := (date_trunc('month', NOW()) + INTERVAL '1 month')::DATE;
    nxt2_start DATE := (date_trunc('month', NOW()) + INTERVAL '2 months')::DATE;
BEGIN
    EXECUTE format('CREATE TABLE IF NOT EXISTS audit_log_%s PARTITION OF audit_log FOR VALUES FROM (%L) TO (%L);',
        to_char(cur_start, 'YYYYMM'), cur_start, nxt_start);
    EXECUTE format('CREATE TABLE IF NOT EXISTS audit_log_%s PARTITION OF audit_log FOR VALUES FROM (%L) TO (%L);',
        to_char(nxt_start, 'YYYYMM'), nxt_start, nxt2_start);
END$$;
