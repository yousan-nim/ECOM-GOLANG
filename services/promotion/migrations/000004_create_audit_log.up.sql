-- ┌───────────────────────────────────────────────────────────┐
-- │ V17: audit_log.                                           │
-- │  This MUST be the last DDL so earlier tables can attach   │
-- │  the audit trigger (which references this table).         │
-- │                                                           │
-- │  Storage strategy: PARTITION BY RANGE (changed_at) by     │
-- │  month — keeps active partition small and pruning cheap.  │
-- │  Older partitions can be detached and archived to S3.     │
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE audit_log (
    id            BIGSERIAL,
    entity_table  TEXT         NOT NULL,
    entity_id     BIGINT       NOT NULL,
    action        TEXT         NOT NULL
                  CHECK (action IN ('INSERT','UPDATE','DELETE')),
    actor_id      BIGINT,                              -- set via SET LOCAL audit.actor_id
    old_data      JSONB,
    new_data      JSONB,
    changed_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    PRIMARY KEY (id, changed_at)
) PARTITION BY RANGE (changed_at);

CREATE INDEX idx_audit_log_entity
    ON audit_log (entity_table, entity_id, changed_at DESC);
CREATE INDEX idx_audit_log_actor
    ON audit_log (actor_id, changed_at DESC) WHERE actor_id IS NOT NULL;

-- Default partition catches everything until proper monthly partitions are created
-- by a scheduled job (CREATE TABLE … PARTITION OF audit_log FOR VALUES FROM …).
CREATE TABLE audit_log_default PARTITION OF audit_log DEFAULT;

-- ─── Pre-create partitions for the current and next month ────
DO $$
DECLARE
    current_start DATE := date_trunc('month', NOW())::DATE;
    next_start    DATE := (date_trunc('month', NOW()) + INTERVAL '1 month')::DATE;
    month_after   DATE := (date_trunc('month', NOW()) + INTERVAL '2 months')::DATE;
BEGIN
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS audit_log_%s PARTITION OF audit_log
         FOR VALUES FROM (%L) TO (%L);',
        to_char(current_start, 'YYYYMM'),
        current_start, next_start);
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS audit_log_%s PARTITION OF audit_log
         FOR VALUES FROM (%L) TO (%L);',
        to_char(next_start, 'YYYYMM'),
        next_start, month_after);
END$$;
