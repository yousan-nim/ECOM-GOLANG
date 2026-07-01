-- ┌───────────────────────────────────────────────────────────┐
-- │ V2: helper functions used by every domain table.          │
-- │     - uuid_generate_v7()  : time-ordered UUIDs (RFC 9562) │
-- │     - set_updated_at()    : trigger for updated_at        │
-- │     - audit_trigger_fn()  : feeds the audit_log table     │
-- │                                                           │
-- │  Note: audit_log itself is created in V17.                │
-- │  Triggers are wired up at the end of each table's         │
-- │  migration (so audit fires from V3 onwards).              │
-- └───────────────────────────────────────────────────────────┘

-- ─── UUID v7 ─────────────────────────────────────────────────
-- RFC 9562 v7: time-ordered, monotonic, sortable.
-- Postgres 17 ships uuid_generate_v7 natively; we polyfill for PG 16-.
CREATE OR REPLACE FUNCTION uuid_generate_v7()
RETURNS uuid AS $$
DECLARE
    unix_ts_ms BIGINT;
    rand_bytes BYTEA;
    b          BYTEA;
BEGIN
    unix_ts_ms := (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT;
    rand_bytes := gen_random_bytes(10);

    b := set_byte(rand_bytes, 0, 0);  -- placeholder, overwritten below
    -- Compose 16 bytes: [ts_ms(6)] [ver+rand(2)] [var+rand(8)]
    b := decode(lpad(to_hex(unix_ts_ms), 12, '0'), 'hex') || rand_bytes;

    -- Set version = 7  (high nibble of byte 6)
    b := set_byte(b, 6, ((get_byte(b, 6) & 15) | 112));
    -- Set variant = RFC 4122 (10xx high bits of byte 8)
    b := set_byte(b, 8, ((get_byte(b, 8) & 63) | 128));

    RETURN encode(b, 'hex')::uuid;
END;
$$ LANGUAGE plpgsql VOLATILE;

COMMENT ON FUNCTION uuid_generate_v7() IS
  'RFC 9562 UUID v7 — time-ordered, suitable as public-facing identifier and as an indexed column.';

-- ─── updated_at trigger ──────────────────────────────────────
-- Bumps updated_at on every UPDATE.
-- (Optimistic locking — `version` column — is managed by JPA @Version, not here.)
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ─── Audit trigger function ──────────────────────────────────
-- App must set:  SET LOCAL audit.actor_id = '<user_id>';
-- inside each transaction (typically via Spring AOP).
CREATE OR REPLACE FUNCTION audit_trigger_fn()
RETURNS TRIGGER AS $$
DECLARE
    actor BIGINT;
BEGIN
    BEGIN
        actor := NULLIF(current_setting('audit.actor_id', true), '')::BIGINT;
    EXCEPTION WHEN OTHERS THEN
        actor := NULL;
    END;

    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (entity_table, entity_id, action, actor_id, old_data)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', actor, to_jsonb(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        IF to_jsonb(OLD) IS DISTINCT FROM to_jsonb(NEW) THEN
            INSERT INTO audit_log (entity_table, entity_id, action, actor_id, old_data, new_data)
            VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', actor, to_jsonb(OLD), to_jsonb(NEW));
        END IF;
        RETURN NEW;
    ELSE  -- INSERT
        INSERT INTO audit_log (entity_table, entity_id, action, actor_id, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', actor, to_jsonb(NEW));
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Convenience: attach standard triggers to a table.
-- Usage:  SELECT attach_standard_triggers('products');
CREATE OR REPLACE FUNCTION attach_standard_triggers(target_table TEXT)
RETURNS VOID AS $$
BEGIN
    EXECUTE format(
        'DROP TRIGGER IF EXISTS trg_set_updated_at ON %I;
         CREATE TRIGGER trg_set_updated_at
         BEFORE UPDATE ON %I
         FOR EACH ROW EXECUTE FUNCTION set_updated_at();',
        target_table, target_table);

    EXECUTE format(
        'DROP TRIGGER IF EXISTS trg_audit ON %I;
         CREATE TRIGGER trg_audit
         AFTER INSERT OR UPDATE OR DELETE ON %I
         FOR EACH ROW EXECUTE FUNCTION audit_trigger_fn();',
        target_table, target_table);
END;
$$ LANGUAGE plpgsql;
